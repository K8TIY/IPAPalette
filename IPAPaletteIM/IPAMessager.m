/*
Copyright © 2005-2010 Brian S. Hall

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
#import <Carbon/Carbon.h>
#import "IPAMessager.h"
#import "IPAInputController.h"
#import "IPAClientServer.h"

@interface IPAMessager (Private)
-(void)receiveMessage:(IPAMessage)msg withData:(NSData*)data;
-(BOOL)launchServer;
@end
static CFDataRef IPAMessagePortCallBack(CFMessagePortRef port, SInt32 msg, CFDataRef data, void* ctx);

static IPAMessager* gSharedMessager = nil;

@implementation IPAMessager
+(IPAMessager*)sharedMessager
{
  if (!gSharedMessager) gSharedMessager = [[IPAMessager alloc] init];
  return gSharedMessager;
}

-(id)init
{
  self = [super init];
  OSStatus result = 0;
  //  Create a port on which we will listen for messages.
  CFMessagePortContext context = {0,NULL,NULL,NULL,NULL};
  context.info = self;
  if (gDebugLevel >= ipaDebugDebugLevel)
  {
    NSLog(@"IPAInitMessageReceiving: creating port: %@", kIPAClientListenPortName);
  }
  _port = CFMessagePortCreateLocal(NULL, (CFStringRef)kIPAClientListenPortName, IPAMessagePortCallBack, &context, NULL);
  if (!_port) result = -1;
  else
  {
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    if (!runLoop) result = -2;
    else
    {
      CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, _port, 0L);
      if (!source) result = -3;
      else
      {
        CFRunLoopAddSource(runLoop, source, kCFRunLoopCommonModes);
        CFRelease(source);
      }
    }
    CFRelease(_port);
  }
  if (result) NSLog(@"%s ERROR %ld", __PRETTY_FUNCTION__, result);
  return self;
}

-(void)dealloc
{
  if (_port) CFRelease(_port);
  if (_listener) [_listener release];
  [super dealloc];
}

-(void)receiveMessage:(IPAMessage)msg withData:(NSData*)data
{
  if ([_listener respondsToSelector:@selector(receiveMessage:withData:)])
      [_listener receiveMessage:msg withData:data];
}

-(void)listen:(id)listener
{
  [listener retain];
  if (_listener) [_listener release];
  _listener = listener;
}

-(OSErr)sendMessage:(IPAMessage)msg withData:(NSData*)data
{
  OSStatus result = noErr;
  if (gDebugLevel >= ipaDebugDebugLevel) NSLog(@"IPASendMessage %d: %@", msg, data);
  CFMessagePortRef serverPortRef = CFMessagePortCreateRemote(NULL, (CFStringRef)kIPAServerListenPortName);
  if (serverPortRef == NULL)
  {
    if (gDebugLevel >= ipaDebugDebugLevel) NSLog(@"Could not contact server; trying to launch it");
    BOOL launched = [self launchServer];
    if (launched)
    {
      // Wait for the server to come up -- timeout in 20 seconds
      UInt32 timeout = TickCount() + 1200;
      struct timespec ts = {0,500000000}; // half-second
      while (result == noErr)
      {
        if (gDebugLevel >= ipaInsaneDebugLevel) NSLog(@"Sleeping for half a second waiting for the server to launch");
        (void)nanosleep(&ts, NULL);
        if (gDebugLevel >= ipaInsaneDebugLevel) NSLog(@"Wakey wakey");
        //  Get a reference to the server port to see if it is awake yet
        serverPortRef = CFMessagePortCreateRemote(NULL, (CFStringRef)kIPAServerListenPortName);
        if (serverPortRef) break;
        if (TickCount() > timeout)
        {
          result = -2;
          break;
        }
      }
    }
    else result = -1;
  }
  if (result == noErr)
  {
    CFDataRef replyData = NULL;
    if (gDebugLevel >= ipaDebugDebugLevel) NSLog(@"IPASendMessage: sending (msg %ld) %@", msg, data);
    //  Send the message specified in inMessage to the server. We send the message header as data.
    // CFMessagePortSendRequest result codes are 0 on success, like OSStatus codes.
    result = CFMessagePortSendRequest(serverPortRef, msg, (CFDataRef)data, 0.0, 0.0, NULL, &replyData);
    if (result != kCFMessagePortSuccess)
      NSLog(@"IPASendMessage: message=%ld CFMessagePortSendRequest failed (%ld)", msg, result);
    if (replyData) CFRelease(replyData);
    CFRelease(serverPortRef);
  }
  else if (result) NSLog(@"IPASendMessage (%ld) failed: %ld", msg, result);
  return result;
}

-(BOOL)launchServer
{
  NSString* serverApp = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"IPAServer.app"];
  return [[NSWorkspace sharedWorkspace] launchApplication:serverApp];
}
@end

static CFDataRef IPAMessagePortCallBack(CFMessagePortRef port, SInt32 msg, CFDataRef data, void* ctx)
{
  #pragma unused(port)
  IPAMessager* myself = (IPAMessager*)ctx;
  if (gDebugLevel >= ipaDebugDebugLevel)
  {
    NSLog(@"IPAMessagePortCallBack: got message=%ld data=%@", msg, data);
  }
  [myself receiveMessage:msg withData:(NSData*)data];
  return NULL;
}

