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
#import <Cocoa/Cocoa.h>
#include <regex.h>

/* 
  This code is named for Onizuka Eikichi of the Japanese manga/anime/drama/film
  GTO "Great Teacher Onizuka", which holds a special place in my heart.
  I'm not sure I recall why I named it Onizuka -- maybe I was thinking GTO
  could also stand for "Great Translator Onizuka".

  Anyway, this code is for one-nib-many-languages localization. Which means you
  have lots of Localizable.strings but only one MainMenu.nib and strings from
  the former are inserted in the latter at runtime. Obviously, care must be
  taken with item labels as they can suffer great length differences.
  But I like this over Apple's current approach (massive redundancy violation
  of SPOT rule: fundamental flaw) because I like stuff that generalizes.

  To use the code, instantiate the singleton "Onizuka" and give it a window,
  menu, or view to work on. The code recursively walks the view hierarchy and
  localizes anything with a string value or title or label that looks like
  __BLAH_BLAH__ (uppercase alphabetic substrings separated by underscores,
  and flanked by two underscores) if the placeholder title can be found in
  Localizable.strings. It does this in a two-pass manner, so you can have
  strings file entries like this:
  "__BLAH__" = "Blah blah __BLEH__ __APPNAME__ __VERSION__";
  "__BLEH__" = "Bleh";

  Onizuka understands the special expressions __APPNAME__ and __VERSION__ which
  are determined at runtime and do not need to be localized.
  Onizuka uses the CFBundleName from Info.plist or the process info for
  __APPNAME__, and CFBundleShortVersionString for __VERSION__.

  Some container classes -- or those with a special accessor for cells or
  subviews -- probably are not covered by the current code. Submissions welcome.
*/

#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSINTEGER_DEFINED 1
#endif

@interface Onizuka : NSObject
{
  NSString*  _appName;    // Used for menu items like "About MyApp...".
  NSString*  _appVersion; // The short version string like "2.0.1".
  regex_t    _regex;      // Matches __BLAH_BLAH__
}
+(Onizuka*)sharedOnizuka;
-(NSString*)appName;
-(NSString*)appVersion;
-(void)localizeMenu:(NSMenu*)menu;
-(void)localizeWindow:(NSWindow*)window;
-(void)localizeView:(NSView*)window;
// Low-level method that localizes item via setLabel: setTitle: or
// setStringValue: (using the first method that item responds to).
// If title is nil, uses existing label, title, or value.
// Generally this is used internally when you call one of the three high-level
// methods above. You would typically use a non-nil title when changing an item
// in response to some change in application  state, for example:
//   [[Onizuka sharedOnizuka] localizeObject:myTextField
//                            withTitle:@"__NETWORK_ERROR__"];
-(void)localizeObject:(id)item withTitle:(NSString*)title;
-(NSMutableString*)copyLocalizedTitle:(NSString*)title;
// Returns an autoreleased string
-(NSString*)bestLocalizedString:(NSString*)key value:(NSString*)val;
@end
