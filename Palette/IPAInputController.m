/*
Copyright © 2005-2012 Brian S. Hall

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 or later as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
#import "IPAInputController.h"

@interface IPAInputController (Private)
-(TISInputSourceRef)findMe;
@end

@implementation IPAInputController
-(id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)client
{
  self = [super initWithServer:server delegate:delegate client:client];
  [[IPAServer sharedServer] setInputController:self];
  return self;
}

-(BOOL)inputText:(NSString*)string client:(id)sender
{
  #pragma unused(string,sender)
  return NO;
}

-(void)hidePalettes
{
  [super hidePalettes];
  [[IPAServer sharedServer] hide];
}

-(void)receiveText:(NSString*)text font:(NSString*)fontName
{
  if (text)
  {
    if ([[self client] supportsUnicode])
    {
      NSRange range = {NSNotFound,NSNotFound};
      if (fontName)
      {
        NSFont* font = [NSFont fontWithName:fontName size:0.0f];
        if (font)
        {
          NSDictionary* attrs = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, NULL];
          NSAttributedString* attrStr = [[NSAttributedString alloc] initWithString:text attributes:attrs];
          [attrs release];
          [[self client] insertText:attrStr replacementRange:range];
          [attrStr release];
        }
      }
      else
      {
        [[self client] insertText:text replacementRange:range];
      }
    }
    else [[IPAServer sharedServer] setError];
  }
}

-(void)receiveHide
{
  TISInputSourceRef me = [self findMe];
  if (me)
  {
    TISDeselectInputSource(me);
    CFRelease(me);
  }
}

#pragma mark State Setting
-(void)activateServer:(id)sender
{
  #pragma unused(sender)
  NSInteger wl = [[self client] windowLevel] + 1;
  if (__DBG >= ipaVerboseDebugLevel)
    NSLog(@"activateServer with window level %ld", (long)wl);
  [[IPAServer sharedServer] setInputController:self];
  [[IPAServer sharedServer] activateWithWindowLevel:wl];
}

#pragma mark Private
-(TISInputSourceRef)findMe
{
  TISInputSourceRef me = nil;
  NSMutableDictionary* filter = [[NSMutableDictionary alloc] init];
  NSString* bid = [[NSBundle mainBundle] bundleIdentifier];
  [filter setObject:bid forKey:(id)kTISPropertyBundleID];
  NSArray* list = (NSArray*)TISCreateInputSourceList((CFDictionaryRef)filter, false);
  [filter release];
  me = (TISInputSourceRef)[list objectAtIndex:0L];
  CFRetain(me);
  [list release];
  return me;
}
@end
