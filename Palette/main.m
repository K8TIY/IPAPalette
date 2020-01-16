#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "IPAServer.h"

static void local_CheckPrefs(void);

int main(int argc, char *argv[])
{
  #pragma unused(argc,argv)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  local_CheckPrefs();
  NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
  IMKServer* server = [[IMKServer alloc] initWithName:@"IPAPalette_1_Connection" bundleIdentifier:identifier];
  //load the bundle explicitly because in this case the input method is a background only application
  if (@available(macOS 10.8, *))
  {
    NSArray* objs;
    [[NSBundle mainBundle] loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication]
                           topLevelObjects:&objs];
  }
  else
  {
    [NSBundle loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication]];
  }
  [[NSApplication sharedApplication] run];
  [server release];
  [arp release];
  return 0;
}

static void local_CheckPrefs(void)
{
  NSString* home = NSHomeDirectory();
  NSString* dest = [home stringByAppendingPathComponent:@"Library/Preferences/com.blugs.inputmethod.IPAPalette.plist"];
  NSFileManager* dfm = [NSFileManager defaultManager];
  if (![dfm fileExistsAtPath:dest])
  {
    NSString* src = [home stringByAppendingPathComponent:@"Library/Preferences/com.blugs.IPAServer.plist"];
    if ([dfm fileExistsAtPath:src])
    {
      BOOL success = [dfm copyItemAtPath:src toPath:dest error:NULL];
      if (success) NSLog(@"Copied old prefs from %@ to %@", src, dest);
      else NSLog(@"Failed to copy old prefs from %@ to %@", src, dest);
    }
  }
}

/*
Copyright © 2005-2020 Brian S. Hall, BLUGS.COM LLC

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
