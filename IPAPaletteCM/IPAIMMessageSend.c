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

OSStatus IPASendMessage(IPAMessage inMessage, CFDataRef inData)
{
  OSStatus result = noErr;
  CFMessagePortRef serverPortRef;
  
  if (gDebugLevel >= ipaDebugDebugLevel)
  {
    IPALog("IPASendMessage %d", inMessage);
    if (inData) CFShow(inData);
    printf("\n");
  }
  //  Create a reference to the remote message port. We identify the port using a unique,
  //  system-wide name, in this case defined by kIPAServerPortName.
  serverPortRef = CFMessagePortCreateRemote(NULL, CFSTR(kIPAServerPortName));
  if (serverPortRef == NULL)
  {
    result = -1;
    IPALog("IPASendMessage: message=%ld CFMessagePortCreateRemote failed", inMessage);
  }
  else
  {
    if (inMessage == ipaActivatedMsg || inMessage == ipaActivatedShowOnlyMsg)
    {
      ProcessSerialNumber psn;
      // Create our message header.
      result = GetCurrentProcess(&psn);
      if (result) IPALog("IPAPalette: IPASendMessage GetCurrentProcess failed with status %ld", result);
      else
      {
        CFStringRef psnStr = CFStringCreateWithFormat(NULL, NULL, CFSTR("%ld%ld"), psn.highLongOfPSN, psn.lowLongOfPSN);
        inData = CFStringCreateExternalRepresentation(NULL, psnStr, kCFStringEncodingUTF8, '?');
        CFRelease(psnStr);
        if (!inData)
        {
          result = memFullErr;
          IPALog("IPASendMessage: message=%ld CFDataCreate failed", inMessage);
        }
      }
    }
    //if (gDebugLevel >= ipaDebugDebugLevel) IPALog("IPASendMessage: can I send? inData=0x%X, result=%d", inData, result);
    if (result == noErr)
    {
      CFDataRef replyData = NULL;
      if (gDebugLevel >= ipaDebugDebugLevel)
      {
        IPALog("IPASendMessage: sending message=%ld data...", inMessage);
        CFShow(inData);
      }
      //  Send the message specified in inMessage to the server. We send the message header as data.
      // CFMessagePortSendRequest result codes are 0 on success, like OSStatus codes.
      result = CFMessagePortSendRequest(serverPortRef, inMessage, inData, 0.0, 0.0, NULL, &replyData);
      if (result != kCFMessagePortSuccess)
        IPALog("IPASendMessage: message=%ld CFMessagePortSendRequest failed (%ld)", inMessage, result);
      if (replyData) CFRelease(replyData);
      if (inMessage == ipaActivatedMsg || inMessage == ipaActivatedShowOnlyMsg) CFRelease(inData);
    }
    CFRelease(serverPortRef);
  }
  return result;
}

