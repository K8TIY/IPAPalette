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

long gInstanceRefCount = 0;
unsigned gDebugLevel = ipaSilentDebugLevel;
pascal ComponentResult IPAIMComponentDispatch(ComponentParameters *inParams, Handle inSessionHandle);
static char* local_IPAIMSelectorString(short inSelector);
static ComponentResult local_IPAIMOpenComponent(ComponentInstance inComponentInstance);
static ComponentResult local_IPAIMCloseComponent(Handle inSessionHandle, ComponentInstance inComponentInstance);
static ComponentResult local_IPAIMGetScriptLangSupport(ScriptLanguageSupportHandle *outScriptHandle);

/************************************************************************************************
*  This routine is the main entry point for our text service component. All calls to our
*  component go thru here.
*
*  We examine the selector (inParams->what) and dispatch the call to the appropriate handler.
************************************************************************************************/
pascal ComponentResult IPAIMComponentDispatch(ComponentParameters *inParams, Handle inSessionHandle)
{
  ComponentResult result = badComponentSelector;
  //  Dispatch to the appropriate handler, based on the selector in the inParams record.
  short what = inParams->what;
  char* str = local_IPAIMSelectorString(what);
  if (gDebugLevel >= ipaInsaneDebugLevel)
    IPALog("IPAIMComponentDispatch: received %s (%d)", str, what);
  switch (what)
  {
    //  These first four calls are made by the Component Manager to every component.
    case kComponentOpenSelect:
    result = local_IPAIMOpenComponent((ComponentInstance)(inParams->params[0]));
    break;

    case kComponentCloseSelect:
    result = local_IPAIMCloseComponent(inSessionHandle, (ComponentInstance)(inParams->params[0]));
    break;

    case kComponentVersionSelect:
    result = 0x00010000;
    break;

    case kCMGetScriptLangSupport:
    result = local_IPAIMGetScriptLangSupport((ScriptLanguageSupportHandle*)(inParams->params[0]));
    break;

    case kCMInitiateTextService:
    case kCMTerminateTextService:
    case kCMHidePaletteWindows:
    result = noErr;
    break;

    case kCMActivateTextService:
    {
      if (gDebugLevel >= ipaDebugDebugLevel) IPALog("handling kCMActivateTextService.");
      Boolean ok = true;
      result = noErr;
      // We may want to show the IM window but not activate for sending data
      // to this process if it is the troublesome SystemUIServer
      Boolean showOnly = false;
      CFDictionaryRef pidict;
      CFStringRef creator;
      TSMDocumentID doc;
      OSErr err; // Local only, does not get passed out of function
      ProcessSerialNumber psn = {0, kCurrentProcess};
      pidict = ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
      creator = CFDictionaryGetValue(pidict, CFSTR("FileCreator"));
      doc = TSMGetActiveDocument();
      if (kCFCompareEqualTo == CFStringCompare(CFSTR("IPA!"),creator,0))
      {
        ok = false;
        if (gDebugLevel >= ipaDebugDebugLevel) IPALog("front app is IPA Palette! Can't activate.");
        result = eventNotHandledErr;
      }
      else if (CFBooleanGetValue(CFDictionaryGetValue(pidict, CFSTR("LSBackgroundOnly"))))
      {
        ok = false;
        if (gDebugLevel >= ipaDebugDebugLevel) IPALog("front app is LSBackgroundOnly! Can't activate.");
        result = eventNotHandledErr;
      }
      else
      {
        CFStringRef myName = nil;
        err = CopyProcessName(&psn, &myName);
        if (!err &&
            (kCFCompareEqualTo == CFStringCompare(myName,CFSTR("SystemUIServer"),0) ||
             kCFCompareEqualTo == CFStringCompare(CFSTR("syui"),creator,0)))
        {
          CFRelease(myName);
          ok = false;
          // Maybe we've got a Spotlight window open.
          if (NULL != doc)
          {
            if (gDebugLevel >= ipaDebugDebugLevel)
              IPALog("Front app is SystemUIServer with non-NULL TSMDocumentID! Will activate.");
            ok = true;
          }
          else
          {
            if (gDebugLevel >= ipaDebugDebugLevel)
              IPALog("Front app is SystemUIServer! Will only show Palette.");
            ok = true;
            showOnly = true;
          }
        }
      }
      CFRelease(pidict);
      if (gDebugLevel >= ipaInsaneDebugLevel) IPALog("kCMActivateTextService: ok to continue? %s", (ok)?"yes":"no");
      if (ok)
      {
        long gestaltResponse = 0;
        if (!showOnly) gActiveSession = (IPAIMSessionHandle)inSessionHandle;
        //  When we are activated, we register ourselves with the server process.
        IPAIMLaunchServer();
        if (gDebugLevel >= ipaInsaneDebugLevel) IPALog("kCMActivateTextService: calling IPASendMessage()");
        result = IPASendMessage((showOnly) ? ipaActivatedShowOnlyMsg : ipaActivatedMsg, nil);
        // Adjust Palette above Dashboard window level if necessary (Tiger+ version TSM only)
        (void)Gestalt(gestaltTSMgrVersion, &gestaltResponse);
        if (gestaltResponse >= gestaltTSMgr23)
        {
          UInt32 docProperty;
          UInt32 actualSize = 0;
          err = TSMGetDocumentProperty(doc, kTSMDocumentWindowLevelPropertyTag, 0, &actualSize, NULL);
          if (!err && actualSize <= sizeof(docProperty))
          {
            err = TSMGetDocumentProperty(doc, kTSMDocumentWindowLevelPropertyTag,
                                         sizeof(docProperty), &actualSize, &docProperty);
            if (err) IPALog("ERROR: TSMGetDocumentProperty second call; err=%d", err);
            else
            {
              CFDataRef sendData = CFDataCreate(NULL, (void*)&docProperty, sizeof(docProperty));
              if (gDebugLevel >= ipaDebugDebugLevel)
                IPALog("setting window level to %d", docProperty);
              result = IPASendMessage(ipaWindowLevelMsg, sendData);
              CFRelease(sendData);
            }
          }
        }
      }
    }
    break;

    case kCMDeactivateTextService:
    gActiveSession = nil;
    result = noErr;
    break;

    case kComponentCanDoSelect:
    case kCMTextServiceEvent:
    case kCMFixTextService:
    IPALog("ERROR: need to reimplement response for selector %d", what);
    break;
  }
  if (gDebugLevel >= ipaInsaneDebugLevel) IPALog("IPAIMComponentDispatch: returning (%d)", result);
  return result;
}

char* selStrs[] =
{ NULL,
  "kComponentOpenSelect",          // -1
  "kComponentCloseSelect",         // -2
  "kComponentCanDoSelect",         // -3
  "kComponentVersionSelect",       // -4
  "kComponentRegisterSelect",      // -5
  "kComponentTargetSelect",        // -6
  "kComponentUnregisterSelect",    // -7
  "kComponentGetMPWorkFunctionSelect", // -8
  "kComponentExecuteWiredActionSelect", // -9
  "kComponentGetPublicResourceSelect" // -10
};

char* tsmSelStrs[] =
{
  "unknown selector",
  "kCMGetScriptLangSupport", // 1
  "kCMInitiateTextService", // 2
  "kCMTerminateTextService", // 3
  "kCMActivateTextService", // 4
  "kCMDeactivateTextService", // 5
  "kCMTextServiceEventRef", // 6
  "kCMGetTextServiceMenu", // 7
  "kCMTextServiceMenuSelect", // 8
  "kCMFixTextService", // 9
  "kCMSetTextServiceCursor", // 10
  "kCMHidePaletteWindows", // 11
  "kCMGetTextServiceProperty", // 12
  "kCMSetTextServiceProperty", // 13
  "kCMUCTextServiceEvent", // 14
  "kCMCopyTextServiceInputModeList", // 15
  "kCMInputModePaletteItemHit", // 16
  "kCMGetInputModePaletteMenu" // 17
};

#ifndef kCMGetInputModePaletteMenu
#define kCMGetInputModePaletteMenu 17
#endif


static char* local_IPAIMSelectorString(short inSelector)
{
  char* str = selStrs[0];
  if (inSelector < 0 && inSelector >= kComponentGetPublicResourceSelect)
    str = selStrs[-inSelector];
  else if (inSelector > 0 && inSelector <= kCMGetInputModePaletteMenu)
    str = tsmSelStrs[inSelector];
  return str;
}

/************************************************************************************************
*  This routine is called directly via OpenComponent, or indirectly via NewTSMDocument.
*
*  If this the first instance of our component, we initialize our global state (IPAIMInitialize).
*  Then we initialize a new session context (IPAIMOpenSession). 
************************************************************************************************/
static ComponentResult local_IPAIMOpenComponent(ComponentInstance inComponentInstance)
{
  ComponentResult result = noErr;
  Handle sessionHandle = nil;

  //  If this is the first instance of our component, initalize our global state. Normally,
  //  this means that we initialize any global variables that persist across sessions.
  if (!gInstanceRefCount) result = IPAIMInitialize(inComponentInstance);
  gInstanceRefCount++;
  //  Now initialize a new session context. We store our per-session data in a session
  //  handle that is stored with the component instance.
  if (!result)
  {
    //  Get our component instance storage.
    sessionHandle = GetComponentInstanceStorage(inComponentInstance);
    //  Initialize the new session.
    result = IPAIMSessionOpen(inComponentInstance, (IPAIMSessionHandle*)&sessionHandle);
    //  Save the returned handle as our component instance storage.
    if (!result) SetComponentInstanceStorage(inComponentInstance, sessionHandle);
  }
  return result;
}

static ComponentResult local_IPAIMCloseComponent(Handle inSessionHandle, ComponentInstance inComponentInstance)
{
  ComponentResult result = noErr;
  if (inComponentInstance == nil)
  {
    IPALog("local_IPAIMCloseComponent: ERROR? inComponentInstance is nil");
    result = paramErr;
  }
  else
  {
    //  Terminate the current session context. Note that if OpenComponent failed, the session
    //  handle may be NULL.
    if (inSessionHandle) DisposeHandle(inSessionHandle);
    SetComponentInstanceStorage(inComponentInstance, nil);
    //  If this is the last instance of our component, terminate our global state. Normally,
    //  this means that we dispose of any global data allocated during IPAIMInitialize().
    if (gInstanceRefCount > 0)
    {
      gInstanceRefCount--;
      if (gInstanceRefCount == 0)
      {
        if (gDebugLevel >= ipaDebugDebugLevel)
          IPALog("local_IPAIMCloseComponent: reference count now zero; NULL-ing active session and sending ipaHidePaletteMsg");
        gActiveSession = nil;
        IPASendMessage(ipaHidePaletteMsg, nil);
      }
      else if (gDebugLevel >= ipaDebugDebugLevel)
        IPALog("local_IPAIMCloseComponent: gInstanceRefCount decremented to %d", gInstanceRefCount);
    }
  }
  return result;
}

// Called by TSM to determine our input method type.
static ComponentResult local_IPAIMGetScriptLangSupport(ScriptLanguageSupportHandle *outScriptHandle)
{
  OSStatus result = noErr;
  ScriptLanguageRecord scriptLanguageRecord = {kTextEncodingUnicodeDefault, langEnglish};
  size_t neededSize = sizeof(SInt16) + sizeof(ScriptLanguageRecord);
  // Allocate a handle to store our script/language records.
  if (*outScriptHandle == NULL)
  {
    *outScriptHandle = (ScriptLanguageSupportHandle)NewHandle(neededSize);
    if (*outScriptHandle == NULL) result = memFullErr;
  }
  else
  {
    SetHandleSize((Handle)*outScriptHandle, neededSize);
    result = MemError();
  }
  if (!result)
  {
    (**outScriptHandle)->fScriptLanguageCount = 1;
    (**outScriptHandle)->fScriptLanguageArray[0] = scriptLanguageRecord;
  }
  // If an error occurred, dispose of everything.
  if (result)
  {
    if (*outScriptHandle)
    {
      DisposeHandle((Handle)*outScriptHandle);
      *outScriptHandle = NULL;
    }
  }
  return result;
}
