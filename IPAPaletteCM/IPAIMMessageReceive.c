/*
Copyright © 2005-2010 Brian S. Hall
Portions may be Copyright © 2000-2001 Apple Computer, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
#include "IPAIM.h"

static CFDataRef IPAMessagePortCallBack(CFMessagePortRef inLocalPort, SInt32 inMessageID,
                                        CFDataRef inData, void *inContextInfo);
static OSErr IPAInputEvent(IPAIMSessionHandle inSessionHandle, unsigned inBytes, UniChar* inChars);

/************************************************************************************************
*  Initialize everything needed so the UI server can find and communicate
*  with us. Called when we are launched.
************************************************************************************************/
OSStatus IPAInitMessageReceiving(void)
{
  CFStringRef portName = NULL;
  CFMessagePortRef port = NULL;
  ProcessSerialNumber psn;
  // We need a unique port name on which to listen for messages. Use PSN to
  // create a unique port name of the form "com.blugs.IPAServerxxxxxx" where
  // xxxxxx is the PSN of host app. We listen for messages on this port.
  OSStatus result = GetCurrentProcess(&psn);
  //  Create a port on which we will listen for messages.
  if (!result)
  {
    CFMessagePortContext context = {0,NULL,NULL,NULL,NULL};
    //portName = local_CreatePortName(&psn);
    portName = CFStringCreateWithFormat(NULL, NULL, CFSTR("%s%ld%ld"),
                                        kIPAServerListenPortName, psn.highLongOfPSN, psn.lowLongOfPSN);
    if (gDebugLevel >= ipaDebugDebugLevel)
    {
      IPALog("IPAInitMessageReceiving: creating port:");
      CFShow(portName);
    }
    port = CFMessagePortCreateLocal(NULL, portName, IPAMessagePortCallBack, &context, NULL);
    if (!port) result = -1;
    else
    {
      CFRunLoopRef runLoop = CFRunLoopGetCurrent();
      if (!runLoop) result = -2;
      else
      {
        CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, port, 0);
        if (!source) result = -3;
        else
        {
          CFRunLoopAddSource(runLoop, source, kCFRunLoopCommonModes);
          CFRelease(source);
        }
      }
      CFRelease(port);
    }
    CFRelease(portName);
  }
  if (result) IPALog("IPAInitMessageReceiving ERROR %ld", result);
  return result;
}

static CFDataRef IPAMessagePortCallBack(CFMessagePortRef inLocalPort, SInt32 inMessageID,
                                        CFDataRef inData, void *inContextInfo)
{
  #pragma unused (inContextInfo)
  if (gDebugLevel >= ipaDebugDebugLevel)
  {
    IPALog("IPAMessagePortCallBack: got message=%ld data...", inMessageID);
    CFShow(inData);
  }
  if (inMessageID == ipaInputMsg)
  {
    //  When a key on the palette is clicked by the user, the server sends us a
    //  ipaInputMsg message. The message data contains the keypress item(s).
    if (!gActiveSession) IPALog("IPAMessagePortCallBack: ERROR? no gActiveSession");
    else
    {
      //  Extract the keypress data from the message and send it to IPAIMHandleInput to
      //  be processed, just as if the user entered the key from the keyboard. 
      if (inData)
      {
        UniChar* charCodes;
        CFRange  range;
        
        CFStringRef asStr = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, inData, kCFStringEncodingUTF8);
        range.location = 0;
        range.length = CFStringGetLength(asStr);
        charCodes = malloc(range.length*sizeof(UniChar));
        CFStringGetCharacters(asStr, range, charCodes);
        if (gDebugLevel >= ipaVerboseDebugLevel)
        {
          IPALog("ipaInputMsg: got %d characters:", range.length);
          CFShow(asStr);
        }
        CFRelease(asStr);
        IPAInputEvent(gActiveSession, range.length*2, charCodes);
        free(charCodes);
      }
    }
  }
  else if (inMessageID == ipaPaletteHiddenMsg)
  {
    if (gActiveSession)
    {
      ComponentInstance ci = (*gActiveSession)->_comp;
      // Supposedly you can cast a ComponentInstance to a Component willy-nilly.
      // This appears to actually work.
      DeselectTextService((Component)ci);
    }
  }
  else if (inMessageID == ipaDebugMsg)
  {
    if (inData && gActiveSession)
    {
      unsigned level;
      CFRange range = CFRangeMake(0, CFDataGetLength(inData));
      if (range.length != sizeof(level))
        IPALog("ERROR: wrong length for debug level: expected %d, got %d", sizeof(level), range.length);
      else
      {
        CFDataGetBytes(inData, range, (UInt8*)&level);
        if (level != gDebugLevel)
        {
          IPALog("setting debug level from %d to %d", gDebugLevel, level);
          gDebugLevel = level;
        }
      }
    }
  }
  else if (inMessageID == ipaFontMsg)
  {
    if (inData && gActiveSession)
    {
      CFStringRef fontName = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, inData, kCFStringEncodingUTF8);
      ATSFontRef font = ATSFontFindFromName(fontName, kATSOptionFlagsDefault);
      (*gActiveSession)->_font = (ATSUFontID)FMGetFontFromATSFontRef(font);
      if (gDebugLevel >= ipaDebugDebugLevel)
      {
        IPALog("ipaFontMsg: setting session _font to %ld from font:", (*gActiveSession)->_font);
        CFShow(fontName);
      }
      CFRelease(fontName);
    }
  }
  return NULL;
}

static OSErr IPAInputEvent(IPAIMSessionHandle inSessionHandle, unsigned inBytes, UniChar* inChars)
{
  OSErr err;
  EventRef event;
  char* failedCall = "SendTextInputEvent";
  err = CreateEvent(NULL, kEventClassTextInput, kEventTextInputUnicodeText,
                    GetCurrentEventTime(), kEventAttributeUserEvent, &event);
  if (err) failedCall = "CreateEvent";
  else
  {
    ComponentInstance componentInstance = (*inSessionHandle)->_comp;
    err = SetEventParameter(event, kEventParamTextInputSendComponentInstance,
                            typeComponentInstance, sizeof(ComponentInstance),
                            &componentInstance);
    if (err) failedCall = "SetEventParameter->kEventParamTextInputSendComponentInstance";
    else
    {
      UInt32 enc = kTextEncodingMacUnicode;
      err = SetEventParameter(event, kEventParamTextInputSendTextServiceMacEncoding, typeUInt32, sizeof(enc), &enc);
      if (err) failedCall = "SetEventParameter->kEventParamTextInputSendTextServiceMacEncoding";
      else
      {
        err = SetEventParameter(event, kEventParamTextInputSendText, typeUnicodeText, inBytes, inChars);
        if (err) failedCall = "SetEventParameter->kEventParamTextInputSendText";
        else
        {
          if ((*inSessionHandle)->_font)
          {
            TSMGlyphInfoArray gia = {1,{CFRangeMake(0,inBytes/sizeof(UniChar)),(*inSessionHandle)->_font,kGlyphCollectionGID,0}};
            err = SetEventParameter(event, kEventParamTextInputSendGlyphInfoArray, typeGlyphInfoArray, sizeof(gia), &gia);
            if (err) failedCall = "SetEventParameter->kEventParamTextInputSendGlyphInfoArray";
            (*inSessionHandle)->_font = 0;
          }
          err = SendTextInputEvent(event);
        }
      }
    }
    ReleaseEvent(event);
  }
  if (err)
  {
    OSStatus err2;
    // Send the error integer as big-endian, no matter which arch we are running under.
    OSStatus swapped = CFSwapInt32HostToBig(err);
    CFDataRef errData = CFDataCreate(NULL, (void*)&swapped, sizeof(swapped));
    IPALog("IPAInputEvent: %s error %d", failedCall, err);
    err2 = IPASendMessage(ipaErrorMsg, errData);
    if (err2) IPALog("IPAInputEvent: error %d sending ipaErrorMsg", err2);
    CFRelease(errData);
  }
  return err;
}

