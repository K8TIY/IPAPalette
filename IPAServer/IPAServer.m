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
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "IPAServer.h"
#import "Onizuka.h"
#import "Placeholder.h"
#import "CMAPParser.h"
#import "PDFImageMapCreator.h"

@interface NSArray (IPAPalette)
-(NSArray*)slice:(unsigned)size;
@end

@implementation NSArray (IPAPalette)
-(NSArray*)slice:(unsigned)size
{
  NSUInteger ct = [self count];
  NSUInteger slices = (ct/size) + ((ct%size)? 1:0);
  NSMutableArray* ary = [NSMutableArray arrayWithCapacity:slices];
  NSUInteger n = 1;
  NSUInteger offset = 0;
  while (n <= slices)
  {
    NSUInteger rest = (n==slices)? (ct-(size*(n-1))):size;
    [ary addObject:[self subarrayWithRange:NSMakeRange(offset, rest)]];
    n++;
    offset += rest;
  }
  return ary;
}
@end

@implementation IPAApplication
-(void)setIsActive:(BOOL)flag { [(id)super setIsActive:flag]; }
-(void)_deactivateWindows { [(id)super _deactivateWindows]; }
@end

static CFDataRef local_MPCallback(CFMessagePortRef port, SInt32 msg, CFDataRef data, void* ctx);
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5
static BOOL uisspace(unichar ch);
#endif
static NSComparisonResult local_SearchResultComparisonCallback(id item1, id item2, void* something);

@implementation IPASearchResults
-(BOOL)acceptsFirstResponder {return NO;}

// It doesn't seem reasonable to allow dragging table Unicode strings to ourselves,
// so we don't allow dragging IPA symbols to the search field (or anywhere
// else in the Palette). We do a "copy" operation so we get the +-sign cursor badge when dragging
// into a nonlocal target, i.e., another application.
-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return (isLocal)? NSDragOperationNone:NSDragOperationCopy;
}
@end

@implementation IPASearchField
// NSTextField doesn't respond to edit commands even when we are key, either
// because of our "skanky hack" or because we are LSUIElement and
// have no menu bar. NSTextField is sent performKeyEquivalent, but for whatever
// reason it does nothing (maybe it's looking for the menu bar and bailing out
// when it can't find it), hence this subclass.
-(BOOL)performKeyEquivalent:(NSEvent*)evt
{
  BOOL handled = NO;
  if ([evt modifierFlags] & NSCommandKeyMask)
  {
    handled = YES;
    NSString* chars = [evt charactersIgnoringModifiers];
    NSText* fe = [[self window] fieldEditor:YES forObject:self];
    if ([chars isEqual:@"a"]) [fe selectAll:self];
    else if ([chars isEqual:@"c"]) [fe copy:self];
    else if ([chars isEqual:@"v"]) [fe paste:self];
    else if ([chars isEqual:@"x"]) [fe cut:self];
    else handled = [super performKeyEquivalent:evt];
  }
  return handled;
}

-(BOOL)acceptsFirstResponder {return YES;}
@end

@implementation IPAPanel
-(BOOL)canBecomeKeyWindow {return YES;}
-(BOOL)canBecomeMainWindow {return NO;}

-(void)awakeFromNib
{
  [self setBecomesKeyOnlyIfNeeded:YES];
}
@end

@interface IPAServer (Private)
-(void)addIPAFonts:(id)me;
-(void)runFontAlert;
-(void)userGlyphsChanged:(id)sender;
-(NSDictionary*)charactersForIPA:(NSString*)ipa modifiers:(NSUInteger)modifiers;
-(NSString*)longDescriptionForCodepoints:(NSString*)codepoints withFallback:(NSString*)fb;
-(void)local_SendIPAForString:(NSString*)ipa modifiers:(NSUInteger)modifiers;
-(void)doSearch;
-(void)setComponentDebug:(NSInteger)level;
-(int)debug;
-(void)PDFImageMap:(PDFImageMap*)map didChangeSelection:(NSString*)key;
-(void)updateDisplays:(id)hit;
-(void)selectAnotherTab:(BOOL)prev;
-(void)die:(NSTimer*)t;
-(void)setPaletteVisible:(BOOL)vis;
-(void)sendMessage:(IPAMessage)msg withData:(NSData*)data;
-(void)deactivateAppAndWindows;
-(NSArray*)arrayWithStringSplitOnSpace:(NSString*)str;
@end



@implementation IPAServer
static NSString* ipaPlaceholderCircleString = nil;

// charactersForIPA:modifiers: returns a dict with the following keys:
static NSString* ipaStringToSendKey       = @"ToSend";      // NSString
static NSString* ipaStringForGlyphViewKey = @"GlyphView";   // NSString
static NSString* ipaStringCodepointsKey   = @"Codepoints";  // NSString
static NSString* ipaStringSymbolTypeKey   = @"SpelledOut";  // NSString

// Defaults that have registerable values
static NSString* ipaFontKey = @"Font";
static NSString* ipaFontDefault = @"Doulos SIL";
static NSString* ipaDebugKey = @"Debug";
static NSString* ipaComponentDebugKey = @"ComponentDebug";
static NSString* ipaTabKey = @"Tab";
static NSString* ipaTabDefault = @"Vowel";
static NSString* ipaTimeoutKey = @"Timeout";
static NSString* ipaDontShowAgainKey = @"DontShowAgain";
static NSString* ipaUserFontsKey = @"UserFonts";
static NSString* ipaUserGlyphsKey = @"UserGlyphs";
static NSString* ipaUserGlyphDescriptionsKey = @"UserGlyphDescriptions";
static NSString* ipaFallbackKey = @"GlyphFallback";
// These will not be registered; filled in later
static NSString*  ipaFrameKey = @"PaletteFrame";


+(void)initialize
{
  ipaPlaceholderCircleString = [[NSString alloc] initWithCharacters:&PlaceholderDottedCircle length:1L];
  NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
  NSDictionary* defs = [[NSDictionary alloc] initWithObjectsAndKeys:
    ipaFontDefault,               ipaFontKey,
    [NSNumber numberWithInt:0],   ipaDebugKey,
    [NSNumber numberWithInt:0],   ipaComponentDebugKey,
    ipaTabDefault,                ipaTabKey,
    [NSNumber numberWithInt:900], ipaTimeoutKey,
    [NSNumber numberWithInt:0],   ipaDontShowAgainKey,
    [NSArray array],              ipaUserFontsKey,
    [NSArray array],              ipaUserGlyphsKey,
    [NSDictionary dictionary],    ipaUserGlyphDescriptionsKey,
    [NSNumber numberWithInt:0],   ipaFallbackKey,
    NULL];
  [ud registerDefaults:defs];
  [defs release];
}

// Caller disposes
// Given a string such as "i j", produces "U+0069 U+006A" with hex codepoints.
+(NSString*)copyUPlusForString:(NSString*)str
{
  NSMutableString* uplus = [[NSMutableString alloc] init];
  NSUInteger nchars = [str length];
  NSUInteger i;
  for (i = 0; i < nchars; i++)
  {
    unichar uc = [str characterAtIndex:i];
    [uplus appendFormat:@"%sU+%.4X", ([uplus length])?" ":"", uc];
  }
  return uplus;
}

-(id)init
{
  self = [super init];
  CFMessagePortContext context = {0,NULL,NULL,NULL,NULL};
  //  Create a port on which we will listen for messages.
  context.info = self;
  CFMessagePortRef port = CFMessagePortCreateLocal(NULL, (CFStringRef)kIPAServerListenPortName,
                                                   local_MPCallback, &context, NULL);
  if (!port) NSLog(@"error: CFMessagePortCreateLocal failed");
  else
  {
    //  Set up the port with the run loop.
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    if (!runLoop) NSLog(@"error: CFRunLoopGetCurrent failed");
    else
    {
      CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, port, 0);
      if (!source) NSLog(@"error: CFMessagePortCreateRunLoopSource failed");
      else
      {
        CFRunLoopAddSource(runLoop, source, kCFRunLoopCommonModes);
        CFRelease(source);
      }
    }
    CFRelease(port);
  }
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  _debug = [defs integerForKey:ipaDebugKey];
  _timeout = [defs integerForKey:ipaTimeoutKey];
  if (_debug >= ipaVerboseDebugLevel) NSLog(@"Set timeout to %d seconds", _timeout);
  return self;
}

-(void)awakeFromNib
{
  _hidden = 1;
  [_fontMenu removeAllItems];
  [_window setFrameUsingName:ipaFrameKey];
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  NSInteger cdebug = [defs integerForKey:ipaComponentDebugKey];
  [_componentDebugMenu selectItemAtIndex:cdebug];
  [self setComponentDebug:cdebug];
  NSInteger fb = [defs integerForKey:ipaFallbackKey];
  [_fallbackMenu selectItemAtIndex:fb];
  [self fallbackAction:_fallbackMenu];
  // Get the hot rect locations from the main image map data file
  NSString* path = [[NSBundle mainBundle] pathForResource:@"MapData" ofType:@"plist"];
  NSArray* dat = [[NSArray alloc] initWithContentsOfFile:path];
  NSDictionary* entry;
  NSEnumerator* enumerator = [dat objectEnumerator];
  while ((entry = [enumerator nextObject]))
  {
    NSString* key = [entry objectForKey:@"char"];
    NSString* chart = [entry objectForKey:@"chart"];
    SubRect r = NSRectFromString([entry objectForKey:@"rect"]);
    if ([chart isEqual:@"consonant"]) [_consonants setTrackingRect:r forKey:key];
    else if ([chart isEqual:@"vowel"]) [_vowels setTrackingRect:r forKey:key];
    else if ([chart isEqual:@"supratone"]) [_supra setTrackingRect:r forKey:key];
    else if ([chart isEqual:@"diacritic"]) [_diacritic setTrackingRect:r forKey:key];
    else if ([chart isEqual:@"other"]) [_other setTrackingRect:r forKey:key];
    else if ([chart isEqual:@"extipa"]) [_extipa setTrackingRect:r forKey:key];
  }
  [dat release];
  // Load the alternate image for vowel drag images
  path = [[NSBundle mainBundle] pathForResource:@"VowDrag" ofType:@"pdf"];
  NSImage* whatadrag = [[NSImage alloc] initWithContentsOfFile:path];
  [_vowels setDragImage:whatadrag];
  [whatadrag release];
  // Load info on superscripts and /above/below alternations
  path = [[NSBundle mainBundle] pathForResource:@"Alts" ofType:@"strings"];
  _alts = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
  [_debugMenu selectItemAtIndex:_debug];
  [_spinny startAnimation:self];
  [NSApp setDelegate:self];
  _fontMenuSuperview = [_fontMenu superview];
  [_fontMenu retain];
  [_fontMenu removeFromSuperview];
  [[Onizuka sharedOnizuka] localizeWindow:_window];
  [_unicodeText setStringValue:@""];
  [_descriptionText setStringValue:@""];
  _searchResults = [[NSMutableArray alloc] init];
  _descToGlyph = [[NSMutableDictionary alloc] init];
  NSString* locs = [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings"];
  // Turn the appropriate strings file into a dictionary and iterate thru
  // it, looking for anything that starts with "U+..." and setting the
  // localized description as key for the U+ string data.
  NSDictionary* d = [NSDictionary dictionaryWithContentsOfFile:locs];
  enumerator = [d keyEnumerator];
  NSString* glyph;
  while ((glyph = [enumerator nextObject]))
  {
    if ([glyph length] > 2 && [[glyph substringToIndex:2L] isEqual:@"U+"])
    {
      NSString* desc = [d objectForKey:glyph];
      glyph = [glyph substringFromIndex:2L];
      [_descToGlyph setValue:glyph forKey:desc];
    }
  }
  [_searchResultsTable setDoubleAction:@selector(tableDoubleAction:)];
  [_searchResultsTable setTarget:self];
  [_userGlyphsController setGlyphs:[defs objectForKey:ipaUserGlyphsKey]
                         andDescriptions:[defs objectForKey:ipaUserGlyphDescriptionsKey]];
  [self userGlyphsChanged:self];
  // Workaround for problem with making search field First Responder
  // the first time. So we switch to it and then back to Vowel.
  // Then we can switch to whichever tab was last open.
  [_tabs selectTabViewItemWithIdentifier:@"Search"];
  [_tabs selectTabViewItemWithIdentifier:@"Vowel"];
  id obj = [defs objectForKey:ipaTabKey];
  if (obj && [_tabs indexOfTabViewItemWithIdentifier:obj] != NSNotFound) [_tabs selectTabViewItemWithIdentifier:obj];
  [self setPaletteVisible:YES];
  [NSApplication detachDrawingThread:@selector(addIPAFonts:) toTarget:self withObject:nil];
}

#define kLezh 0x026E // LZh digraph U+026E
#define kBeta 0x03B2 // Greek small letter beta
-(void)addIPAFonts:(id)ignore
{
  NSMutableArray* fontNames = [[NSMutableArray alloc] init];
  OSStatus err;
  NSMutableArray* fonts = [[[NSFontManager sharedFontManager] availableFonts] mutableCopy];
  NSEnumerator* enumerator = [fonts objectEnumerator];
  NSString* font;
  while ((font = [enumerator nextObject]))
  {
    if (![font isEqualToString:@"LastResort"])
    {
      ByteCount neededSize;
      ATSFontRef atsf = ATSFontFindFromPostScriptName((CFStringRef)font, kATSOptionFlagsDefault);
      err = ATSFontGetTable(atsf, 'cmap', 0, 0, NULL, &neededSize);
      if (err) NSLog(@"  ATSFontGetTable '%@' err=%d, size=%ld", font, err, neededSize);
      else
      {
        char* buffer = malloc(neededSize);
        err = ATSFontGetTable(atsf, 'cmap', 0, neededSize, buffer, &neededSize);
        if (err) NSLog(@"  ATSFontGetTable '%@' err=%d, size=%ld", font, err, neededSize);
        if (!err && CMAPHasChar(buffer, kLezh) && CMAPHasChar(buffer, kBeta))
        {
          CFStringRef readable;
          err = ATSFontGetName(atsf, kATSOptionFlagsDefault, &readable);
          [fontNames addObject:(NSString*)readable];
          //NSLog(@"Adding %@", readable);
          CFRelease(readable);
        }
      }
    }
  }
  [fonts release];
  // Now let's add in any custom fonts added by the user.
  NSString* name;
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  NSArray* userFonts = [defs objectForKey:ipaUserFontsKey];
NS_DURING
  if (userFonts && [userFonts isKindOfClass:[NSArray class]] && [userFonts count])
  {
    enumerator = [userFonts objectEnumerator];
    while ((name = [enumerator nextObject])) [fontNames addObject:(NSString*)name];
  }
NS_HANDLER
  NSLog(@"ERROR: had problem loading user fonts: %@", [localException reason]);
NS_ENDHANDLER
  [fontNames sortUsingSelector: @selector(compare:)];
  NSEnumerator* e = [fontNames objectEnumerator];
  NSString* fontName;
  while ((fontName = [e nextObject]))
  {
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:fontName action:nil keyEquivalent:@""];
    [[_fontMenu menu] addItem:item];
    [item release];
  }
  // See if the user has selected a font before
  name = [defs objectForKey:ipaFontKey];
  if ([fontNames containsObject:name]) [_fontMenu selectItemWithTitle:name];
  else
  {
    if (_debug >= ipaDebugDebugLevel) NSLog(@"preferred font '%@' not found, falling back to Doulos SIL.", name);
    if ([fontNames containsObject:@"Doulos SIL"]) [_fontMenu selectItemWithTitle:@"Doulos SIL"];
    else
    {
      if ([_fontMenu numberOfItems])
      {
        if (_debug >= ipaDebugDebugLevel) NSLog(@"recommended Doulos SIL font not found, falling back to first in menu.");
        [_fontMenu selectItemAtIndex:0L];
      }
      else
      {
        if (![defs integerForKey:ipaDontShowAgainKey])
        {
          [self runFontAlert];
        }
      }
    }
  }
  [fontNames release];
  [_spinny stopAnimation:self];
  [_spinny removeFromSuperview];
  _spinny = nil;
  [_glyphView setNeedsDisplay:YES];
  [_scanningText removeFromSuperview];
  _scanningText = nil;
  [_fontMenuSuperview addSubview:_fontMenu];
  // This started crashing in 10.4.6 if I called it directly from this thread.
  // Doesn't do so any more, probably since GlyphView was rewritten.
  // But just in case, this seems safer.
  if ([_fontMenu numberOfItems] > 0)
    [self performSelectorOnMainThread:@selector(fontAction:) withObject:_fontMenu waitUntilDone:YES];
  else [_fontMenu setEnabled:NO];
}

-(void)runFontAlert
{
  [[Onizuka sharedOnizuka] localizeWindow:_alert];
  NSString* typeStr = NSFileTypeForHFSTypeCode(kAlertCautionIcon);
  NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType:typeStr];
  if (icon) [_alertIcon setImage:icon];
  [NSApp beginSheet:_alert modalForWindow:_window
         modalDelegate:self didEndSelector:@selector(closeAlertAction:)
         contextInfo:nil];
}

-(IBAction)closeAlertAction:(id)sender
{
  if ([_dontShowAgainButton state] == NSOnState)
    [[NSUserDefaults standardUserDefaults] setInteger:1L forKey:ipaDontShowAgainKey];
  [NSApp endSheet:_alert];
  [_alert orderOut:nil];
}

-(IBAction)addSymbolAction:(id)sender
{
  #pragma unused (sender)
  [_userGlyphsController edit];
}

//#define kUGMargin (10.0)
//#define kUGHeight (256.0)
-(void)userGlyphsChanged:(id)sender
{
  #pragma unused (sender)
  NSArray* glyphs = [_userGlyphsController glyphs];
  NSDictionary* descriptions = [_userGlyphsController descriptions];
  NSInteger where = [_tabs indexOfTabViewItemWithIdentifier:@"User"];
  if ([glyphs count] == 0)
  {
    _userGlyphsTab = [_tabs tabViewItemAtIndex:where];
    [_userGlyphsTab retain];
    [_tabs removeTabViewItem:_userGlyphsTab];
  }
  else
  {
    if (where == NSNotFound)
    {
      [_tabs insertTabViewItem:_userGlyphsTab atIndex:3L];
      [_userGlyphsTab release];
    }
    // FIXME: set the width of the image to the number of slices times the height of the image divided by 6.
    NSArray* data = [glyphs slice:6];
    [PDFImageMapCreator setPDFImapgeMap:_user toData:data ofType:PDFImageMapColumnar];
    if ([_tabs selectedTabViewItem] == _userGlyphsTab) [_user startTracking];
  }
  [[NSUserDefaults standardUserDefaults] setObject:glyphs forKey:ipaUserGlyphsKey];
  [[NSUserDefaults standardUserDefaults] setObject:descriptions forKey:ipaUserGlyphDescriptionsKey];
}

-(IBAction)updatesAction:(id)sender
{
  if (!_updateData)
  {
    _updateData = [[NSMutableData alloc] init];
    [[Onizuka sharedOnizuka] localizeObject:_updateResults withTitle:@"__LOOKING_FOR_UPDATES__"];
    NSURL* url = [NSURL URLWithString:@"http://www.blugs.com/IPA/version.txt"];
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    _updateCheck = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  }
}

-(IBAction)downloadUpdatesAction:(id)sender
{
  NSString* where = @"http://www.blugs.com/IPA/IPAPalette.dmg";
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:where]];
  [_updateButton setEnabled:NO];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
  [_updateData appendData:data];
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
  [_updateResults performSelectorOnMainThread:@selector(setStringValue:) withObject:[error localizedDescription] waitUntilDone:NO];
  [_updateData release];
  _updateData = nil;
  [_updateCheck release];
  _updateCheck = nil;
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
  NSString* versHere = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
  NSString* temp = [[NSString alloc] initWithData:_updateData encoding:NSUTF8StringEncoding];
  NSString* versThere = [temp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  [temp release];
  //NSLog(@">>%@<<==>>%@<<?", versHere, versThere);
  BOOL gotOne = ([versHere compare:versThere]==NSOrderedAscending);
  NSString* results;
  NSString* fmt = nil;
  if (gotOne)
  {
    fmt = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__HAVE_UPDATE__"];
    results = [NSString stringWithFormat:fmt, versThere];
    [[Onizuka sharedOnizuka] localizeObject:_updateButton withTitle:@"__DOWNLOAD__"];
    [_updateButton setAction:@selector(downloadUpdatesAction:)];
  }
  else
  {
    fmt = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__NO_UPDATE__"];
    results = [NSString stringWithFormat:fmt, [[Onizuka sharedOnizuka] appVersion], versHere];
  }
  [fmt release];
  [_updateResults setStringValue:results];
  [_updateData release];
  _updateData = nil;
  [_updateCheck release];
  _updateCheck = nil;
}

-(void)setPaletteVisible:(BOOL)vis
{
  if (vis != [_window isVisible])
  {
    BOOL isMin = [_window isMiniaturized];
    if (_debug >= ipaDebugDebugLevel)
      NSLog(@"setPaletteVisible:%s isMin=%s [_window isVisible]=%s",
            (vis)? "YES" : "NO", (isMin)? "YES" : "NO",
            ([_window isVisible])? "YES" : "NO");
    if (_timer) [_timer invalidate];
    _timer = nil;
    if (vis)
    {
      // We get activation messages when we switch apps.
      // If the window is miniaturized, just let it sit there.
      // FIXME: we don't distinguish between the reasons this is being called.
      // Switching apps is one reason.
      // Selecting 'Show IPA Palette' menu item is another.
      // In the former case, we should leave it miniaturized.
      if ((isMin && _hidden) || !isMin)
      {
        if (_debug >= ipaDebugDebugLevel) NSLog(@"calling [_window orderFrontRegardless];");
        [_window orderFrontRegardless];
      }
      _hidden = NO;
      //_timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self
      //                  selector:@selector(updateDisplays:) userInfo:nil repeats:YES];
    }
    else
    {
      [_window orderOut:nil];
      //if (isMin) [_window deminiaturize:nil];
      //_haveHitTested = NO;
      _timer = [NSTimer scheduledTimerWithTimeInterval:_timeout target:self
                        selector:@selector(die:) userInfo:nil repeats:NO];
    }
    if (_timer) [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
  }
}

// Returns an autoreleased dictionary or nil
-(NSDictionary*)charactersForIPA:(NSString*)ipa modifiers:(NSUInteger)modifiers
{
  NSMutableDictionary* d = nil;
  if (ipa)
  {
    NSInteger nChars = [ipa length];
    if (nChars)
    {
      NSString* primary = ipa;
      NSString* secondary = nil;
      d = [[NSMutableDictionary alloc] init];
      if (modifiers & NSShiftKeyMask || modifiers & NSAlternateKeyMask)
      {
        NSString* alt = [_alts objectForKey:ipa];
        if (alt)
        {
          primary = alt;
          secondary = ipa;
          if (_debug >= ipaInsaneDebugLevel) NSLog(@"Alternation: '%@' to '%@'", ipa, alt);
        }
      }
      BOOL needPlaceholder = NeedsPlaceholder([primary characterAtIndex:0]);
      NSString* toSend = [[NSMutableString alloc] initWithString:primary];
      NSString* toDisplay = [[NSString alloc] initWithFormat:@"%@%@",
                            (needPlaceholder)? ipaPlaceholderCircleString:@"", primary];
      NSString* codepoints1 = [IPAServer copyUPlusForString:primary];
      NSString* codepoints2 = [IPAServer copyUPlusForString:secondary];
      NSString* longdesc = [self longDescriptionForCodepoints:codepoints1 withFallback:codepoints2];
      [d setObject:toSend forKey:ipaStringToSendKey];
      [d setObject:toDisplay forKey:ipaStringForGlyphViewKey];
      [d setObject:codepoints1 forKey:ipaStringCodepointsKey];
      [d setObject:longdesc forKey:ipaStringSymbolTypeKey];
      [toSend release];
      [toDisplay release];
      [codepoints1 release];
      [codepoints2 release];
      [d autorelease];
    }
  }
  return d;
}

// For superscript forms, we have to try twice to get the long description.
// First we try to get a longdesc for the superscript form. This covers superscript 'h' which
//  has a special description ('aspiration').
// If there is no such description (like for, e.g., superscript 's') then we use the description
//  for the non-superscript form, and maybe localized suffix like ' (superscript)' on the end.
// First, we use the English desc as the default, since we expect the localizedStringForKey
// lookup to fail in some cases for non-English locales, as localization has so far been
// gradual. It also could turn out that the English descriptions are naturalized within the
// phonetics community; it remains to be seen how true this is.
// First we try the localized desc for the primary codes we're sending to the component,
//   falling back to English.
// If that fails, it will return an empty string or the key.
//   In which case, if we have a fallback, we try that in a similar way.
// Docs say the localizedString methods never return nil.
-(NSString*)longDescriptionForCodepoints:(NSString*)codepoints withFallback:(NSString*)fb
{
  NSDictionary* udescs = [_userGlyphsController descriptions];
  NSString* longdesc = [udescs objectForKey:codepoints];
  if (!longdesc)
  {
    longdesc = [udescs objectForKey:fb];
    if (!longdesc)
    {
      longdesc = [[Onizuka sharedOnizuka] bestLocalizedString:codepoints];
      if (!longdesc)
      {
        longdesc = [[Onizuka sharedOnizuka] bestLocalizedString:fb];
        if (!longdesc)  longdesc = @"";
      }
    }
  }
  return longdesc;
}

-(IBAction)imageAction:(id)sender
{
  NSUInteger mods = [sender modifiers];
  [self local_SendIPAForString:[sender stringValue] modifiers:mods];
}

-(void)local_SendIPAForString:(NSString*)ipa modifiers:(NSUInteger)modifiers
{
  NSDictionary* d = [self charactersForIPA:ipa modifiers:modifiers];
  if (d)
  {
    NSString* toSend = [d objectForKey:ipaStringToSendKey];
    if (toSend)
    {
      if (modifiers & NSControlKeyMask)
      {
        NSString* fontName = [[_fontMenu selectedItem] title];
        if (_debug >= ipaDebugDebugLevel) NSLog(@"Will try to synchronize font to %@", fontName);
        CFDataRef data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, (CFStringRef)fontName, kCFStringEncodingUTF8, 0x3F);
        [self sendMessage:ipaFontMsg withData:(NSData*)data];
        CFRelease(data);
      }
      CFDataRef data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, (CFStringRef)toSend, kCFStringEncodingUTF8, 0x3F);
      [self sendMessage:ipaInputMsg withData:(NSData*)data];
      CFRelease(data);
    }
  }
}

-(IBAction)fontAction:(id)sender
{
  NSMenuItem* item = [sender selectedItem];
  if (item)
  {
    NSString* font = [item title];
    [_glyphView setFont:font];
    [[NSUserDefaults standardUserDefaults] setObject:font forKey:ipaFontKey];
  }
}

-(IBAction)debugAction:(id)sender
{
  _debug = [sender indexOfSelectedItem];
  if (_debug != ipaSilentDebugLevel) NSLog(@"setting debug level to %d", _debug);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedChar:_debug] forKey:ipaDebugKey];
}

-(IBAction)componentDebugAction:(id)sender
{
  uint8_t dbg = [sender indexOfSelectedItem];
  [self setComponentDebug:dbg];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedChar:dbg] forKey:ipaComponentDebugKey];
}

-(IBAction)fallbackAction:(id)sender
{
  NSInteger fba = [sender indexOfSelectedItem];
  [_glyphView setFallbackBehavior:fba];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedChar:fba] forKey:ipaFallbackKey];
}

-(void)doSearch
{
  NSMutableDictionary* composite = [[NSMutableDictionary alloc] initWithDictionary:_descToGlyph];
  NSDictionary* udescs = [_userGlyphsController descriptions];
  NSEnumerator* enu = [udescs keyEnumerator];
  NSString* ipa;
  while ((ipa = [enu nextObject]))
    [composite setObject:[ipa substringFromIndex:2] forKey:[udescs objectForKey:ipa]];
  enu = [composite keyEnumerator];
  NSString* search = [_searchText stringValue];
  NSArray* terms = [self arrayWithStringSplitOnSpace:search];
  [_searchResults removeAllObjects];
  if ([search length] && [terms count])
  {
    NSString* desc;
    while ((desc = [enu nextObject]))
    {
      NSEnumerator* enu2 = [terms objectEnumerator];
      NSString* term;
      BOOL hasAll = YES;
      while ((term = [enu2 nextObject]))
      {
        NSRange where = [desc rangeOfString:term options:NSCaseInsensitiveSearch];
        if (where.location == NSNotFound || where.length == 0) hasAll = NO;
      }
      if (hasAll)
      {
        NSString* hex = [composite objectForKey:desc];
        NSScanner* scanner = [[NSScanner alloc] initWithString:hex];
        unsigned asint;
        if ([scanner scanHexInt:&asint])
        {
          ipa = nil;
          // Very special cases: two characters! (First U+ has already been trimmed)
          if ([hex isEqual:@"01C3 U+00A1"])
          {
            ipa = [NSString stringWithFormat:@"%C%C", 0x01C3, 0x00A1];
          }
          else if ([hex isEqual:@"0346 U+032A"])
          {
            ipa = [NSString stringWithFormat:@"%C%C", 0x0346, 0x032A];
          }
          else
          {
            unichar uchar = (unichar)asint;
            ipa = [NSString stringWithCharacters:&uchar length:1L];
          }
          NSDictionary* d = [self charactersForIPA:ipa modifiers:0L];
          ipa = [d objectForKey:ipaStringToSendKey];
          NSString* gv = [d objectForKey:ipaStringForGlyphViewKey];
          NSString* codes = [d objectForKey:ipaStringCodepointsKey];
          [_searchResults addObject:[NSArray arrayWithObjects:ipa,gv,desc,codes,NULL]];
        }
        [scanner release];
      }
    }
  }
  [composite release];
  if ([_searchResults count]) [_searchResults sortUsingFunction:&local_SearchResultComparisonCallback context:nil];
  [_searchResultsTable reloadData];
  [_searchResultsTable scrollRowToVisible:0];
}

-(void)setComponentDebug:(NSInteger)level
{
  if (_debug > ipaVerboseDebugLevel) NSLog(@"setting component debug level to %d", level);
  // Send the debug level to the component
  NSData* sendData = [[NSData alloc] initWithBytes:&level length:sizeof(level)];
  [self sendMessage:ipaDebugMsg withData:sendData];
  [sendData release];
}

-(int)debug {return _debug;}

-(void)windowWillClose:(NSNotification*)note
{
  if (_debug > ipaDebugDebugLevel) NSLog(@"windowWillClose: received");
  _hidden = YES;
  [self setPaletteVisible:NO];
  [self sendMessage:ipaPaletteHiddenMsg withData:NULL];
}

/*-(void)flagsChanged:(id)sender
{
  NSUInteger mods = local_CurrentModifiers();
  if (mods == (NSControlKeyMask | NSAlternateKeyMask)) [self selectAnotherTab:NO];
  else if (mods == (NSControlKeyMask | NSShiftKeyMask)) [self selectAnotherTab:YES];
  [self updateDisplays:nil];
}*/

-(void)PDFImageMapDidChange:(PDFImageMap*)map
{
  [self updateDisplays:map];
}

-(void)updateDisplays:(id)sender
{
  // If we are still scanning for IPA fonts, the spinny is still, er, spinning
  // in the glyph view. Don't overwrite it.
  // We could also wait to install the timer until after the font thread is done.
  if (_scanningText == nil &&
      ![[[_tabs selectedTabViewItem] identifier] isEqual:@"Search"])
  {
    NSPoint p = [_window mouseLocationOutsideOfEventStream];
    NSString* strVal = @"";
    NSString* uniVal = @"";
    NSString* descVal = @"";
    id hit = sender;
    if (!hit || ![hit isMemberOfClass:[PDFImageMap class]]) hit = nil;
    if (!hit)
    {
      hit = [_tabs hitTest:p];
      if (!hit || ![hit isMemberOfClass:[PDFImageMap class]]) hit = nil;
    }
    if (hit)
    {
      NSString* str = [hit stringValue];
      NSUInteger mods = [hit modifiers];
      NSDictionary* d = [self charactersForIPA:str modifiers:mods];
      if (d)
      {
        strVal = [d objectForKey:ipaStringForGlyphViewKey];
        uniVal = [d objectForKey:ipaStringCodepointsKey];
        descVal = [d objectForKey:ipaStringSymbolTypeKey];
      }
    }
    [_glyphView setStringValue:strVal];
    [_unicodeText setStringValue:uniVal];
    [_descriptionText setStringValue:descVal];
  }
}

/*-(void)selectAnotherTab:(BOOL)prev
{
  NSTabViewItem* item = [_tabs selectedTabViewItem];
  NSInteger n = [_tabs indexOfTabViewItem:item];
  NSInteger of = [_tabs numberOfTabViewItems];
  if (prev)
  {
    if (n == 0) [_tabs selectTabViewItemAtIndex:of - 1];
    else [_tabs selectPreviousTabViewItem:self];
  }
  else
  {
    if (n >= of - 1) [_tabs selectTabViewItemAtIndex:0];
    else [_tabs selectNextTabViewItem:self];
  }
}*/

-(void)die:(NSTimer*)t
{
  if (_debug > ipaDebugDebugLevel) NSLog(@"Timed out hidden palette; calling [NSApp terminate:]");
  [[NSApplication sharedApplication] terminate:nil];
}

-(void)applicationWillTerminate:(NSNotification*)aNotification
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  id obj = [[_tabs selectedTabViewItem] identifier];
  [defaults setObject:obj forKey:ipaTabKey];
  [_window saveFrameUsingName:ipaFrameKey];
}

static CFDataRef local_MPCallback(CFMessagePortRef port, SInt32 msg, CFDataRef data, void* ctx)
{
  IPAServer* me = (IPAServer*)ctx;
  int dbg = [me debug];
  CFRange range = {0,0};
  if (dbg >= ipaDebugDebugLevel)
    NSLog(@"local_MPCallback called with message %d, data %@", msg, data);
  switch (msg)
  {
    // Our client text service component was activated. If the palette was not
    // visible, but the preferences indicate it should be visible, show it now. The
    // ipaActivatedMsg message includes the pid of the sender.
    case ipaActivatedMsg:
    {
#if __IPA_CM__
      CFStringRef psn = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);
      if (dbg >= ipaDebugDebugLevel) NSLog(@"ipaActivatedMsg received psn %@", psn);
      if (![(NSString*)psn isEqual:@"0"]) [me setPaletteVisible:YES];
      if (!me->_activeComponent) me->_activeComponent = [[NSMutableString alloc] init];
      [me->_activeComponent setString:(NSString*)psn];
      CFRelease(psn);
      [me setComponentDebug:[me->_componentDebugMenu indexOfSelectedItem]];
#else
      [me setPaletteVisible:YES];
      CGWindowLevel level;
      range.length = sizeof(level);
      CFDataGetBytes(data, range, (UInt8*)&level);
      if (dbg >= ipaDebugDebugLevel) NSLog(@"Setting window level to %d", level);
      [me->_window setLevel:level];
#endif
    }
    break;
    
#if __IPA_CM__
    case ipaActivatedShowOnlyMsg:
    if (dbg >= ipaDebugDebugLevel) NSLog(@"ipaActivatedShowOnlyMsg received");
    // We *don't* keep track of the current active input method in this case.
    [me setPaletteVisible:YES];
    [me setComponentDebug:[me->_componentDebugMenu indexOfSelectedItem]];
    break;
#endif
    
    case ipaHidePaletteMsg:
    if (dbg >= ipaDebugDebugLevel) NSLog(@"ipaHidePaletteMsg received");
    // We record the fact that we have been explicitly hidden, so we can
    // know whether to auto-minimize.
    me->_hidden = YES;
    [me setPaletteVisible:NO];
    break;
    
#if __IPA_CM__
    case ipaWindowLevelMsg:
    {
      int wLevel;
      range.length = sizeof(wLevel);
      CFDataGetBytes(data, range, (UInt8*)&wLevel);
      wLevel++;
      if (dbg >= ipaDebugDebugLevel) NSLog(@"ipaWindowLevelMsg received; setting to %d", wLevel);
      [me->_window setLevel:wLevel];
    }
    break;
#endif
    
    case ipaErrorMsg:
    {
      // The CM code sends error messages in big-endian format.
      // If this code is ever reinstated, make sure the IM version does the same.
      // (I don't think we need to ever worry about Rosetta with IMKit, but this
      // is for the sake of uniformity with the CM code.
      //OSStatus err;
      //range.length = sizeof(err);
      //CFDataGetBytes(inData, range, (UInt8*)&err);
      //err = CFSwapInt32BigToHost(err);
      [[Onizuka sharedOnizuka] localizeObject:me->_descriptionText withTitle:@"Unsupported"];
    }
    break;
  }
  return NULL;
}

-(void)sendMessage:(IPAMessage)msg withData:(NSData*)data
{
  NSString* portName = nil;
#if __IPA_CM__
  // Determine the name of the remote port we are trying to reach, based on its process
  // serial number. The name is of the form "com.blugs.IPAServerxxxxxx" where xxxxxx is PSN.
  if (!_activeComponent) return;
  portName = [[NSString alloc] initWithFormat:@"%s%@", kIPAServerListenPortName, _activeComponent];
#else
  portName = kIPAClientListenPortName;
#endif
  if (_debug >= ipaVerboseDebugLevel) NSLog(@"sendMessage: %ld to %@ with %@", msg, portName, data);
  CFMessagePortRef mp = CFMessagePortCreateRemote(NULL, (CFStringRef)portName);
  if (!mp) NSLog(@"CFMessagePortCreateRemote (%@) failed", portName);
  else
  {
    CFDataRef replyData = NULL;
    SInt32 mpResult = CFMessagePortSendRequest(mp, msg, (CFDataRef)data, 10, 10, NULL, &replyData);
    if (mpResult != kCFMessagePortSuccess)
    {
      switch (mpResult)
      {
        case kCFMessagePortSendTimeout:
        NSLog(@"CFMessagePortSendRequest (%@) timed out on send", data);
        break;
        case kCFMessagePortReceiveTimeout:
        NSLog(@"CFMessagePortSendRequest (%@) timed out on receive", data);
        break;
        case kCFMessagePortIsInvalid:
        NSLog(@"CFMessagePortSendRequest (%@) invalid port", data);
        break;
        case kCFMessagePortTransportError:
        NSLog(@"CFMessagePortSendRequest (%@) transport error", data);
        break;
        default:
        NSLog(@"CFMessagePortSendRequest (%@) unknown error %d", data, mpResult);
        break;
      }
    }
    CFRelease(mp);
    if (replyData) CFRelease(replyData);
  }
#if __IPA_CM__
  [portName release];
#endif
}

-(void)controlTextDidChange:(NSNotification*)note
{
  [self doSearch];
}

// Delegate for search text
-(void)controlTextDidEndEditing:(NSNotification*)note
{
  [self deactivateAppAndWindows];
}

// This code courtesy Evan Gross of Rainmaker Research (Spell Catcher X)
-(void)deactivateAppAndWindows
{
  if ([NSApp respondsToSelector:@selector(_deactivateWindows)])
      [NSApp performSelector:@selector(_deactivateWindows)];
  if ([NSApp respondsToSelector:@selector(setIsActive:)])
      [NSApp setIsActive:NO];
  [NSApp deactivate];
}

-(void)tabView:(NSTabView*)tv didSelectTabViewItem:(NSTabViewItem*)item
{
  unichar firstLetter = [[item identifier] characterAtIndex:0L];
  BOOL v, s, c, d, o, e, u;
  v = s = c = d = o = e = u = NO;
  switch (firstLetter)
  {
    case 'V': // Vowel
    v = s = YES;
    break;
    
    case 'C': // Consonant
    c = YES;
    break;
    
    case 'D': // Diacritic
    d = o = YES;
    break;

    case 'e': // extIPA
    e = YES;
    break;
    
    case 'S': // Search
    // Activate the search box when switching to Search pane.
    [_window makeFirstResponder:_window];
    [_window makeKeyWindow];
    [_window makeFirstResponder:_searchText];
    // Update the various text displays based on selection if any
    [self tableViewSelectionDidChange:nil];
    break;
    
    case 'U': // User Glyphs
    u = YES;
    break;
  }
  // If selected something other than search, deactivate the window
  if (firstLetter != 'S') [self deactivateAppAndWindows];
  v? [_vowels startTracking]:[_vowels stopTracking];
  s? [_supra startTracking]:[_supra stopTracking];
  c? [_consonants startTracking]:[_consonants stopTracking];
  d? [_diacritic startTracking]:[_diacritic stopTracking];
  o? [_other startTracking]:[_other stopTracking];
  e? [_extipa startTracking]:[_extipa stopTracking];
  u? [_user startTracking]:[_user stopTracking];
  [self updateDisplays:nil];
}

#pragma mark SEARCH RESULTS TABLE
-(NSInteger)numberOfRowsInTableView:(NSTableView*)tv
{
  return [_searchResults count];
}

-(id)tableView:(NSTableView*)tv objectValueForTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  NSArray* obj = [_searchResults objectAtIndex:row];
  id ident = [col identifier];
  if ([ident isEqual:@"0"]) return [obj objectAtIndex:1L];
  return [obj objectAtIndex:2L];
}

-(BOOL)tableView:(NSTableView*)tv shouldEditTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  #pragma unused (tv)
  return NO;
}

-(void)tableDoubleAction:(id)sender
{
  #pragma unused (sender)
  NSInteger sel = [_searchResultsTable selectedRow];
  NSString* toSend = [[_searchResults objectAtIndex:sel] objectAtIndex:0L];
  CFDataRef data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, (CFStringRef)toSend, kCFStringEncodingUTF8, 0x3F);
  [self sendMessage:ipaInputMsg withData:(NSData*)data];
  CFRelease(data);
}

-(void)tableViewSelectionDidChange:(NSNotification*)note
{
  NSInteger sel = [_searchResultsTable selectedRow];
  // Clear the fields when nothing selected.
  NSString* zilch = @"";
  if (sel == -1)
  {
    [_glyphView setStringValue:zilch];
    [_descriptionText setStringValue:zilch];
    [_unicodeText setStringValue:zilch];
  }
  else
  {
    NSArray* obj = [_searchResults objectAtIndex:sel];
    [_glyphView setStringValue:[obj objectAtIndex:1L]];
    [_descriptionText setStringValue:[obj objectAtIndex:2L]];
    [_unicodeText setStringValue:[obj objectAtIndex:3L]];
  }
}

// This is deprecated as of Tiger but is implemented for backwards compatibility.
// In IB the table needs to be set up for only single selection, so we *should*
// only ever get a single row. So we only use the first item in the rows.
-(BOOL)tableView:(NSTableView*)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
  BOOL wrote = NO;
  NSInteger sel = [[rows objectAtIndex:0L] intValue];
  NSString* str = [[_searchResults objectAtIndex:sel] objectAtIndex:0L];
  [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
  if (str) wrote = [pboard setString:str forType:NSStringPboardType];
  return wrote;
}

-(BOOL)tableView:(NSTableView*)tv writeRowsWithIndexes:(NSIndexSet*)rowIndexes
       toPasteboard:(NSPasteboard*)pboard
{
  NSNumber* row = [NSNumber numberWithUnsignedInt:[rowIndexes firstIndex]];
  NSArray* rows = [[NSArray alloc] initWithObjects:row, NULL];
  BOOL wrote = [self tableView:tv writeRows:rows toPasteboard:pboard];
  [rows release];
  return wrote;
}

-(NSArray*)arrayWithStringSplitOnSpace:(NSString*)str
{
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  return [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
#else
  NSMutableArray* arr = [[NSMutableArray alloc] init];
  unichar uch;
  NSRange where = NSMakeRange(0L,0L);
  NSUInteger i, len = [str length];
  NSString* sub;
  for (i=0; i<len; i++)
  {
    uch = [str characterAtIndex:i];
    if (uisspace(uch))
    {
      if (where.length)
      {
        sub = [str substringWithRange:where];
        [arr addObject:sub];
        where.length = 0;
      }
    }
    else
    {
      if (where.length == 0) where.location = i;
      where.length++;
    }
  }
  if (where.length)
  {
    sub = [str substringWithRange:where];
    [arr addObject:sub];
  }
  return arr;
#endif
}
@end

// Taken from Unicode Consortium data.
// We don't use 0xFEFF ZERO WIDTH NO-BREAK SPACE because it is a control
// character and is invisible.
// 0x200C ZERO WIDTH NON-JOINER is counted as a space, but
// 0x200D ZERO WIDTH JOINER is counted as a nonspace.
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5
static BOOL uisspace(unichar ch)
{
  return ((ch >= 0x0009 && ch <= 0x000D) || // Spacey control characters
          ch == 0x0020 || // SPACE
          ch == 0x0085 || // NEXT LINE (NEL)
          ch == 0x00A0 || // NO-BREAK SPACE
          ch == 0x1680 || // OGHAM SPACE MARK
          ch == 0x180E || // MONGOLIAN VOWEL SEPARATOR
          (ch >= 0x2000 && ch <= 0x200C) || // Spacey part of gen punctuation
          ch == 0x2028 || // LINE SEPARATOR
          ch == 0x2029 || // PARAGRAPH SEPARATOR
          ch == 0x202F || // NARROW NO-BREAK SPACE
          ch == 0x205F || // MEDIUM MATHEMATICAL SPACE
          ch == 0x3000);
}
#endif

static NSComparisonResult local_SearchResultComparisonCallback(id item1, id item2, void* something)
{
  NSArray* a1 = item1;
  NSArray* a2 = item2;
  return [[a1 objectAtIndex:2] compare:[a2 objectAtIndex:2L] options:NSCaseInsensitiveSearch];
}

