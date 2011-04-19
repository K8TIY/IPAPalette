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
#import "IPAInputController.h"
#import "IPAMessager.h"
#import "IPAClientServer.h"

@interface IPAInputController (Private)
-(TISInputSourceRef)findMe;
@end

@implementation IPAInputController
-(id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)client
{
  self = [super initWithServer:server delegate:delegate client:client];
  return self;
}

-(BOOL)inputText:(NSString*)string client:(id)sender
{
  #pragma unused(string,sender)
  return NO;
}

-(void)hidePalettes
{
  [[IPAMessager sharedMessager] sendMessage:ipaHidePaletteMsg withData:nil];
}

-(void)dealloc
{
  if (_font) [_font release];
	[super dealloc];
}

#pragma mark State Setting
-(void)activateServer:(id)sender
{
  #pragma unused(sender)
  if ([[[self client] bundleIdentifier] isEqual:@"com.blugs.IPAServer"])
  {
    if (gDebugLevel >= ipaVerboseDebugLevel) NSLog(@"activateServer: refusing com.blugs.IPAServer");
  }
  else
  {
    [[IPAMessager sharedMessager] listen:self];
    CGWindowLevel lev = [[self client] windowLevel] + 1;
    NSData* levData = [[NSData alloc] initWithBytes:&lev length:sizeof(lev)];
    [[IPAMessager sharedMessager] sendMessage:ipaActivatedMsg withData:levData];
    [levData release];
    if (gDebugLevel >= ipaVerboseDebugLevel) NSLog(@"activateServer: %@ (window level %d)", [[self client] bundleIdentifier], lev);
  }
}

-(void)deactivateServer:(id)sender
{
   #pragma unused(sender)
  //[[IPAMessager sharedMessager] unlisten:self];
}

-(void)receiveMessage:(SInt32)msg withData:(NSData*)data
{
  if (msg == ipaInputMsg)
  {
    if (data)
    {
      if ([[self client] supportsUnicode])
      {
        CFStringRef asStr = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, (CFDataRef)data, kCFStringEncodingUTF8);
        if (gDebugLevel >= ipaVerboseDebugLevel) NSLog(@"ipaInputMsg: %@", asStr);
        NSRange range = {NSNotFound,NSNotFound};
        if (_font)
        {
          if (gDebugLevel >= ipaVerboseDebugLevel) NSLog(@"ipaInputMsg: sending attributed string with font %@", _font);
          NSFont* font = [NSFont fontWithName:_font size:0.0f];
          NSDictionary* attrs = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, NULL];
          NSAttributedString* attrStr = [[NSAttributedString alloc] initWithString:(NSString*)asStr attributes:attrs];
          [attrs release];
          [[self client] insertText:attrStr replacementRange:range];
          [attrStr release];
          [_font release];
          _font = nil;
        }
        else
        {
          [[self client] insertText:(NSString*)asStr replacementRange:range];
        }
        CFRelease(asStr);
      }
      else [[IPAMessager sharedMessager] sendMessage:ipaErrorMsg withData:nil];
    }
  }
  else if (msg == ipaFontMsg)
  {
    CFStringRef asStr = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, (CFDataRef)data, kCFStringEncodingUTF8);
    if (gDebugLevel >= ipaDebugDebugLevel) NSLog(@"ipaFontMsg: %@", asStr);
    if (_font) [_font release];
    _font = [[NSString alloc] initWithString:(NSString*)asStr];
    CFRelease(asStr);
  }
  else if (msg == ipaPaletteHiddenMsg)
  {
    TISInputSourceRef me = [self findMe];
    if (me)
    {
      TISDeselectInputSource(me);
      CFRelease(me);
    }
  }
  else if (msg == ipaDebugMsg)
  {
    if (data)
    {
      unsigned level;
      CFRange cfrange = CFRangeMake(0L, CFDataGetLength((CFDataRef)data));
      if (cfrange.length != sizeof(level))
        NSLog(@"ERROR: wrong length for debug level: expected %d, got %d", sizeof(level), cfrange.length);
      else
      {
        CFDataGetBytes((CFDataRef)data, cfrange, (UInt8*)&level);
        if (level != gDebugLevel)
        {
          NSLog(@"setting debug level from %d to %d", gDebugLevel, level);
          gDebugLevel = level;
        }
      }
    }
  }
}

-(TISInputSourceRef)findMe
{
  TISInputSourceRef me = nil;
  NSMutableDictionary* filter = [[NSMutableDictionary alloc] init];
  NSString* bid = [[NSBundle mainBundle] bundleIdentifier];
  [filter setObject:(id)bid forKey:(id)kTISPropertyBundleID];
  NSArray* list = (NSArray*)TISCreateInputSourceList((CFDictionaryRef)filter, false);
  [filter release];
  //NSLog(@"TISCreateInputSourceList: returned %d sources", [list count]);
  me = (TISInputSourceRef)[list objectAtIndex:0L];
  CFRetain(me);
  [list release];
  return me;
}
@end
