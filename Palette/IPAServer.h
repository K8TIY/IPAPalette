#import <Cocoa/Cocoa.h>
#import "IPAInputController.h"
#include "GlyphView.h"
#include "PDFImageMap.h"
#include "UserGlyphsController.h"

extern NSString* ipaUserGlyphsKey;
extern NSString* ipaUserGlyphDescriptionsKey;
extern NSString* ipaDebugKey;

#define __DBG ([[NSUserDefaults standardUserDefaults] integerForKey:ipaDebugKey])

// Shared debug levels
enum
{
  ipaSilentDebugLevel,
  ipaDebugDebugLevel,
  ipaVerboseDebugLevel,
  ipaInsaneDebugLevel
};

@interface IPASearchField: NSSearchField {} @end
@interface IPASearchResults: NSTableView {} @end
@interface IPAPanel : NSPanel {} @end

@interface IPAServer : NSObject <NSApplicationDelegate,NSWindowDelegate>
{
  IBOutlet IPAPanel* _window;
  IBOutlet PDFImageMap*  _consonants;
  IBOutlet PDFImageMap*  _vowels;
  IBOutlet PDFImageMap*  _supra;
  IBOutlet PDFImageMap*  _diacritic;
  IBOutlet PDFImageMap*  _other;
  IBOutlet PDFImageMap*  _extipa;
  IBOutlet PDFImageMap*  _user;
  IBOutlet GlyphView* _glyphView;
  IBOutlet NSPopUpButton* _fontMenu;
  IBOutlet NSTabView* _tabs;
  IBOutlet NSTextField* _scanningText;
  IBOutlet NSTextField* _unicodeText;
  IBOutlet NSTextField* _keyboardText;
  IBOutlet NSTextField* _descriptionText;
  IBOutlet IPASearchResults* _searchResultsTable;
  IBOutlet IPASearchField* _searchText;
  IBOutlet UserGlyphsController* _userGlyphsController;
  IPAInputController* _inputController;
  NSTabViewItem* _userGlyphsTab;
  NSView* _fontMenuSuperview;
  //NSTimer* _timer;
  //NSInteger _timeout; // Seconds between window close and server termination
  BOOL _hidden; // YES if the window has been explicitly hidden
  NSMutableDictionary* _alts;
  NSMutableDictionary* _keyboard;
  NSDictionary* _descToGlyph; // For search
  NSMutableArray* _searchResults;
  NSString* _savedSubwindow;
  NSMutableSet* _auxiliaries; // of IPAPanel: aux windows dragged
}
+(IPAServer*)sharedServer;
+(NSString*)copyUPlusForString:(NSString*)str;
-(IBAction)imageAction:(id)sender;
-(IBAction)fontAction:(id)sender;
-(void)activateWithWindowLevel:(NSInteger)level;
-(void)hide;
-(void)setError;
-(void)setInputController:(IPAInputController*)ic;
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
