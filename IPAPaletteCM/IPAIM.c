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
#include <unistd.h>

IPAIMSessionHandle gActiveSession;
static OSStatus IPAIMLaunchWithFSSpec(FSSpec *fileSpec);
/************************************************************************************************
*  Called via NewTSMDocument the first time our text service component is instantiated.
*
*  Initialize our global state (initialize global variables, launch the
*  server process). We only initialize global data
*  here. All per-session context initialization is handled in IPAIMSessionOpen().
************************************************************************************************/
ComponentResult IPAIMInitialize(ComponentInstance inComponentInstance)
{
  ComponentResult result;

  gActiveSession = nil;
  result = IPAIMLaunchServer();
  if (!result) result = IPAInitMessageReceiving();
  return result;
}

/************************************************************************************************
*  Called via NewTSMDocument. Initialize a new session context. Create a session handle to store all
*  of the information pertinent to the session and initialize all its data structures. We do not
*  handle initialize global data (data that is shared across sessions); that is taken care of by
*  IPAIMInitialize().
************************************************************************************************/
ComponentResult IPAIMSessionOpen(ComponentInstance inComponentInstance,
                                 IPAIMSessionHandle *outSessionHandle)
{
  ComponentResult result = noErr;
  IPAIMSessionHandle h = *outSessionHandle;
  // If per-session storage is not set up yet, do so now.
  if (h == nil) h = (IPAIMSessionHandle)NewHandleClear(sizeof(IPAIMSessionRecord));
  if (h) (*h)->_comp = inComponentInstance;
  else result = memFullErr;
  *outSessionHandle = h;
  return result;
}

/************************************************************************************************
*  Checks to see if the server is running. If not, it is launched. Control does not return from
*  this function until the launch is complete.
************************************************************************************************/
OSStatus IPAIMLaunchServer(void)
{
  OSStatus          result = noErr;
  CFMessagePortRef  serverPortRef;

  //  Obtain a reference to the server port. If it exists, then the server is already running.
  serverPortRef = CFMessagePortCreateRemote(NULL, CFSTR(kIPAServerPortName));
  if (!serverPortRef)
  {
    // The server is not running, so launch it now.
    // Obtain a reference to our text service component bundle. Can't use CFBundleGetMainBundle
    // because we are running inside another application's context so we find our bundle using the
    // bundle identifier in our Info.plist file.
    CFURLRef sharedSupportURL = NULL;
    CFURLRef serverURL = NULL;
    FSRef serverFSRef;
    FSSpec serverFileSpec;
    CFBundleRef myComponentBundle = CFBundleGetBundleWithIdentifier(kBundleIdentifier);
    
    //  If we got a reference to the bundle, locate the "SharedSupport" directory inside the bundle.
    if (myComponentBundle) sharedSupportURL = CFBundleCopySharedSupportURL(myComponentBundle);
    //  If we found the "SharedSupport" directory, append the name of our server application to the
    //  URL so we can identify it.
    if (sharedSupportURL)
        serverURL = CFURLCreateCopyAppendingPathComponent(nil, sharedSupportURL,
                                                           kServerName, false);
    //  We need to do some extra work here. Since LaunchApplication only takes an FSSpec as a parameter,
    //  me must convert the server URL into an FSRef and then convert it into an FSSpec. Whew!
    if (!serverURL) result = -2;
    else
    {
      if (!CFURLGetFSRef(serverURL, &serverFSRef)) result = -2;
      else
      {
        result = FSGetCatalogInfo(&serverFSRef, kFSCatInfoNone, nil, nil, &serverFileSpec, nil);
        if (result == noErr)
        {
          // Wait for the server to come up (timeout in 20 seconds -- this is arbitrary and may need
          // adjusting for certain situations such as launching over a network)
          long timeout = TickCount() + 1200;
          //  Launch the server application.
          result = IPAIMLaunchWithFSSpec(&serverFileSpec);
          while (result == noErr)
          {
            struct timespec ts = {0,90000000};
            //  Get a reference to the server port.
            serverPortRef = CFMessagePortCreateRemote(nil, CFSTR(kIPAServerPortName));
            if (serverPortRef) break;
            if (TickCount() > timeout)
            {
              result = -1;
              break;
            }
            // Sleep a little to give time to the server.
            // Don't just keep pounding on it.
            (void)nanosleep(&ts, NULL);
          }
        }
      }
      CFRelease(serverURL);
    }
    if (sharedSupportURL) CFRelease(sharedSupportURL);
    if (result == -1) IPALog("IPAIMLaunchServer: timeout occured while trying to launch UI server.");
    else if (result == -2) IPALog("IPAIMLaunchServer: unable to locate the Shared Support directory.");
    else if (result) IPALog("IPAIMLaunchServer: error %ld occured while trying to launch the UI.", result);
  }
  if (serverPortRef) CFRelease(serverPortRef);
  return result;
}

static LaunchParamBlockRec lpbr =
  {0,0,extendedBlock,extendedBlockLen, //reserved1,reserved2,launchBlockID,launchEPBLength
   0,launchNoFileFlags + launchContinue + launchDontSwitch, //launchFileFlags, launchControlFlags
   NULL, {0,0}, //launchAppSpec, launchProcessSN
   0, 0, 0, NULL}; //launchPreferredSize, launchMinimumSize, launchAvailableSize, launchAppParameters


static OSStatus IPAIMLaunchWithFSSpec(FSSpec* fileSpec)
{
  lpbr.launchAppSpec = fileSpec;
  return LaunchApplication(&lpbr);
}

// A logger that gives us info about the process id and process name.
void IPALog(char* fmt, ...)
{
  va_list ap;
  ProcessSerialNumber psn = {0, kCurrentProcess};
  CFStringRef myName = nil;
  CFDataRef utf8 = nil;
  OSErr err = CopyProcessName(&psn, &myName);
  ProcessInfoRec pir;
  pir.processInfoLength = sizeof(pir);
  pir.processName = nil;
  pir.processAppSpec = nil;
  (void)GetProcessInformation(&psn, &pir);
  if (!err) utf8 = CFStringCreateExternalRepresentation(NULL, myName, kCFStringEncodingUTF8, 0);
  if (utf8) printf("IPA Palette (%d:[%ld,%ld]:%.*s): ", getpid(),
    pir.processNumber.highLongOfPSN, pir.processNumber.lowLongOfPSN,
    (int)CFDataGetLength(utf8), CFDataGetBytePtr(utf8));
  else printf("IPA Palette (%d): ", getpid());
  if (myName) CFRelease(myName);
  if (utf8) CFRelease(utf8);
  va_start(ap, fmt);
  vprintf(fmt, ap);
  va_end(ap);
  printf("\n");
  fflush(stdout);
}
