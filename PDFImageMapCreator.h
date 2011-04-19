/*
Copyright © 2009-2010 Brian S. Hall

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
#import "PDFImageMap.h";

extern CGFloat PDFImageMapConsonantWidthPerHeight;

typedef enum
{
  PDFImageMapVowel,
  PDFImageMapFramelessVowel,
  PDFImageMapConsonant,
  PDFImageMapColumnar
} PDFImageMapType;

@interface PDFImageMapCreator : NSObject
{
  void*            _ctx; // CG context
  NSArray*         _data;
  CGRect           _rect;
  NSMutableString* _xml;
  NSMutableString* _preferredFont;
  CGFloat          _fontsize;
  CGFloat          _margin;
  BOOL             _drawLines; // for debugging
}
+(void)setPDFImapgeMap:(PDFImageMap*)map toData:(NSArray*)data ofType:(PDFImageMapType)type;
-(id)initWithContext:(void*)ctx rect:(CGRect)rect data:(NSArray*)data;
-(void)setFontSize:(CGFloat)size;
-(void)setPreferredFont:(NSString*)font;
-(void)setMargin:(CGFloat)m;
-(NSString*)xml;
-(void)makeImageMapOfType:(PDFImageMapType)type;
@end
