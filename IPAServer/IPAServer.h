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
#include "IPAClientServer.h"
#include "GlyphView.h"
#include "PDFImageMap.h"
#include "UserGlyphsController.h"

// Skanky hack to resign key when search text is deactivated.
@interface IPAApplication : NSApplication
-(void)setIsActive:(BOOL)flag;
-(void)_deactivateWindows;
@end

@interface IPASearchField: NSTextField {} @end
@interface IPASearchResults: NSTableView {} @end
@interface IPAPanel : NSPanel {} @end

@interface IPAServer : NSObject
{
  IBOutlet IPAPanel* _window;
  IBOutlet PDFImageMap*  _consonants;
  IBOutlet PDFImageMap*  _vowels;
  IBOutlet PDFImageMap*  _supra;
  IBOutlet PDFImageMap*  _diacritic;
  IBOutlet PDFImageMap*  _other;
  IBOutlet PDFImageMap*  _extipa;
  IBOutlet PDFImageMap*  _user;
  IBOutlet NSPanel* _alert;
  IBOutlet NSImageView* _alertIcon;
  IBOutlet NSButton* _dontShowAgainButton;
  IBOutlet GlyphView* _glyphView;
  IBOutlet NSPopUpButton* _fontMenu;
  IBOutlet NSProgressIndicator* _spinny;
  IBOutlet NSPopUpButton* _debugMenu;
  IBOutlet NSPopUpButton* _componentDebugMenu;
  IBOutlet NSPopUpButton* _fallbackMenu;
  IBOutlet NSTabView* _tabs;
  IBOutlet NSTextField* _scanningText;
  IBOutlet NSTextField* _unicodeText;
  IBOutlet NSTextField* _descriptionText;
  IBOutlet IPASearchResults* _searchResultsTable;
  IBOutlet IPASearchField* _searchText;
  IBOutlet NSButton* _updateButton;
  IBOutlet NSTextField* _updateResults;
  IBOutlet UserGlyphsController* _userGlyphsController;
  NSTabViewItem* _userGlyphsTab;
  NSView* _fontMenuSuperview;
  NSTimer* _timer;
  NSInteger _timeout; // Seconds between window close and server termination
  BOOL _hidden; // YES if the window has been explicitly hidden
  NSMutableDictionary* _alts;
  //NSMutableDictionary* _userGlyphDescriptions;
  NSDictionary* _descToGlyph; // For search
  NSMutableArray* _searchResults;
  NSURLConnection* _updateCheck;
  NSMutableData* _updateData;
#if __IPA_CM__
  NSMutableString* _activeComponent;
#endif
  uint8_t _debug;
}
+(NSString*)copyUPlusForString:(NSString*)str;
-(IBAction)addSymbolAction:(id)sender;
-(IBAction)imageAction:(id)sender;
-(IBAction)fontAction:(id)sender;
-(IBAction)debugAction:(id)sender;
-(IBAction)componentDebugAction:(id)sender;
-(IBAction)fallbackAction:(id)sender;
-(IBAction)closeAlertAction:(id)sender;
-(IBAction)updatesAction:(id)sender;
-(IBAction)downloadUpdatesAction:(id)sender;
@end



