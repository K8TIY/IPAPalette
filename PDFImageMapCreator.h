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
  BOOL                 _darkMode;
}

@property (nonatomic, assign) BOOL darkMode;
+(NSString*)copyPDFFileNameForName:(NSString*)name dark:(BOOL)dark;
+(void)setPDFImageMap:(PDFImageMap*)map toData:(NSArray*)data
       ofType:(PDFImageMapType)type dark:(BOOL)dark;
+(CGMutablePathRef)newSubmapIndicatorQuartzInRect:(CGRect)rect;
+(NSBezierPath*)newSubmapIndicatorCocoaInRect:(NSRect)rect;
#if !__PDFIMC_RUNTIME_ONLY__
+(void)drawSubmapIndicatorInRect:(CGRect)rect context:(CGContextRef)ctx
       dark:(BOOL)dark;
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

/*
Copyright © 2005-2020 Brian S. Hall, BLUGS.COM LLC

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
