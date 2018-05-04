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
  IBOutlet NSButton* _updateButton;
  IBOutlet NSTextField* _updateResults;
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



