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
#import "PDFImageMap.h"

@interface AppController : NSObject
{
  IBOutlet NSProgressIndicator* _spinny;
  IBOutlet NSTextField* _info;
  IBOutlet NSWindow* _window;
}
@end
