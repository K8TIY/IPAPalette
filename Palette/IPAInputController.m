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
  if ([list count])
  {
    me = (TISInputSourceRef)[list objectAtIndex:0L];
    CFRetain(me);
  }
  [list release];
  return me;
}
@end

/*
Copyright © 2005-2019 Brian S. Hall, BLUGS.COM LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/
