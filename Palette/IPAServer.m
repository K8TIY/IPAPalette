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
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "IPAServer.h"
#import "Onizuka.h"
#import "Placeholder.h"
#import "CMAPParser.h"
#import "PDFImageMapCreator.h"
#import "KeylayoutParser.h"
#import "NSView+Spinny.h"
#import "NSApplication+DarkMode.h"

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

/*#ifdef __IPA_APPSTORE__
@interface NSString (IPAPalette)
+(NSString*)rot13:(NSString*)s;
@end

@implementation NSString (IPAPalette)
+(NSString*)rot13:(NSString*)s
{
  NSMutableString* ms = [[NSMutableString alloc] init];
  unsigned len = [s length];
  unsigned i;
  for (i = 0; i < len; i++)
  {
    unichar c = [s characterAtIndex:i];
    if (c <= 122 && c >= 97) c += (c + 13 > 122)? -13:13;
    else if(c <= 90 && c >= 65) c += (c + 13 > 90)? -13:13;
    [ms appendFormat:@"%C", c];
  }
  NSString* ret = [NSString stringWithString:ms];
  [ms release];
  return ret;
}
@end
#endif*/

static NSComparisonResult local_SearchResultComp(id item1, id item2,
                                                 void* something);
static void local_KeyboardChanged(CFNotificationCenterRef center,
                                  void* observer, CFStringRef name,
                                  const void* object, CFDictionaryRef userInfo);

@implementation IPASearchResults
// It doesn't seem reasonable to allow dragging table Unicode strings to ourselves,
// so we don't allow dragging IPA symbols to the search field (or anywhere
// else in the Palette). We do a "copy" operation so we get the +-sign cursor badge when dragging
// into a nonlocal target, i.e., another application.
-(NSDragOperation)draggingSession:(NSDraggingSession*)session
                  sourceOperationMaskForDraggingContext:(NSDraggingContext)ctx
{
  #pragma unused (session)
  switch (ctx)
  {
    case NSDraggingContextOutsideApplication:
    return NSDragOperationCopy;
    break;

    case NSDraggingContextWithinApplication:
    default:
    return NSDragOperationNone;
    break;
  }
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
-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle
     backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
  if ((self = [super initWithContentRect:contentRect
                     styleMask:windowStyle
                     backing:bufferingType
                     defer:deferCreation]))
  {
    [[self standardWindowButton:NSWindowZoomButton] setHidden:YES];
    [self setBecomesKeyOnlyIfNeeded:YES];
  }
  return self;
}

-(BOOL)canBecomeKeyWindow {return YES;}
-(BOOL)canBecomeMainWindow {return NO;}
@end

@interface IPAServer (Private)
-(void)updateAppearance;
-(void)addIPAFonts:(id)me;
-(void)finishIPAFonts:(id)sender;
-(void)runFontAlert;
-(void)userGlyphsChanged:(id)sender;
-(NSDictionary*)charactersForIPA:(NSString*)ipa modifiers:(NSUInteger)modifiers;
-(NSString*)longDescriptionForCodepoints:(NSString*)codepoints withFallback:(NSString*)fb;
-(void)sendIPAForString:(NSString*)ipa modifiers:(NSUInteger)modifiers;
-(void)doSearch;
-(int)debug;
-(void)PDFImageMap:(PDFImageMap*)map didChangeSelection:(NSString*)key;
-(void)updateDisplays:(id)hit;
-(void)selectAnotherTab:(BOOL)prev;
//-(void)die:(NSTimer*)t;
-(void)setPaletteVisible:(BOOL)vis;
-(void)deactivateAppAndWindows;
-(void)createAuxiliaryPanelForName:(NSString*)name withFrame:(NSRect)frame
       syncToDefaults:(BOOL)sync;
-(void)keyboardChanged;
-(void)keylayoutParser:(KeylayoutParser*)kp foundSequence:(NSString*)seq
       forOutput:(NSString*)output;
-(BOOL)isInterestingKeyboardSequence:(NSString*)seq
       forOutput:(NSString*)output;
-(NSAttributedString*)attributedStringForKeyboardShortcut:(NSString*)seq;
-(void)syncAuxiliariesToDefaults;
-(void)syncAuxiliariesFromDefaults;
@end



@implementation IPAServer
static NSString* ipaPlaceholderCircleString = nil;
static IPAServer* gServer = nil;

// charactersForIPA:modifiers: returns a dict with the following keys:
static NSString* ipaStringToSendKey       = @"ToSend";      // NSString
static NSString* ipaStringForGlyphViewKey = @"GlyphView";   // NSString
static NSString* ipaStringCodepointsKey   = @"Codepoints";  // NSString
static NSString* ipaStringSymbolTypeKey   = @"SpelledOut";  // NSString

// Defaults that have registerable values
static NSString* ipaFontKey = @"Font";
static NSString* ipaFontDefault = @"Doulos SIL";
NSString* ipaDebugKey = @"Debug";
static NSString* ipaDontShowAgainKey = @"DontShowAgain";
static NSString* ipaUserFontsKey = @"UserFonts";
NSString* ipaUserGlyphsKey = @"UserGlyphs";
NSString* ipaUserGlyphDescriptionsKey = @"UserGlyphDescriptions";
static NSString* ipaFallbackKey = @"GlyphFallback";
static NSString* ipaKeyboardSyncKey = @"KeyboardSync";
static NSString*  ipaAuxiliariesKey = @"Auxiliaries";
// These will not be registered; filled in later
static NSString*  ipaFrameKey = @"PaletteFrame";

+(void)initialize
{
  ipaPlaceholderCircleString = [[NSString alloc] initWithCharacters:&PlaceholderDottedCircle length:1L];
  NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
  NSString* where = [[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"];
  NSDictionary* d = [[NSMutableDictionary alloc] initWithContentsOfFile:where];
  [ud registerDefaults:d];
  [d release];
}

+(IPAServer*)sharedServer { return gServer; }


// Given a string such as "i j", produces "U+0069 U+006A" with hex codepoints.
+(NSString*)copyUPlusForString:(NSString*)str
{
  if (str == nil) return nil;
  NSMutableString* uplus = [[NSMutableString alloc] init];
  __block NSUInteger i, uc, uc2;
  NSRange fullRange = NSMakeRange(0, [str length]);
  [str enumerateSubstringsInRange:fullRange
       options:NSStringEnumerationByComposedCharacterSequences
       usingBlock:^(NSString* substring, NSRange substringRange,
                    NSRange enclosingRange, BOOL* stop)
  {
    #pragma unused (substring, enclosingRange, stop)
    uc = 0;
    for (i = 0; i < substringRange.length; i++)
    {
      uc = [str characterAtIndex:substringRange.location+i];
      uc2 = 0;
      if (0xD800 <= uc && uc <= 0xDBFF && i+1 < substringRange.length)
      {
        uc2 = [str characterAtIndex:substringRange.location+i+1];
        uc = ((uc - 0xD800) * 0x400) + (uc2 - 0xDC00) + 0x10000;
        i++;
      }
      [uplus appendFormat:@"%sU+%.4X", ([uplus length])?" ":"", (unsigned)uc];
    }
  }];
  return uplus;
}

-(void)awakeFromNib
{
  _hidden = 1;
  [_fontMenu removeAllItems];
  // Get the hot rect locations from the main image map data file
  NSString* path = [[NSBundle mainBundle] pathForResource:@"MapData" ofType:@"plist"];
  [_vowels loadDataFromFile:path withName:@"Vow"];
  [_consonants loadDataFromFile:path withName:@"Cons"];
  [_supra loadDataFromFile:path withName:@"SupraTone"];
  [_diacritic loadDataFromFile:path withName:@"Diacritic"];
  [_other loadDataFromFile:path withName:@"Other"];
  [_extipa loadDataFromFile:path withName:@"ExtIPA"];
  [_user setName:@"User"];
  [_window setFrameUsingName:ipaFrameKey];
  [_window setCollectionBehavior: NSWindowCollectionBehaviorMoveToActiveSpace |
                                  NSWindowCollectionBehaviorFullScreenNone];
  // Load the alternate image for vowel drag images
  path = [[NSBundle mainBundle] pathForResource:@"VowDrag" ofType:@"pdf"];
  NSImage* whatadrag = [[NSImage alloc] initWithContentsOfFile:path];
  [_vowels setDragImage:whatadrag];
  [whatadrag release];
  // Load info on superscripts and /above/below alternations
  path = [[NSBundle mainBundle] pathForResource:@"Alts" ofType:@"strings"];
  _alts = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
  //[_debugMenu selectItemAtIndex:_debug];
  [_glyphView embedSpinny];
  [NSApp setDelegate:self];
  _fontMenuSuperview = [_fontMenu superview];
  [_fontMenu retain];
  [_fontMenu removeFromSuperview];
  [[Onizuka sharedOnizuka] localizeWindow:_window];
  [_unicodeText setStringValue:@""];
  [_descriptionText setStringValue:@""];
  _searchResults = [[NSMutableArray alloc] init];
  _descToGlyph = [[NSMutableDictionary alloc] init];
  NSString* locs = [[NSBundle mainBundle] pathForResource:@"Keyboard" ofType:@"plist"];
  // Map all localized descriptions we have to the stringified U+ minus the U+.
  NSArray* a = [NSArray arrayWithContentsOfFile:locs];
  for (NSString* glyph in a)
  {
    if ([glyph length] > 2 && [[glyph substringToIndex:2L] isEqual:@"U+"])
    {
      NSString* desc = [[Onizuka sharedOnizuka] bestLocalizedString:glyph];
      if (desc)
      {
        glyph = [glyph substringFromIndex:2L];
        [_descToGlyph setValue:glyph forKey:desc];
      }
    }
  }
  CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
    self, local_KeyboardChanged, kTISNotifySelectedKeyboardInputSourceChanged,
    NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  [[NSDistributedNotificationCenter defaultCenter]
     addObserver:self selector:@selector(prefsChanged:)
     name:@"IPAPalatte_PrefsChanged" object:nil
     suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
  NSNotificationCenter* nc = [[NSWorkspace sharedWorkspace] notificationCenter];
  [nc addObserver:self selector:@selector(windowDidMoveSpace:)
      name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
  [nc addObserver:self selector:@selector(userWillLogout:)
      name:NSWorkspaceWillPowerOffNotification object:nil];
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  [defs addObserver:self forKeyPath:ipaKeyboardSyncKey
        options:NSKeyValueObservingOptionNew context:NULL];
  [self keyboardChanged];
  [_searchResultsTable setDoubleAction:@selector(tableDoubleAction:)];
  [_searchResultsTable setTarget:self];
  [self userGlyphsChanged:self];
  [_keyboardText setStringValue:@""];
  [NSApplication detachDrawingThread:@selector(addIPAFonts:) toTarget:self withObject:nil];
  gServer = self;
#if defined(XCODE_DEBUG_CONFIGURATION_DEBUG)
  [self activateWithWindowLevel:NSFloatingWindowLevel];
#endif
  [self syncAuxiliariesFromDefaults];
  // So we can call start tracking on it.
  [self tabView:_tabs didSelectTabViewItem:[_tabs selectedTabViewItem]];
  [self updateAppearance];
}

-(void)updateAppearance
{
  BOOL dark = [NSApplication isDarkMode];
  NSString* imageName = [PDFImageMapCreator copyPDFFileNameForName:@"Vow" dark:dark];
  [_vowels setImage:[NSImage imageNamed:imageName]];
  [imageName release];
  imageName = [PDFImageMapCreator copyPDFFileNameForName:@"Cons" dark:dark];
  [_consonants setImage:[NSImage imageNamed:imageName]];
  [imageName release];
  imageName = [PDFImageMapCreator copyPDFFileNameForName:@"SupraTone" dark:dark];
  [_supra setImage:[NSImage imageNamed:imageName]];
  [imageName release];
  imageName = [PDFImageMapCreator copyPDFFileNameForName:@"Diacritic" dark:dark];
  [_diacritic setImage:[NSImage imageNamed:imageName]];
  [imageName release];
  imageName = [PDFImageMapCreator copyPDFFileNameForName:@"Other" dark:dark];
  [_other setImage:[NSImage imageNamed:imageName]];
  [imageName release];
  imageName = [PDFImageMapCreator copyPDFFileNameForName:@"ExtIPA" dark:dark];
  [_extipa setImage:[NSImage imageNamed:imageName]];
  [imageName release];
}

#define kLezh 0x026E // LZh digraph U+026E
#define kBeta 0x03B2 // Greek small letter beta
-(void)addIPAFonts:(id)ignore
{
  #pragma unused (ignore)
  NSMutableArray* fontNames = [[NSMutableArray alloc] init];
  NSArray* fonts = [[NSFontManager sharedFontManager] availableFonts];
  for (NSString* font in fonts)
  {
    // Ignore some System-private fonts that spam the logs with douchey
    // warnings like "All system UI font access should be through proper APIs…"
    if (![font isEqualToString:@"LastResort"] && ![font hasPrefix:@"."])
    {
      CFDataRef data = nil;
      CTFontRef ctFont = CTFontCreateWithName((CFStringRef)font, 0.0, NULL);
      if (ctFont)
      {
        data = CTFontCopyTable(ctFont, 'cmap', kCTFontTableOptionNoOptions);
      }
      if (!data) NSLog(@"CTFontCopyTable '%@' failed", font);
      else
      {
        if (CMAPHasChar((char*)CFDataGetBytePtr(data), kLezh) &&
            CMAPHasChar((char*)CFDataGetBytePtr(data), kBeta))
        {
          CFStringRef readable = CTFontCopyDisplayName(ctFont);
          if (![(NSString*)readable hasPrefix:@"."])
          {
            [fontNames addObject:(NSString*)readable];
          }
          CFRelease(readable);
        }
        CFRelease(data);
      }
    }
  }
  // Now let's add in any custom fonts added by the user.
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  NSArray* userFonts = [defs objectForKey:ipaUserFontsKey];
NS_DURING
  if (userFonts && [userFonts isKindOfClass:[NSArray class]] && [userFonts count])
  {
    for (NSString* name in userFonts) [fontNames addObject:(NSString*)name];
  }
NS_HANDLER
  NSLog(@"ERROR: had problem loading user fonts: %@", [localException reason]);
NS_ENDHANDLER
  [fontNames sortUsingSelector: @selector(compare:)];
  for (NSString* fontName in fontNames)
  {
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:fontName action:nil keyEquivalent:@""];
    //[[_fontMenu menu] addItem:item];
    [self performSelectorOnMainThread:@selector(addToFontMenu:) withObject:item
        waitUntilDone:YES];
    [item release];
  }
  // See if the user has selected a font before
  NSString* name = [defs objectForKey:ipaFontKey];
  if ([fontNames containsObject:name])
  {
    //[_fontMenu selectItemWithTitle:name];
    [_fontMenu performSelectorOnMainThread:@selector(selectItemWithTitle:) withObject:name
        waitUntilDone:YES];
  }
  else
  {
    if (__DBG >= ipaDebugDebugLevel)
      NSLog(@"preferred font '%@' not found, falling back to %@.", name, ipaFontDefault);
    if ([fontNames containsObject:ipaFontDefault])
      [_fontMenu selectItemWithTitle:ipaFontDefault];
    else
    {
      if ([_fontMenu numberOfItems])
      {
        if (__DBG >= ipaDebugDebugLevel)
          NSLog(@"recommended %@ font not found, falling back to first in menu.", ipaFontDefault);
        [_fontMenu selectItemAtIndex:0L];
      }
      else
      {
        if (![defs integerForKey:ipaDontShowAgainKey])
        {
          [self performSelectorOnMainThread:@selector(runFontAlert) withObject:self
                waitUntilDone:NO];
        }
      }
    }
  }
  [fontNames release];
  [self performSelectorOnMainThread:@selector(finishIPAFonts:) withObject:self
        waitUntilDone:NO];
}

// Call on main thread.
-(void)addToFontMenu:(NSMenuItem*)item
{
  [[_fontMenu menu] addItem:item];
}

// Called to do cleanup on main thread after font collection thread finishes.
-(void)finishIPAFonts:(id)sender
{
  #pragma unused (sender)
  [_glyphView unembedSpinny];
  [_scanningText removeFromSuperview];
  _scanningText = nil;
  [_fontMenuSuperview addSubview:_fontMenu];
  if ([_fontMenu numberOfItems] > 0) [self fontAction:_fontMenu];
  else [_fontMenu setEnabled:NO];
}

-(void)runFontAlert
{
  NSString* msg1 = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__NO_FONTS__"];
  NSString* msg2 = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__PREVIEW_BAD__"];
  NSAlert* alert = [NSAlert alertWithMessageText:msg1 defaultButton:nil
                            alternateButton:nil otherButton:nil
                            informativeTextWithFormat:@"%@", msg2];
  [msg1 release];
  [msg2 release];
  [alert setShowsSuppressionButton:YES];
  /*[alert beginSheetModalForWindow:_window modalDelegate:self
             didEndSelector:@selector(endAlert:returnCode:contextInfo:)
             contextInfo:nil];*/
  [alert beginSheetModalForWindow:_window
         completionHandler:^(NSModalResponse result)
  {
    if (result == NSModalResponseOK)
    {
      if ([[alert suppressionButton] state] == NSOnState)
      [[NSUserDefaults standardUserDefaults] setInteger:1L forKey:ipaDontShowAgainKey];
    }
  }];
}

/*-(void)endAlert:(NSAlert*)alert returnCode:(int)code contextInfo:(void*)ctx
{
  #pragma unused (code,ctx)
  if ([[alert suppressionButton] state] == NSOnState)
    [[NSUserDefaults standardUserDefaults] setInteger:1L forKey:ipaDontShowAgainKey];
}*/

-(void)userGlyphsChanged:(id)sender
{
  #pragma unused (sender)
  NSArray* glyphs = [[NSUserDefaults standardUserDefaults] objectForKey:ipaUserGlyphsKey];
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
    NSArray* data = [glyphs slice:6];
    [PDFImageMapCreator setPDFImageMap:_user toData:data
                        ofType:PDFImageMapColumnar dark:[NSApplication isDarkMode]];
    if ([_tabs selectedTabViewItem] == _userGlyphsTab) [_user startTracking];
    [self keyboardChanged];
  }
}

-(void)setPaletteVisible:(BOOL)vis
{
  if (vis != [_window isVisible])
  {
    BOOL isMin = [_window isMiniaturized];
    if (__DBG >= ipaDebugDebugLevel)
      NSLog(@"setPaletteVisible:%s isMin=%s [_window isVisible]=%s",
            (vis)? "YES" : "NO", (isMin)? "YES" : "NO",
            ([_window isVisible])? "YES" : "NO");
    if (vis)
    {
      // We get activation messages when we switch apps.
      // If the window is miniaturized, just let it sit there.
      // Switching apps is one reason.
      // Selecting 'Show IPA Palette' menu item is another.
      // In the former case, we should leave it miniaturized.
      if ((isMin && _hidden) || !isMin)
      {
        if (__DBG >= ipaDebugDebugLevel) NSLog(@"calling [_window orderFrontRegardless];");
        [_window orderFrontRegardless];
        [_diacritic showSubwindow:_savedSubwindow];
      }
      _hidden = NO;
    }
    else
    {
      if (_savedSubwindow) [_savedSubwindow release];
      _savedSubwindow = [[_diacritic subwindowName] copy];
      [_diacritic showSubwindow:nil];
      [_window orderOut:nil];
      //if (isMin) [_window deminiaturize:nil];
    }
    if (_auxiliaries)
    {
      for (IPAPanel* aux in _auxiliaries)
      {
        if (vis) [aux orderFrontRegardless];
        else [aux orderOut:nil];
      }
    }
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
      d = [NSMutableDictionary dictionary];
      if (modifiers & NSShiftKeyMask || modifiers & NSAlternateKeyMask)
      {
        NSString* alt = [_alts objectForKey:ipa];
        if (alt)
        {
          primary = alt;
          secondary = ipa;
          if (__DBG >= ipaInsaneDebugLevel) NSLog(@"Alternation: '%@' to '%@'", ipa, alt);
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
      if (codepoints1) [codepoints1 release];
      if (codepoints2) [codepoints2 release];
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
  NSDictionary* udescs = [[NSUserDefaults standardUserDefaults] objectForKey:ipaUserGlyphDescriptionsKey];
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
  [self sendIPAForString:[sender stringValue] modifiers:mods];
}

-(void)sendIPAForString:(NSString*)ipa modifiers:(NSUInteger)modifiers
{
  NSDictionary* d = [self charactersForIPA:ipa modifiers:modifiers];
  if (d)
  {
    NSString* toSend = [d objectForKey:ipaStringToSendKey];
    if (toSend && _inputController)
    {
      NSString* fontName = nil;
      if (modifiers & NSControlKeyMask)
        fontName = [[_fontMenu selectedItem] title];
      [_inputController receiveText:toSend font:fontName];
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

-(IBAction)fallbackAction:(id)sender
{
  NSInteger fba = [sender indexOfSelectedItem];
  [_glyphView setFallbackBehavior:fba];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedChar:fba] forKey:ipaFallbackKey];
}

-(void)doSearch
{
  NSMutableDictionary* composite = [[NSMutableDictionary alloc] initWithDictionary:_descToGlyph];
  NSDictionary* udescs = [[NSUserDefaults standardUserDefaults] objectForKey:ipaUserGlyphDescriptionsKey];
  for (NSString* ipa in udescs)
    [composite setObject:[ipa substringFromIndex:2] forKey:[udescs objectForKey:ipa]];
  NSString* search = [_searchText stringValue];
  NSArray* terms = [search componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  [_searchResults removeAllObjects];
  if ([search length] && [terms count])
  {
    for (NSString* desc in [composite allKeys])
    {
      BOOL hasAll = YES;
      for (NSString* term in terms)
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
          NSString* ipa = nil;
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
  if ([_searchResults count]) [_searchResults sortUsingFunction:&local_SearchResultComp context:nil];
  [_searchResultsTable reloadData];
  [_searchResultsTable scrollRowToVisible:0];
}

-(void)PDFImageMapDidChange:(PDFImageMap*)map
{
  [self updateDisplays:map];
}

-(void)PDFImageMapDidDrag:(PDFImageMap*)map
{
  NSRect f = [map imageRect];
  NSRect wf = f;
  wf.size.width = f.size.width + 4.0f;
  wf.size.height = f.size.height + 4.0f;
  wf.origin = [map dropPoint];
  [self createAuxiliaryPanelForName:[map name] withFrame:wf syncToDefaults:YES];
}

-(void)updateDisplays:(id)sender
{
  NSString* strVal = @"";
  NSString* uniVal = @"";
  NSString* descVal = @"";
  NSString* str = @"";
  NSUInteger mods = 0;
  NSString* kbVal = nil;
  if ([[[_tabs selectedTabViewItem] identifier] isEqual:@"Search"])
  {
    NSInteger sel = [_searchResultsTable selectedRow];
    // Clear the fields when nothing selected.
    if (sel != -1)
    {
      NSArray* obj = [_searchResults objectAtIndex:sel];
      str = [obj objectAtIndex:1L];
    }
  }
  else
  {
    if (!sender || ![sender isMemberOfClass:[PDFImageMap class]]) sender = nil;
    if (sender)
    {
      str = [sender stringValue];
      mods = [sender modifiers];
    }
  }
  NSDictionary* d = [self charactersForIPA:str modifiers:mods];
  if (d)
  {
    strVal = [d objectForKey:ipaStringForGlyphViewKey];
    uniVal = [d objectForKey:ipaStringCodepointsKey];
    descVal = [d objectForKey:ipaStringSymbolTypeKey];
    if (_keyboard)
    {
      NSArray* comps = [uniVal componentsSeparatedByString:@" "];
      // In a multi-element sequence, use an ellipsis to indicate a missing
      // shortcut for one of the elements. There must be at least 1 with a
      // real, "interesting" shortcut.
      NSMutableArray* keys = [[NSMutableArray alloc] init];
      BOOL gotOne = NO;
      BOOL interesting = NO;
      NSUInteger i = 0;
      for (NSString* comp in comps)
      {
        NSString* key = [_keyboard objectForKey:comp];
        if (key && ![key isKindOfClass:[NSNull class]])
        {
          if ([self isInterestingKeyboardSequence:key
                    forOutput:[str substringWithRange:NSMakeRange(i, 1)]])
            interesting = YES;
          [keys addObject:key];
          gotOne = YES;
        }
        else [keys addObject:[NSString stringWithFormat:@"%C", 0x2026]];
        i++;
      }
      if (gotOne && interesting) kbVal = [keys componentsJoinedByString:@" "];
      [keys release];
    }
  }
  [_glyphView setStringValue:strVal];
  [_unicodeText setStringValue:uniVal];
  [_descriptionText setStringValue:descVal];
  if (kbVal)
  {
    NSAttributedString* akbVal = [self attributedStringForKeyboardShortcut:kbVal];
    [_keyboardText setAttributedStringValue:akbVal];
  }
  else [_keyboardText setStringValue:@""];
}

-(void)activateWithWindowLevel:(NSInteger)level
{
  [self setPaletteVisible:YES];
  if (level != [_window level]) [_window setLevel:level];
  if (_auxiliaries)
  {
    for (IPAPanel* aux in _auxiliaries)
      if (level != [aux level]) [aux setLevel:level];
  }
}

-(void)hide
{
  // We record the fact that we have been explicitly hidden, so we can
  // know whether to auto-minimize.
  _hidden = YES;
  [self setPaletteVisible:NO];
}

-(void)setError
{
  [[Onizuka sharedOnizuka] localizeObject:_descriptionText
                           withTitle:@"Unsupported"];
}

-(void)setInputController:(IPAInputController*)ic
{
  [ic retain];
  if (_inputController) [_inputController release];
  _inputController = ic;
}

#pragma mark Notifications
-(void)applicationWillTerminate:(NSNotification*)note
{
  #pragma unused (note)
  //NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  //id obj = [[_tabs selectedTabViewItem] identifier];
  //[defaults setObject:obj forKey:ipaTabKey];
  [_window saveFrameUsingName:ipaFrameKey];
}

-(void)observeValueForKeyPath:(NSString*)path ofObject:(id)object
       change:(NSDictionary*)change context:(void*)ctx
{
  #pragma unused (object,change,ctx)
  //NSLog(@"observeValueForKeyPath:%@ ofObject:%@ change:%@", path, object, change);
  if ([path isEqualToString:ipaKeyboardSyncKey])
  {
    [self keyboardChanged];
  }
}

-(void)windowWillClose:(NSNotification*)note
{
  if (__DBG > ipaDebugDebugLevel) NSLog(@"windowWillClose: received");
  IPAPanel* w = [note object];
  if (w == _window)
  {
    _hidden = YES;
    [self setPaletteVisible:NO];
    if (_inputController) [_inputController receiveHide];
  }
  else
  {
    if (_auxiliaries)
    {
      [_auxiliaries removeObject:w];
      [self syncAuxiliariesToDefaults];
    }
  }
}

-(void)controlTextDidChange:(NSNotification*)note
{
  #pragma unused (note)
  [self doSearch];
}

// It would be nice if [NSApp deactivate] worked for our purpose....
// This code courtesy Evan Gross of Rainmaker Research (Spell Catcher X)
// Further modified to fly under the radar (maybe) using on-the-fly
// SEL generation to hide the undocumented calls to _deactivateWindows and
// setIsActive: methods of NSApplication.
// Use an invocation to keep compiler from whining about the
// [NSApp setIsActive:NO] call.
// This is in case I ever want to get onto the App Store! (yeah, right)
-(void)deactivateAppAndWindows
{
  [_window resignKeyWindow];
  [[NSApplication sharedApplication] deactivate];
  /*
#ifdef __IPA_APPSTORE__
  SEL dw = NSSelectorFromString([NSString rot13:@"_qrnpgvingrJvaqbjf"]);
  SEL sia = NSSelectorFromString([NSString rot13:@"frgVfNpgvir:"]);
#else
  SEL dw = @selector(_deactivateWindows);
  SEL sia = @selector(setIsActive:);
#endif
  if ([NSApp respondsToSelector:dw]) [NSApp performSelector:dw];
  if ([NSApp respondsToSelector:sia]);
  {
    BOOL arg0 = NO;
    NSMethodSignature* sig = [NSApp methodSignatureForSelector:sia];
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:sia];
    [inv setTarget:NSApp];
    [inv setArgument:&arg0 atIndex:2];
    [inv invoke];
  }*/
}

-(void)tabView:(NSTabView*)tv didSelectTabViewItem:(NSTabViewItem*)item
{
  #pragma unused (tv)
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
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [_window orderFrontRegardless];
    [_window makeFirstResponder:_window];
    [_window makeKeyAndOrderFront:nil];
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

-(void)windowDidMove:(NSNotification*)note
{
  NSWindow* w = [note object];
  if (_auxiliaries && [_auxiliaries containsObject:w])
    [self syncAuxiliariesToDefaults];
}

-(void)prefsChanged:(id)sender
{
  #pragma unused (sender)
  //NSLog(@"prefsChanged");
  [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)windowDidMoveSpace:(NSNotification*)note
 {
   #pragma unused (note)
   if (_hidden) [_window orderOut:self];
   else [_window orderFront:self];
}

-(void)userWillLogout:(NSNotification*)note
{
  #pragma unused (note)
  //NSLog(@"Will logout");
  [self hide];
}

#pragma mark Search Results Table
-(NSInteger)numberOfRowsInTableView:(NSTableView*)tv
{
  #pragma unused (tv)
  return [_searchResults count];
}

-(id)tableView:(NSTableView*)tv objectValueForTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  #pragma unused (tv)
  NSArray* obj = [_searchResults objectAtIndex:row];
  id ident = [col identifier];
  if ([ident isEqual:@"0"]) return [obj objectAtIndex:1L];
  return [obj objectAtIndex:2L];
}

-(BOOL)tableView:(NSTableView*)tv shouldEditTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  #pragma unused (tv,col,row)
  return NO;
}

-(void)tableDoubleAction:(id)sender
{
  #pragma unused (sender)
  NSInteger sel = [_searchResultsTable selectedRow];
  NSString* toSend = [[_searchResults objectAtIndex:sel] objectAtIndex:0L];
  [self deactivateAppAndWindows];
  [_inputController receiveText:toSend font:nil];
}

-(void)tableViewSelectionDidChange:(NSNotification*)note
{
  #pragma unused (note)
  [self updateDisplays:nil];
}

-(BOOL)tableView:(NSTableView*)tv writeRowsWithIndexes:(NSIndexSet*)rowIndexes
       toPasteboard:(NSPasteboard*)pboard
{
  #pragma unused (tv)
  BOOL wrote = NO;
  NSString* str = [[_searchResults objectAtIndex:[rowIndexes firstIndex]] objectAtIndex:0L];
  if (str)
  {
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    wrote = [pboard setString:str forType:NSStringPboardType];
  }
  return wrote;
}

#pragma mark Keyboard Synchronization
-(void)keyboardChanged
{
  if (__DBG > ipaDebugDebugLevel) NSLog(@"Keyboard changed");
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  if ([defs boolForKey:ipaKeyboardSyncKey])
  {
    if (_keyboard)
    {
      for (id key in [_keyboard allKeys])
        [_keyboard setObject:[NSNull null] forKey:key];
    }
    else
    {
      _keyboard = [[NSMutableDictionary alloc] init];
      NSString* path = [[NSBundle mainBundle] pathForResource:@"Keyboard"
                                              ofType:@"plist"];
      NSArray* unicodes = [[NSArray alloc] initWithContentsOfFile:path];
      for (NSString* u in unicodes)
        [_keyboard setObject:[NSNull null] forKey:u];
      [unicodes release];
      NSArray* glyphs = [defs objectForKey:ipaUserGlyphsKey];
      for (NSString* u in glyphs)
      {
        if ([u length])
        {
          NSString* uplus = [IPAServer copyUPlusForString:u];
          [_keyboard setObject:[NSNull null] forKey:uplus];
          if (uplus) [uplus release];
        }
      }
    }
    KeylayoutParser* klp = [[KeylayoutParser alloc] init];
    unsigned type = [klp matchingKeyboardType];
    [klp parseKeyboardType:type withObject:self
         selector:@selector(keylayoutParser:foundSequence:forOutput:)];
    [klp release];
    [self updateDisplays:self];
  }
  else
  {
    if (_keyboard)
    {
      [_keyboard release];
      _keyboard = nil;
    }
  }
}

-(void)keylayoutParser:(KeylayoutParser*)kp foundSequence:(NSString*)seq
       forOutput:(NSString*)output
{
  #pragma unused (kp)
  //if ([self isInterestingKeyboardSequence:seq forOutput:output])
  {
    NSString* uplus = [IPAServer copyUPlusForString:output];
    NSString* existing = [_keyboard objectForKey:uplus];
    if (!existing ||
        [existing isKindOfClass:[NSNull class]] ||
        ([existing isKindOfClass:[NSString class]] &&
         [KeylayoutParser compareKeyboardSequence:seq withSequence:existing] == NSOrderedAscending))
    {
      BOOL allow = YES;
      // But, never ever allow cmd
      for (unsigned i = 0; i < [seq length]; i++)
      {
        if ([seq characterAtIndex:i] == kCommandUnicode)
        {
          allow = NO;
          break;
        }
      }
      if (allow) [_keyboard setObject:seq forKey:uplus];
    }
    if (uplus) [uplus release];
  }
}

// The following combos are officially uninteresting:
// 1. Anything yielding an empty string.
// 2. Anything yielding a single character of 0x20 (space) or below,
//    or 0x7F (delete).
// 3. Unmodified 'A' yields 'a' or 'A'
// 4. Sequence with a cmd modifier
-(BOOL)isInterestingKeyboardSequence:(NSString*)seq
       forOutput:(NSString*)output
{
  BOOL interesting = NO;
  if ([seq length] > 0 && [output length] > 0)
  {
    interesting = YES;
    unichar ch1 = [seq characterAtIndex:0];
    unichar ch2 = [output characterAtIndex:0];
    if (ch2 <= 0x0020 || ch2 == 0x007F) interesting = NO;
    if ([seq length] == 1 && [output length] == 1)
    {
      if (ch1 == ch2 || (ch1 >= 'A' && ch1 <= 'Z' && ch2 - 0x0020 == ch1))
        interesting = NO;
    }
    if ([seq length] == 2 && [output length] == 1)
    {
      if (ch1 == kShiftUnicode || ch1 == kControlUnicode || ch1 == 0x21EA)
        ch1 = [seq characterAtIndex:1];
      if (ch1 == ch2 || (ch1 >= 'A' && ch1 <= 'Z' && ch2 - 0x0020 == ch1))
        interesting = NO;
    }
    unsigned i;
    for (i = 0; i < [seq length]; i++)
    {
      if ([seq characterAtIndex:i] == kCommandUnicode)
      {
        interesting = NO;
        break;
      }
    }
  }
  return interesting;
}

-(NSAttributedString*)attributedStringForKeyboardShortcut:(NSString*)seq
{
  NSMutableParagraphStyle* style = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
  [style setAlignment:NSCenterTextAlignment];
  NSMutableAttributedString* seq2 = [[NSMutableAttributedString alloc] initWithString:seq];
  NSColor* col = [NSColor colorWithCalibratedRed:0.75 green:0.1 blue:0.1 alpha:1.0];
  unsigned i;
  for (i = 0; i < [seq length]; i++)
  {
    if ([KeylayoutParser isModifier:[seq characterAtIndex:i]])
      [seq2 addAttribute:NSForegroundColorAttributeName value:col range:NSMakeRange(i, 1)];
  }
  [seq2 addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [seq length])];
  [style release];
  return [seq2 autorelease];
}

#pragma mark Auxiliary Windows
-(void)createAuxiliaryPanelForName:(NSString*)name withFrame:(NSRect)frame
       syncToDefaults:(BOOL)flag
{
  NSRect imf = frame;
  imf.size.width = frame.size.width - 4.0f;
  imf.size.height = frame.size.height - 4.0f;
  imf.origin = NSMakePoint(2.0f, 2.0f);
  PDFImageMap* newMap = [[PDFImageMap alloc] initWithFrame:imf];
  if ([name isEqualToString:@"User"])
  {
    NSArray* glyphs = [[NSUserDefaults standardUserDefaults] objectForKey:ipaUserGlyphsKey];
    if ([glyphs count])
    {
      NSArray* data = [glyphs slice:6];
      [PDFImageMapCreator setPDFImageMap:newMap toData:data
                          ofType:PDFImageMapColumnar dark:[NSApplication isDarkMode]];
    }
  }
  else
  {
    NSString* imageName = [PDFImageMapCreator copyPDFFileNameForName:name
                                              dark:[NSApplication isDarkMode]];
    [newMap setImage:[NSImage imageNamed:imageName]];
    NSString* path = [[NSBundle mainBundle] pathForResource:@"MapData" ofType:@"plist"];
    [newMap loadDataFromFile:path withName:name];
  }
  unsigned flags = NSTitledWindowMask | NSClosableWindowMask |
                   NSMiniaturizableWindowMask | NSResizableWindowMask |
                   NSUtilityWindowMask;
  IPAPanel* aux = [[IPAPanel alloc] initWithContentRect:frame styleMask:flags
                                    backing:NSBackingStoreBuffered defer:NO];
  if (!_auxiliaries) _auxiliaries = [[NSMutableSet alloc] init];
  NSString* auxPath = [[NSBundle mainBundle] pathForResource:@"AuxNames" ofType:@"strings"];
  NSDictionary* auxNames = [[NSDictionary alloc] initWithContentsOfFile:auxPath];
  NSString* auxName = [auxNames objectForKey:name];
  if (auxName)
  {
    auxName = [[Onizuka sharedOnizuka] copyLocalizedTitle:auxName];
    if (auxName)
    {
      [aux setTitle:auxName];
      [auxName release];
    }
  }
  [auxNames release];
  [aux setFloatingPanel:YES];
  [aux setHidesOnDeactivate:NO];
  [[aux contentView] addSubview:newMap];
  [aux setLevel:[_window level]];
  [aux setDelegate:self];
  [newMap setDelegate:self];
  [newMap setTarget:self];
  [newMap setAction:@selector(imageAction:)];
  [newMap setCanDragMap:NO];
  [newMap startTracking];
  [newMap release];
  [_auxiliaries addObject:aux];
  if (!_hidden) [aux orderFront:self];
  if (flag) [self syncAuxiliariesToDefaults];
}

// In defaults Auxiliaries is an array of strings,
// where the string is of the form "{stringified frame}__{map name}"
-(void)syncAuxiliariesToDefaults
{
  NSMutableArray* arr = [[NSMutableArray alloc] init];
  for (IPAPanel* aux in _auxiliaries)
  {
    PDFImageMap* im = [[[aux contentView] subviews] objectAtIndex:0];
    if ([im isKindOfClass:[PDFImageMap class]])
    {
      NSString* val = [[NSString alloc] initWithFormat:@"%@__%@",
                                        NSStringFromRect([aux frame]),
                                        [im name]];
      [arr addObject:val];
      [val release];
    }
  }
  [[NSUserDefaults standardUserDefaults] setObject:arr forKey:ipaAuxiliariesKey];
  [arr release];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)syncAuxiliariesFromDefaults
{
  NSArray* arr = [[NSUserDefaults standardUserDefaults] objectForKey:ipaAuxiliariesKey];
  for (NSString* val in arr)
  {
    NSArray* vals = [val componentsSeparatedByString:@"__"];
    //NSLog(@"%@ from %@", vals, val);
    NSRect frame = NSRectFromString([vals objectAtIndex:0]);
    NSString* name = [vals objectAtIndex:1];
    [self createAuxiliaryPanelForName:name withFrame:frame syncToDefaults:NO];
  }
}
@end


static NSComparisonResult local_SearchResultComp(id item1, id item2, void* something)
{
  #pragma unused (something)
  NSArray* a1 = item1;
  NSArray* a2 = item2;
  return [[a1 objectAtIndex:2] compare:[a2 objectAtIndex:2L] options:NSCaseInsensitiveSearch];
}

static void local_KeyboardChanged(CFNotificationCenterRef center,
   void* observer, CFStringRef name, const void* object,
   CFDictionaryRef userInfo)
{
  #pragma unused (center, name, object, userInfo)
  IPAServer* serv = (IPAServer*)observer;
  [serv keyboardChanged];
}

