/*
Copyright © 2005-2011 Brian S. Hall

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

@interface UserGlyphsTable : NSTableView
{}
@end

@interface UserGlyphsController : NSObject
{
  NSMutableArray*           _editglyphs;       // Data being edited in the sheet
  NSMutableArray*           _editdescriptions; // Data being edited in the sheet
  IBOutlet UserGlyphsTable* _table;
  IBOutlet NSPanel*         _editSheet;
  IBOutlet NSWindow*        _window;
  id                        delegate;
}
-(IBAction)editSymbolsAction:(id)sender;
-(IBAction)exportSymbolsAction:(id)sender;
-(IBAction)importSymbolsAction:(id)sender;
-(IBAction)addAction:(id)sender;
-(IBAction)acceptSheet:(id)sender;
-(IBAction)cancelSheet:(id)sender;
@end
