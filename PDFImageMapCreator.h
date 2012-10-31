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

@interface NSArray (PDFImageMapCreator)
-(NSArray*)slice:(NSUInteger)size;
@end

#ifndef __PDFIMC_RUNTIME_ONLY__
#define __PDFIMC_RUNTIME_ONLY__ 0
#endif

typedef enum
{
  PDFImageMapVowel,
  PDFImageMapFramelessVowel,
  PDFImageMapConsonant,
  PDFImageMapColumnar
} PDFImageMapType;

@interface PDFImageMapCreator : NSObject
{
  void*                _ctx; // CG context
  NSArray*             _data;
  CGRect               _rect;
  NSMutableString*     _xml;
  NSMutableString*     _preferredFont;
  NSString*            _chart;
  NSMutableDictionary* _submaps;
  NSMutableDictionary* _fontOverrides;
  NSMutableDictionary* _stringOverrides;
  NSMutableDictionary* _placeholderOverrides;
  CGFloat              _fontSize;
}
+(void)setPDFImageMap:(PDFImageMap*)map toData:(NSArray*)data ofType:(PDFImageMapType)type;
+(CGMutablePathRef)newSubmapIndicatorQuartzInRect:(CGRect)rect;
+(NSBezierPath*)newSubmapIndicatorCocoaInRect:(NSRect)rect;
#if !__PDFIMC_RUNTIME_ONLY__
+(void)drawSubmapIndicatorInRect:(CGRect)rect context:(CGContextRef)ctx;
#endif
-(id)initWithContext:(void*)ctx rect:(CGRect)rect data:(NSArray*)data;
-(void)setFontSize:(CGFloat)size;
-(void)setPreferredFont:(NSString*)font;
-(void)setOverrideString:(NSString*)str forString:(NSString*)string;
-(void)setOverridePlaceholder:(NSString*)str forString:(NSString*)string;
-(void)setOverrideFont:(NSString*)font forString:(NSString*)string;
-(void)setSubmap:(NSString*)map forString:(NSString*)string;
-(NSString*)xmlWithContainer:(BOOL)container;
-(void)makeImageMapOfType:(PDFImageMapType)type named:(NSString*)name;
@end

