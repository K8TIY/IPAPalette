/*
Copyright © 2009-2011 Brian S. Hall

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
#import "PDFImageMap.h"

@interface AppController : NSObject
{
  IBOutlet NSProgressIndicator* _spinny;
  IBOutlet NSTextField* _info;
  IBOutlet NSWindow* _window;
  
  IBOutlet NSButton* _vowButton;
  IBOutlet NSButton* _vowDragButton;
  IBOutlet NSButton* _supraToneButton;
  IBOutlet NSButton* _consButton;
  IBOutlet NSButton* _diacriticButton;
  IBOutlet NSButton* _palButton;
  IBOutlet NSButton* _retroButton;
  IBOutlet NSButton* _vPhButton;
  IBOutlet NSButton* _otherButton;
  IBOutlet NSButton* _extIPAButton;
  
  NSMutableString*   _xml;
}

-(IBAction)doIt:(id)sender;
@end
