//
//  NSApplication+DarkMode.m
//  IPAPalette
//
//  Created by Moses Hall on 12/6/19.
//  Copyright © 2019 blugs.com. All rights reserved.
//

#import "NSApplication+DarkMode.h"

@implementation NSApplication (DarkMode)
+(BOOL)isDarkMode
{
  if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_14)
  {
    NSAppearance* appearance = [NSApp effectiveAppearance];
    //NSLog(@"current appearance %@", appearance.name);
    //if (@available(macOS 10.14, *)) {
      NSArray* names = @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua];
      NSAppearanceName name = [appearance bestMatchFromAppearancesWithNames:names];
      return [name isEqualToString:NSAppearanceNameDarkAqua];
    //} else {
      // Fallback on earlier versions
    //}
  }
  else
  {
    NSString* style = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    return (style && [style isEqualToString:@"Dark"]);
  }
  return NO;
}
@end
