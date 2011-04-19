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

@interface UserGlyphsTable : NSTableView
{}
@end

@interface UserGlyphsController : NSObject
{
  NSMutableArray*           _glyphs;
  NSMutableDictionary*      _descriptions;
  NSMutableArray*           _editglyphs;
  NSMutableArray*           _editdescriptions;
  IBOutlet UserGlyphsTable* _table;
  IBOutlet NSPanel*         _editSheet;
  IBOutlet NSWindow*        _window;
  id                        delegate;
}
-(NSArray*)glyphs;
-(NSDictionary*)descriptions;
-(void)setGlyphs:(NSArray*)glyphs andDescriptions:(NSDictionary*)descriptions;
-(void)edit;
-(IBAction)addAction:(id)sender;
-(IBAction)acceptSheet:(id)sender;
-(IBAction)cancelSheet:(id)sender;
@end
