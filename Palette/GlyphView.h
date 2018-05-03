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
#import "TextRenderer.h"

enum
{
  GlyphViewSubstituteFont,
  GlyphViewLastResortFont,
  GlyphViewWarningOnly
};

@interface GlyphView : NSImageView
{
  NSMutableString*  _font;
  NSMutableString*  _stringValue;
  CGFloat           _fontSize;
  CGFloat           _baseline;
  uint8_t           _fallbackBehavior;
  BOOL              _setup; // Font size has been set up
}
-(void)setStringValue:(NSString*)str;
-(void)setFont:(NSString*)font;
-(void)setFallbackBehavior:(uint8_t)flag;
@end
