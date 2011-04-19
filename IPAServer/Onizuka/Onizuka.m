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
#import "Onizuka.h"

@interface Onizuka (Private)
-(void)localizeTextView:(NSTextView*)tv;
-(void)localizeTableView:(NSTableView*)item;
-(void)localizeForm:(NSForm*)form;
-(void)localizeMatrix:(NSMatrix*)matrix;
-(void)localizeSegmentedControl:(NSSegmentedControl*)item;
-(void)localizeComboBox:(NSComboBox*)box;
-(NSMutableString*)copyLocalizedTitle1Pass:(NSString*)title;
-(NSString*)bestLocalizedString:(NSString*)key value:(NSString*)val;
@end

@implementation Onizuka
static Onizuka* gSharedOnizuka = nil;
static const char* gRegexString = "__[A-Z]+(_[A-Z]+)*__";

+(Onizuka*)sharedOnizuka
{
  if (nil == gSharedOnizuka) gSharedOnizuka = [[Onizuka alloc] init];
  return gSharedOnizuka;
}

-(id)init
{
  self = [super init];
  // Uses the value of CFBundleName from Info.plist (which is localizable).
  // If not found, uses NSProcessInfo to get the name.
  NSBundle* mb = [NSBundle mainBundle];
  NSString* appname = [mb objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
  if (!appname) appname = [[NSProcessInfo processInfo] processName];
  _appName = [[NSString alloc] initWithString:appname];
  NSString* version = [mb objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if (!version) version = @"1.0";
  _appVersion = [[NSString alloc] initWithString:version];
  if (0 != regcomp(&_regex, gRegexString, REG_EXTENDED))
    [NSException raise:@"OnizukaException"
                 format:@"Error: could not compile Onizuka regex '%s'", gRegexString];
  return self;
}

-(void)dealloc
{
  [_appName release];
  regfree(&_regex);
  [super dealloc];
}

-(NSString*)appName { return _appName; }
-(NSString*)appVersion { return _appVersion; }

-(void)localizeMenu:(NSMenu*)menu
{
  if (menu)
  {
    //NSLog(@"Localizing menu %@", menu);
    [self localizeObject:menu withTitle:nil];
    NSArray* items = [menu itemArray];
    NSEnumerator* enumerator = [items objectEnumerator];
    NSMenuItem* item;
    while ((item = [enumerator nextObject]))
    {
      //NSLog(@"Localizing menu item %@", item);
      [self localizeObject:item withTitle:nil];
      if ([item submenu]) [self localizeMenu:[item submenu]];
    }
  }
}

-(void)localizeWindow:(NSWindow*)window
{
  [self localizeObject:window withTitle:nil];
  NSView* item = [window contentView];
  [self localizeView:item];
}

-(void)localizeView:(NSView*)view
{
  //NSLog(@"Localizing view (%@) %@", [view class], view);
  if ([view respondsToSelector:@selector(menu)])
  {
    //NSLog(@"Localizing view w/ menu: [%@ %@", [view class], view);
    [self localizeMenu:[view menu]];
  }
  [self localizeObject:view withTitle:nil];
  NSArray* items = nil;
  if ([view isKindOfClass:[NSTabView class]])
  {
    items = [(NSTabView*)view tabViewItems];
  }
  else if ([view isKindOfClass:[NSTabViewItem class]])
  {
    items = [[(NSTabViewItem*)view view] subviews];
  }
  else if ([view isKindOfClass:[NSTextView class]])
  {
    [self localizeTextView:(NSTextView*)view];
  }
  else if ([view isKindOfClass:[NSTableView class]])
  {
    [self localizeTableView:(NSTableView*)view];
  }
  else if ([view isKindOfClass:[NSForm class]])
  {
    [self localizeForm:(NSForm*)view];
  }
  else if ([view isKindOfClass:[NSMatrix class]])
  {
    [self localizeMatrix:(NSMatrix*)view];
  }
  else if ([view isKindOfClass:[NSComboBox class]])
  {
    [self localizeComboBox:(NSComboBox*)view];
  }
  else
  {
    // NSSegmentedControl is 10.3 only, so we use generic code so as not
    // to be dependent on the 10.3 SDK.
    id segctlClass = objc_getClass("NSSegmentedControl");
    if (segctlClass && [view isKindOfClass:segctlClass])
    {
      [self localizeSegmentedControl:(NSSegmentedControl*)view];
    }
    else items = [view subviews];
  }
  if (items)
  {
    NSEnumerator* enumerator = [items objectEnumerator];
    NSView* item;
    while ((item = [enumerator nextObject]))
    {
      [self localizeView:item];
    }
  }
}

-(void)localizeTextView:(NSTextView*)tv
{
  NSTextStorage* ts = [tv textStorage];
  NSString* str = [ts string];
  NSString* localized = [self copyLocalizedTitle:str];
  NSRange range = NSMakeRange(0, 1);
  NSDictionary* attrs = [ts attributesAtIndex:0 effectiveRange:&range];
  range.length = [str length];
  NSAttributedString* attrStr = [[NSAttributedString alloc] initWithString:localized attributes:attrs];
  [localized release];
  [ts replaceCharactersInRange:range withAttributedString:attrStr];
  [attrStr release];
}

-(void)localizeTableView:(NSTableView*)item
{
  NSTableView* tv = item;
  NSArray* cols = [tv tableColumns];
  NSEnumerator* enumerator = [cols objectEnumerator];
  NSTableColumn* col;
  while ((col = [enumerator nextObject]))
    [self localizeObject:[col headerCell] withTitle:nil];
}

-(void)localizeForm:(NSForm*)form
{
  unsigned i = 0;
  while (YES)
  {
    NSFormCell* cell = [form cellAtIndex:i];
    if (nil == cell) break;
    [self localizeObject:cell withTitle:nil];
    i++;
  }
}

-(void)localizeMatrix:(NSMatrix*)matrix
{
  NSUInteger i = 0, j = 0;
  NSUInteger rows = [matrix numberOfRows];
  NSUInteger cols = [matrix numberOfColumns];
  for (i = 0; i < rows; i++)
  {
    for (j = 0; j < cols; j++)
    {
      NSCell* cell = [matrix cellAtRow:i column:j];
      [self localizeObject:cell withTitle:nil];
    }
  }
}

-(void)localizeSegmentedControl:(NSSegmentedControl*)item
{
  NSInteger i, nsegs = [item segmentCount];
  for (i = 0; i < nsegs; i++)
  {
    NSString* lab = [self copyLocalizedTitle:[item labelForSegment:i]];
    [item setLabel:lab forSegment:i];
    [lab release];
    [self localizeMenu:[item menuForSegment:i]];
  }
}

-(void)localizeComboBox:(NSComboBox*)box
{
  if (![box usesDataSource])
  {
    NSArray* objs = [box objectValues];
    NSEnumerator* enumerator = [objs objectEnumerator];
    id val;
    NSMutableArray* newVals = [[NSMutableArray alloc] init];
    while ((val = [enumerator nextObject]))
    {
      id newVal = nil;
      if ([val isKindOfClass:[NSString class]])
      {
        newVal = [self copyLocalizedTitle:val];
        if (newVal) [newVal autorelease];
      }
      [newVals addObject:(newVal)? newVal:val];
    }
    [box removeAllItems];
    [box addItemsWithObjectValues:newVals];
    [newVals release];
  }
}

-(void)localizeObject:(id)item withTitle:(NSString*)title
{
  NSMutableString* localized;
  SEL getters[3] = {@selector(title),@selector(stringValue),@selector(label)};
  SEL setters[3] = {@selector(setTitle:),@selector(setStringValue:),@selector(setLabel:)};
  unsigned i;
  for (i = 0; i < 3; i++)
  {
    if ([item respondsToSelector:getters[i]] &&
        [item respondsToSelector:setters[i]])
    {
      if (!title) title = [item performSelector:getters[i] withObject:nil];
      if (title)
      {
        //NSLog(@"localizeObject: title %@", title);
        localized = [self copyLocalizedTitle:title];
        //NSLog(@"localized: %@", localized);
        [item performSelector:setters[i] withObject:localized];
        [localized release];
        break;
      }
    }
  }
}

// Always returns a string that must be released.
-(NSMutableString*)copyLocalizedTitle:(NSString*)title
{
  NSMutableString* localized = nil;
  NSMutableString* loc1 = [self copyLocalizedTitle1Pass:title];
  //NSLog(@"Pass 1: %@", loc1);
  if (loc1)
  {
    localized = [self copyLocalizedTitle1Pass:loc1];
    //NSLog(@"Pass 2: %@", localized);
    if (!localized) localized = loc1;
    else [loc1 release];
  }
  else localized = [[NSMutableString alloc] initWithString:title];
  return localized;
}

-(NSMutableString*)copyLocalizedTitle1Pass:(NSString*)title
{
  if (!title) return nil;
  NSMutableString* localized = nil;
  const char* s = [title UTF8String];
  regoff_t handled = 0L; // The last character we handled
  regmatch_t match = {0,strlen(s)};
  BOOL gotOne = NO;
  NSString* add;
  NSString* loc;
  //NSLog(@"%llu-%llu handled %llu", match.rm_so, match.rm_eo, handled);
  while (YES)
  {
    int e = regexec(&_regex, s, 1, &match, REG_STARTEND);
    if (e)
    {
      char errbuf[1000];
      regerror(e, &_regex, errbuf, 1000);
      if (e != REG_NOMATCH) NSLog(@"%d: %s", e, errbuf);
      break;
    }
    if (!localized) localized = [[NSMutableString alloc] init];
    gotOne = YES;
    //NSLog(@"regexec: %llu-%llu handled %llu", match.rm_so, match.rm_eo, handled);
    if (match.rm_so > handled)
    {
      add = [[NSString alloc] initWithBytes:s+handled
                              length:match.rm_so-handled
                              encoding:NSUTF8StringEncoding];
      [localized appendString:add];
      [add release];
    }
    add = [[NSString alloc] initWithBytes:s+match.rm_so
                            length:match.rm_eo-match.rm_so
                            encoding:NSUTF8StringEncoding];
    //NSLog(@"2 add=%@", add);
    if ([add isEqual:@"__APPNAME__"]) loc = _appName;
    else if ([add isEqual:@"__VERSION__"]) loc = _appVersion;
    else loc = [self bestLocalizedString:add value:add];
    [add release];
    [localized appendString:loc];
    handled = match.rm_eo;
    match.rm_so = match.rm_eo;
    match.rm_eo = strlen(s);
  }
  if (gotOne && handled < strlen(s))
  {
    add = [[NSString alloc] initWithBytes:s+handled
                            length:strlen(s)-handled
                            encoding:NSUTF8StringEncoding];
    //NSLog(@"3 add=%@", add);
    if ([add isEqual:@"__APPNAME__"]) loc = _appName;
    else if ([add isEqual:@"__VERSION__"]) loc = _appVersion;
    else loc = [self bestLocalizedString:add value:add];
    [add release];
    [localized appendString:loc];
  }
  //if (localized) NSLog(@"return >>%@<<", localized);
  return localized;
}

-(NSString*)bestLocalizedString:(NSString*)key value:(NSString*)val
{
  NSString* localized = NSLocalizedString(key, val);
  if ([localized isEqual:key])
  {
    NSBundle* mb = [NSBundle mainBundle];
    NSArray* locs = [NSBundle preferredLocalizationsFromArray:[mb preferredLocalizations]];
    NSEnumerator* iter = [locs objectEnumerator];
    NSString* lang;
    BOOL gotIt = NO;
    while ((lang = [iter nextObject]) && !gotIt)
    {
      NSString* p = [mb pathForResource:@"Localizable" ofType:@"strings"
                        inDirectory:nil forLocalization:lang];
      NSDictionary* strings = [[NSDictionary alloc] initWithContentsOfFile:p];
      localized = [strings objectForKey:key];
      if (localized)
      {
        localized = [NSString stringWithString:localized];
        gotIt = YES;
      }
      [strings release];
    }
  }
  if (!localized) localized = val;
  return localized;
}

@end
