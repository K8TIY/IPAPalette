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
