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
#import "PDFImageMapCreator.h"
#import "Placeholder.h"
#import "TextRenderer.h"

#ifndef __PDFIMC_DEBUG__
#define __PDFIMC_DEBUG__ 0
#endif

@implementation NSArray (PDFImageMapCreator)
-(NSArray*)slice:(NSUInteger)size
{
  NSUInteger ct = [self count];
  NSUInteger slices = (ct/size) + ((ct%size)? 1:0);
  NSMutableArray* ary = [NSMutableArray arrayWithCapacity:slices];
  NSUInteger n = 1;
  NSUInteger offset = 0;
  while (n <= slices)
  {
    NSUInteger rest = (n==slices)? (ct-(size*(n-1))):size;
    [ary addObject:[self subarrayWithRange:NSMakeRange(offset, rest)]];
    n++;
    offset += rest;
  }
  return ary;
}
@end

typedef struct
{
  unichar voiceless;
  unichar voiced;
  // 0 if both possible, 1 if voiced impossible, (2 if voiceless), 3 if both
  uint8_t possibility;
} ConsInfo;

typedef struct
{
  unichar unrounded;
  unichar rounded;
  CGFloat x;
  CGFloat y;
} VowInfo;

static size_t local_PutBytesCB(void* info, const void* buffer, size_t count);
static void local_ReleaseInfoCB(void* info);

@interface PDFImageMapCreator (Private)
#if !__PDFIMC_RUNTIME_ONLY__
-(void)makeVowelMapWithFrame:(BOOL)frame named:(NSString*)name;
-(void)makeConsonantMapNamed:(NSString*)name;
#endif
-(void)makeColumnarMapNamed:(NSString*)name;
@end

@implementation PDFImageMapCreator
+(void)setPDFImageMap:(PDFImageMap*)map toData:(NSArray*)data ofType:(PDFImageMapType)type
{
  NSSize imgSize = [map bounds].size;
  NSUInteger slices = [data count];
  if (slices)
  {
    NSUInteger stacks = [[data objectAtIndex:0] count];
    NSUInteger w = (imgSize.height * slices) / stacks;
    if (stacks && 0 < w && w < imgSize.width) imgSize.width = w;
  }
  CGRect imgRect = CGRectMake(0.0L, 0.0L, imgSize.width, imgSize.height);
  NSMutableData* pdfData = [[NSMutableData alloc] init];
  static CGDataConsumerCallbacks const cbs = {local_PutBytesCB, local_ReleaseInfoCB};
  CGDataConsumerRef consumer = CGDataConsumerCreate(pdfData, &cbs);
  CGContextRef ctx = CGPDFContextCreate(consumer, &imgRect, nil);
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator makeImageMapOfType:type named:@"Custom"];
  NSArray* dat = (NSArray*)[[creator xmlWithContainer:YES] propertyList];
  [creator release];
  CGContextRelease(ctx);
  CGDataConsumerRelease(consumer);
  NSImage* pdf = [[NSImage alloc] initWithData:pdfData];
  [pdfData release];
  [map setImage:pdf];
  [pdf release];
  // Get the hot rect locations
  [map removeAllTrackingRects];
  for (NSDictionary* entry in dat)
  {
    NSString* key = [entry objectForKey:@"char"];
    SubRect r = NSRectFromString([entry objectForKey:@"rect"]);
    [map setTrackingRect:r forKey:key];
  }
}

#define SIXLeftPct (0.05)
#define SIXRightPct (0.3)
#define SIYBottomPct (0.05)
#define SIYTopPct (0.5)
// Starting from bottom left and going clockwise...
#define SIPt1(r) r.origin.x + (r.size.width * SIXLeftPct), r.origin.y + (r.size.height * SIYBottomPct)
#define SIPt2(r) r.origin.x + (r.size.width * SIXLeftPct), r.origin.y + (r.size.height * SIYTopPct)
#define SIPt3(r) r.origin.x + (r.size.width * SIXRightPct), r.origin.y + (r.size.height * ((SIYBottomPct+SIYTopPct)/2))
+(CGMutablePathRef)submapIndicatorQuartzInRect:(CGRect)rect
{
  CGMutablePathRef path = CGPathCreateMutable();
  CGPathMoveToPoint(path, NULL, SIPt1(rect));
  CGPathAddLineToPoint(path, NULL, SIPt2(rect));
  CGPathAddLineToPoint(path, NULL, SIPt3(rect));
  CGPathCloseSubpath(path);
  return path;
}

+(NSBezierPath*)submapIndicatorCocoaInRect:(NSRect)rect
{
  NSBezierPath* path = [NSBezierPath bezierPath];
  [path moveToPoint:NSMakePoint(SIPt1(rect))];
  [path lineToPoint:NSMakePoint(SIPt2(rect))];
  [path lineToPoint:NSMakePoint(SIPt3(rect))];
  [path closePath];
  return path;
}

#if !__PDFIMC_RUNTIME_ONLY__
+(void)drawSubmapIndicatorInRect:(CGRect)rect context:(CGContextRef)ctx
{
  CGContextSaveGState(ctx);
  CGMutablePathRef path = [PDFImageMapCreator submapIndicatorQuartzInRect:rect];
  CGContextSetRGBFillColor(ctx, 0.1f, 0.1f, 0.9f, 0.75f);
  CGContextAddPath(ctx, path);
  CGContextSetShadow(ctx, CGSizeMake(2.0f, -2.0f), 4.0);
  CGContextFillPath(ctx);
  CGPathRelease(path);
  CGContextRestoreGState(ctx);
}
#endif

-(id)initWithContext:(void*)ctx rect:(CGRect)rect data:(NSArray*)data
{
  self = [super init];
  _xml = [[NSMutableString alloc] init];
  _preferredFont = [[NSMutableString alloc] initWithString:@"Doulos SIL"];
  _ctx = CGContextRetain(ctx);
  _rect = rect;
  if (data) _data = [data retain];
  _submaps = [[NSMutableDictionary alloc] init];
  _fontOverrides = [[NSMutableDictionary alloc] init];
  _stringOverrides = [[NSMutableDictionary alloc] init];
  _placeholderOverrides = [[NSMutableDictionary alloc] init];
  return self;
}

-(void)dealloc
{
  if (_xml) [_xml release];
  if (_preferredFont) [_preferredFont release];
  if (_submaps) [_submaps release];
  if (_fontOverrides) [_fontOverrides release];
  if (_stringOverrides) [_stringOverrides release];
  if (_placeholderOverrides) [_placeholderOverrides release];
  if (_ctx) CGContextRelease(_ctx);
  if (_data) [_data release];
  [super dealloc];
}

-(void)setFontSize:(CGFloat)size {_fontSize = size;}
-(void)setPreferredFont:(NSString*)font {if (font) [_preferredFont setString:font];}

-(void)setOverrideString:(NSString*)str forString:(NSString*)string
{
  [_stringOverrides setObject:str forKey:string];
}

-(void)setOverridePlaceholder:(NSString*)str forString:(NSString*)string
{
  [_placeholderOverrides setObject:str forKey:string];
}


-(void)setOverrideFont:(NSString*)font forString:(NSString*)string;
{
  [_fontOverrides setObject:font forKey:string];
}

-(void)setSubmap:(NSString*)map forString:(NSString*)string
{
  [_submaps setObject:map forKey:string];
}

static const char* plistHeader = "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"\n  \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>\n";
static const char* plistFooter = "</array>\n</plist>\n";

-(NSString*)xmlWithContainer:(BOOL)container
{
  return [NSString stringWithFormat:@"%s%@%s", (container)? plistHeader:"",
          _xml, (container)? plistFooter:""];
}

-(void)makeImageMapOfType:(PDFImageMapType)type named:(NSString*)name
{
  switch (type)
  {
  #if !__PDFIMC_RUNTIME_ONLY__
    case PDFImageMapVowel:          [self makeVowelMapWithFrame:YES named:name];  break;
    case PDFImageMapFramelessVowel: [self makeVowelMapWithFrame:NO named:name];   break;
    case PDFImageMapConsonant:      [self makeConsonantMapNamed:name];           break;
  #endif
    default:                        [self makeColumnarMapNamed:name];            break;
  }
}

#if !__PDFIMC_RUNTIME_ONLY__
//#define kVowelQuadWidth (287.0)
//#define kVowelQuadHeight (218.0)
//#define kVowelQuadOverhang (148.0)
//#define kVowelDotSize (9.0)
//#define kVowelFontSize (30.0)
const CGFloat PDFImageMapVowelWidthPerHeight = 1.46L;
const CGFloat PDFImageMapVowelQuadWidth      = 0.77L;
const CGFloat PDFImageMapVowelQuadHeight     = 0.85L;
const CGFloat PDFImageMapVowelDotSize        = 0.035L; // Fraction of height
const CGFloat PDFImageMapVowelQuadOverhang   = 0.4L; // Fraction of width
// If not frame, this is the dragging-source-only supplementary image.
// Nothing is done to XML, and lines/dots are not drawn
-(void)makeVowelMapWithFrame:(BOOL)frame named:(NSString*)name
{
  CGPDFContextBeginPage(_ctx, NULL);
  CGContextSetLineJoin(_ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGContextSetRGBFillColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGRect imgRect = CGRectMake(0.0f, 0.0f, _rect.size.width, _rect.size.height);
  imgRect.size.width = imgRect.size.height*PDFImageMapVowelWidthPerHeight;
  if (imgRect.size.width > _rect.size.width)
  {
    CGFloat scale = _rect.size.width/imgRect.size.width;
    //NSLog(@"Scaling by %f", scale);
    imgRect.size.width *= scale;
    imgRect.size.height *= scale;
  }
  imgRect.origin.x = fabs(_rect.size.width * .5f - CGRectGetWidth(imgRect) * .5f);
  imgRect.origin.y = fabs(_rect.size.height * .5f - CGRectGetHeight(imgRect) * .5f);
  //CGFloat inset = 0.02f*imgRect.size.width;
  //imgRect = CGRectInset(imgRect, inset, inset);
#if __PDFIMC_DEBUG__
  CGContextStrokeRect(_ctx, imgRect);
#endif
  // The rectangle enclosing the vowel quad
  CGFloat vQuadWidth = imgRect.size.width*PDFImageMapVowelQuadWidth;
  CGFloat vQuadHeight = imgRect.size.height*PDFImageMapVowelQuadHeight;
  CGFloat vQuadOverhang = imgRect.size.width*PDFImageMapVowelQuadOverhang;
  CGFloat dotSize = imgRect.size.height*PDFImageMapVowelDotSize;
  CGRect vrect = CGRectMake(0.0f, 0.0f, vQuadWidth, vQuadHeight);
  // Center it in the PDF and draw
  vrect.origin.x = imgRect.origin.x + ((imgRect.size.width-vrect.size.width)*0.5f);
  vrect.origin.y = imgRect.origin.y + ((imgRect.size.height-vrect.size.height)*0.5f);
  //NSLog(@"vrect at %f,%f  %f,%f", vrect.origin.x, vrect.origin.y, vrect.size.width, vrect.size.height);
  if (frame)
  {
    CGContextBeginPath(_ctx);
    // Stroke the left and right sort-of verticals
    CGContextMoveToPoint(_ctx, vrect.origin.x+vQuadOverhang, vrect.origin.y);
    CGContextAddLineToPoint(_ctx, vrect.origin.x, vrect.origin.y+vrect.size.height);
#if __PDFIMC_DEBUG__
    CGContextAddLineToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
#endif    
    CGContextMoveToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
    CGContextAddLineToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y);
#if __PDFIMC_DEBUG__
    CGContextAddLineToPoint(_ctx, vrect.origin.x+vQuadOverhang, vrect.origin.y);
#endif
    CGContextStrokePath(_ctx);
  }
  CGFloat dy = vrect.size.height/3.0f;
  NSUInteger row, col;
  // Draw dots top to bottom
  for (row = 0; row < 4; row++)
  {
    if (!frame) break;
    CGFloat y = vrect.origin.y + ((3-row)*dy);
    CGFloat indent = vQuadOverhang * ((CGFloat)row/3.0f);
    CGFloat xstart = vrect.origin.x + indent;
    CGFloat dx = (vrect.size.width - indent)/2.0f;
    CGFloat x = xstart;
    //NSLog(@"row %d: indent %f dx %f x %f y %f", row, indent, dx, x, y);
#if __PDFIMC_DEBUG__
    CGContextBeginPath(_ctx);
    CGContextMoveToPoint(_ctx, xstart, y);
    CGContextAddLineToPoint(_ctx, vrect.origin.x + vrect.size.width, y);
    CGContextStrokePath(_ctx);
#endif
    for (col = 0; col < 3; col++)
    {
      if (row < 3 || col != 1)
      {
        CGRect dot = CGRectMake(x-(dotSize*0.5f),y-(dotSize*0.5f),dotSize,dotSize);
        //NSLog(@"  col %d: dot at %f,%f", col, dot.origin.x, dot.origin.y);
        CGContextFillEllipseInRect(_ctx, dot);
      }
      x += dx;
    }
  }
#if __PDFIMC_DEBUG__
  // Middle column
  CGContextBeginPath(_ctx);
  CGContextMoveToPoint(_ctx, vrect.origin.x + (vrect.size.width/2.0f), vrect.origin.y+vrect.size.height);
  CGContextAddLineToPoint(_ctx, vrect.origin.x + vQuadOverhang + ((vrect.size.width-vQuadOverhang)/2.0f), vrect.origin.y);
  CGContextStrokePath(_ctx);
#endif
  CGRect prect = CGRectMake(0.0f,0.0f,vQuadWidth/4.0f,vQuadHeight/6.0f);
  CGRect chrect = CGRectMake(0.0f,0.0f,prect.size.width/2.0f,prect.size.height);
  CGFloat baseline;
  (void)TRGetBestFontSize(_ctx, chrect, CFSTR("W"), (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &_fontSize, &baseline);
  // The zero for both vowels is a sentinel
  VowInfo vinfo[] = {
    {'i','y',0.02f,0.86f},{0x0268,0x0289,0.405f,0.86f},{0x026F,'u',0.79f,0.86f},
    {0x026A,0x028F,0.20f,0.72f},{1,0x028A,0.62f,0.72f},
    {'e',0x00F8,0.15f,0.58f},{0x0258,0x0275,0.47f,0.58f},{0x0264,'o',0.79f,0.58f},
    {0x0259,0,0.50f,0.44f},
    {0x025B,0x0153,0.285f,0.299f},{0x025C,0x025E,0.535f,0.299f},{0x028C,0x0254,0.79f,0.299f},
    {0x00E6,1,0.35f,0.156f},{0x0250,0,0.56f,0.156f},
    {0x025A,0x025D,0.02f,0.01f},{'a',0x0276,0.418f,0.01f},{0x0251,0x0252,0.79f,0.01f},
    {0,0,0.0f,0.0f}
  };
  NSUInteger i = 0;
  while (YES)
  {
    VowInfo info = vinfo[i];
    if (info.unrounded == 0 && info.rounded == 0) break;
    prect.origin.x = imgRect.origin.x + (info.x * imgRect.size.width);
    prect.origin.y = imgRect.origin.y + (info.y * imgRect.size.height);
    NSString* str;
    NSRect pctRect;
    //CGContextStrokeRect(ctx,prect);
    if (info.unrounded != 0)
    {
      chrect = prect;
      if (info.rounded != 0) chrect.size.width *= 0.5f;
#if __PDFIMC_DEBUG__
      CGContextStrokeRect(_ctx,chrect);
#endif
      if (info.unrounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.rounded == 0)
        {
          chrect.size.width *= 0.5f;
          chrect.origin.x += (chrect.size.width * 0.5f);
        }
        str = [[NSString alloc] initWithCharacters:&(info.unrounded) length:1];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, _fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [_xml appendFormat:@"<dict>\n  <key>char</key> <string>%@</string>\n", str];
        [_xml appendFormat:@"  <key>name</key> <string>%@</string>\n", name];
        [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
    }
    if (info.rounded != 0)
    {
      chrect = prect;
      if (info.unrounded != 0)
      {
        chrect.size.width *= 0.5f;
        chrect.origin.x += chrect.size.width;
      }
#if __PDFIMC_DEBUG__
      CGContextStrokeRect(_ctx,chrect);
#endif
      if (info.rounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.unrounded == 0)
        {
          chrect.size.width *= 0.5f;
          chrect.origin.x += (chrect.size.width * 0.5f);
        }
        str = [[NSString alloc] initWithCharacters:&(info.rounded) length:1];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, _fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [_xml appendFormat:@"<dict>\n  <key>char</key> <string>%@</string>\n", str];
        [_xml appendFormat:@"  <key>name</key> <string>%@</string>\n", name];
        [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
    }
    i++;
  }
  CGPoint frags[] = {
    // Horizontal
    {0.22f,0.925f},{0.41f,0.925f}, {0.60f,0.925f},{0.79f,0.925f},
    {0.34f,0.64f},{0.48f,0.64f},   {0.66f,0.64f},{0.79f,0.64f},
    {0.47f,0.36f},{0.545f,0.36f},  {0.72f,0.36f},{0.79f,0.36f},
                {0.61f,0.075f},  {0.79f,0.075f},
    // Vertical
    {0.50f,0.925f},{0.59f,0.545f},
    {0.61f,0.45f},{0.65f,0.28f},
    {0.675f,0.17f},{0.695f,0.075f},
    //Sentinel
    {0.0f,0.0f},{0.0f,0.0f}
  };
#if __PDFIMC_DEBUG__
  CGContextSetRGBStrokeColor(_ctx,1.0f,0.0f,0.0f,1.0f);
#endif
  CGContextBeginPath(_ctx);
  i = 0;
  while (YES && frame)
  {
    CGPoint p1 = frags[i];
    if (p1.x == 0.0 && p1.y == 0.0) break;
    p1.x = imgRect.origin.x + (p1.x * imgRect.size.width);
    p1.y = imgRect.origin.y + (p1.y * imgRect.size.height);
    CGPoint p2 = frags[i+1];
    CGContextMoveToPoint(_ctx, p1.x, p1.y);
    p2.x = imgRect.origin.x + (p2.x * imgRect.size.width);
    p2.y = imgRect.origin.y + (p2.y * imgRect.size.height);
    CGContextAddLineToPoint(_ctx, p2.x, p2.y);
    i += 2;
  }
  CGContextStrokePath(_ctx);
  CGPDFContextEndPage(_ctx);
}

CGFloat PDFImageMapConsonantWidthPerHeight = 2.9f;
-(void)makeConsonantMapNamed:(NSString*)name
{
  CGPDFContextBeginPage(_ctx, NULL);
  CGContextSetLineJoin(_ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGContextSetRGBFillColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGRect imgRect = CGRectMake(0.0f, 0.0f, _rect.size.width, _rect.size.height);
  imgRect.size.width = imgRect.size.height*PDFImageMapConsonantWidthPerHeight;
  if (imgRect.size.width > _rect.size.width)
  {
    CGFloat scale = _rect.size.width/imgRect.size.width;
    //NSLog(@"Scaling by %f", scale);
    imgRect.size.width *= scale;
    imgRect.size.height *= scale;
  }
  imgRect.origin.x = (_rect.size.width * .5f - CGRectGetWidth(imgRect) * .5f);
  imgRect.origin.y = (_rect.size.height * .5f - CGRectGetHeight(imgRect) * .5f);
  CGFloat inset = 0.01f*imgRect.size.width;
  imgRect = CGRectInset(imgRect, inset, inset);
  //NSLog(@"%@ centered in %@", NSStringFromRect(*(NSRect*)&imgRect), NSStringFromSize(_size));
  // These are the dimensions of a box containing a voicing pair
  CGFloat dy = imgRect.size.height/8.0f;
  CGFloat dx = imgRect.size.width/11.0f;
  CGFloat halfdx = 0.5f*dx;
  CGRect prect = CGRectMake(0.0f,0.0f,halfdx,dy);
  CGFloat baseline;
  CGFloat fsize;
  (void)TRGetBestFontSize(_ctx, prect, CFSTR("\xCA\x83"), (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &fsize, &baseline);
  if (!_fontSize) _fontSize = fsize;
  baseline += (baseline * 0.16f);
  //NSLog(@"font %f baseline %f", _fontSize, baseline);
  unsigned row, col;
  ConsInfo cinfo[8][11] =
  {
    {{'p','b',0},{0,0,0},{0,0,0},{'t','d',0},{0,0,0},{0x0288,0x0256,0},
                 {'c',0x025F,0},{'k',0x0261,0},{'q',0x0262,0},{0,0,1},{0x0294,0,1}},
    {{0,'m',0},{0,0x271,0},{0,0,0},{0,'n',0},{0,0,0},{0,0x0273,0},
                 {0,0x0272,0},{0,0x014B,0},{0,0x0274,0},{0,0,3},{0,0,3}},
    {{0,0x0299,0},{0,0,0},{0,0,0},{0,'r',0},{0,0,0},{0,0,0},
                 {0,0,0},{0,0,3},{0,0x0280,0},{0,0,0},{0,0,3}},
    {{0,0,0},{0,0x2C71,0},{0,0,0},{0,0x027E,0},{0,0,0},{0,0x027D,0},
                 {0,0,0},{0,0,3},{0,0,0},{0,0,0},{0,0,3}},
    {{0x0278,0x03B2,0},{'f','v',0},{0x03B8,0x00F0,0},{'s','z',0},{0x0283,0x0292,0},{0x0282,0x0290,0},
                 {0x00E7,0x029D,0},{'x',0x0263,0},{0x03C7,0x0281,0},{0x0127,0x0295,0},{'h',0x0266,0}},
    {{0,0,3},{0,0,3},{0,0,0},{0x026C,0x026E,0},{0,0,0},{0,0,0},
                 {0,0,0},{0,0,0},{0,0,0},{0,0,3},{0,0,3}},
    {{0,0,0},{0,0x028B,0},{0,0,0},{0,0x0279,0},{0,0,0},{0,0x027B,0},
                 {0,'j',0},{0,0x0270,0},{0,0,0},{0,0,0},{0,0,3}},
    {{0,0,3},{0,0,3},{0,0,0},{0,'l',0},{0,0,0},{0,0x026D,0},
                 {0,0x028E,0},{0,0x029F,0},{0,0,0},{0,0,3},{0,0,3}}
  };
  for (row = 0; row < 8; row++)
  {
    CGFloat y2 = imgRect.origin.y+imgRect.size.height-(row*dy);
    CGFloat y = y2 - dy;
    for (col = 0; col < 11; col++)
    {
      CGFloat x = imgRect.origin.x+(col*dx);
      //CGFloat x2 = x + dx;
      //NSLog(@"y %f y2 %f x %f x2 %f", y, y2, x, x2);
      ConsInfo info = cinfo[row][col];
      prect = CGRectMake(x,y,dx,dy);
      CGRect chrect = prect;
      if (info.possibility > 0)
      {
        if (info.possibility == 1) chrect.origin.x += halfdx;
        if (info.possibility < 3) chrect.size.width = halfdx;
        CGContextSetRGBFillColor(_ctx,0.78f,0.78f,0.78f,1.0f);
        CGContextFillRect(_ctx, chrect);
        if (info.possibility < 3)
        {
          CGContextBeginPath(_ctx);
          CGContextMoveToPoint(_ctx,x+halfdx,y);
          CGContextAddLineToPoint(_ctx,x+halfdx,y2);
          CGContextStrokePath(_ctx);
        }
      }
      NSString* str;
      NSRect pctRect;
      if (info.voiceless != 0)
      {
        chrect = prect;
        chrect.size.width = halfdx;
        str = [[NSString alloc] initWithCharacters:&(info.voiceless) length:1L];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, _fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                             (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                              chrect.size.width/_rect.size.width,
                              chrect.size.height/_rect.size.height);
        [_xml appendFormat:@"<dict>\n  <key>char</key> <string>%@</string>\n", str];
        [_xml appendFormat:@"  <key>name</key> <string>%@</string>\n", name];
        [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
      if (info.voiced != 0)
      {
        chrect = prect;
        chrect.origin.x += halfdx;
        chrect.size.width = halfdx;
        str = [[NSString alloc] initWithCharacters:&(info.voiced) length:1L];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, _fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                             (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                              chrect.size.width/_rect.size.width,
                              chrect.size.height/_rect.size.height);
        [_xml appendFormat:@"<dict>\n  <key>char</key> <string>%@</string>\n", str];
        [_xml appendFormat:@"  <key>name</key> <string>%@</string>\n", name];
        [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
    }
  }
  // Put horizontal lines
  CGContextBeginPath(_ctx);
  // Draw the horizontal lines
  for (row = 1; row < 8; row++)
  {
    CGFloat y = imgRect.origin.y+(row*dy);
    CGContextMoveToPoint(_ctx, imgRect.origin.x, y);
    CGContextAddLineToPoint(_ctx, imgRect.origin.x + imgRect.size.width, y);
  }
  CGContextStrokePath(_ctx);
  // Draw the vertical lines
  CGContextBeginPath(_ctx);
  for (col = 1; col < 11; col++)
  {
    CGFloat x = imgRect.origin.x+(col*dx);
    if (col < 3 || col > 4)
    {
      CGContextMoveToPoint(_ctx, x, imgRect.origin.y);
      CGContextAddLineToPoint(_ctx, x, imgRect.origin.y+imgRect.size.height);
    }
    else
    {
      CGContextMoveToPoint(_ctx, x, imgRect.origin.y+(dy*4));
      CGContextAddLineToPoint(_ctx, x, imgRect.origin.y+(dy*3));
    }
  }
  CGContextStrokePath(_ctx);
  // Enclose chart
  CGContextStrokeRect(_ctx, imgRect);
  CGPDFContextEndPage(_ctx);
}
#endif //#if !__PDFIMC_RUNTIME_ONLY__

-(void)makeColumnarMapNamed:(NSString*)name
{
  CGPDFContextBeginPage(_ctx, NULL);
  CGContextSetLineJoin(_ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGContextSetRGBFillColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGRect r = _rect;
  NSUInteger cols = [_data count];
  NSUInteger rows = 1;
  for (NSArray* subarray in _data)
  {
    if ([subarray count] > rows) rows = [subarray count];
  }
  if (rows < 6) rows = 6;
#if __PDFIMC_DEBUG__
  CGContextStrokeRect(_ctx,r);
#endif
  CGFloat dx = r.size.width/cols;
  CGFloat dy = r.size.height/rows;
  NSUInteger row, col;
  CGRect chrect = CGRectMake(0.0f,0.0f,dx,dy);
  CGFloat baseline = 0.0f;
  CGFloat strSize;
  if (!_fontSize)
  {
    _fontSize = 200.0;
    for (NSArray* colArray in _data)
    {
      for (NSString* str in colArray)
      {
        if (![str length]) continue;
        unichar chr = [str characterAtIndex:0L];
        NSString* toDraw = str;
        if ([_stringOverrides objectForKey:str])
          toDraw = [_stringOverrides objectForKey:str];
        if (NeedsPlaceholder(chr))
        {
          NSString* ph = [_placeholderOverrides objectForKey:str];
          if (ph) [ph retain];
          else ph = [[NSString alloc] initWithFormat:@"%C", PlaceholderDottedCircle];
          toDraw = [NSString stringWithFormat:@"%@%@", ph, toDraw];
          [ph release];
        }
        CGFloat strBaseline;
        (void)TRGetBestFontSize(_ctx, chrect, (CFStringRef)toDraw, (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &strSize, &strBaseline);
        if (strSize < _fontSize)
        {
          baseline = strBaseline;
          _fontSize = strSize;
          //NSLog(@"baseline now %f", baseline);
        }
      }
    }
  }
  else
  {
    (void)TRGetBestFontSize(_ctx, chrect, (CFStringRef)@"a", (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &strSize, &baseline);
  }
#if __PDFIMC_DEBUG__
  // Draw the horizontal lines
  CGContextBeginPath(_ctx);
  for (row = 1; row < rows; row++)
  {
    CGFloat y = r.origin.y+(row*dy);
    CGContextMoveToPoint(_ctx, r.origin.x, y);
    CGContextAddLineToPoint(_ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(_ctx);
  // Draw the baselines
  CGContextBeginPath(_ctx);
  for (row = 0; row < rows; row++)
  {
    CGFloat y = r.origin.y+(row*dy)+baseline;
    CGContextMoveToPoint(_ctx, r.origin.x, y);
    CGContextAddLineToPoint(_ctx, r.origin.x + r.size.width, y);
  }
  CGContextSetRGBStrokeColor(_ctx, 1.0f, 0.0f, 0.0f, 0.5f);
  CGContextStrokePath(_ctx);
  CGContextSetRGBStrokeColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  // Draw the vertical lines
  CGContextBeginPath(_ctx);
  for (col = 1; col < cols; col++)
  {
    CGFloat x = r.origin.x+(col*dx);
    CGContextMoveToPoint(_ctx, x, r.origin.y);
    CGContextAddLineToPoint(_ctx, x, r.origin.y+r.size.height);
  }
  CGContextStrokePath(_ctx);
#endif
  //NSLog(@"%@: %f baseline %f", name, _fontSize, baseline);
  col = 0;
  NSRect pctRect;
  for (NSArray* colArray in _data)
  {
    chrect.origin.x = r.origin.x + (col*dx);
    row = 0;
    for (NSString* str in colArray)
    {
      if (![str length]) continue;
      NSString* submap = [_submaps objectForKey:str];
      NSString* fontOverride = [_fontOverrides objectForKey:str];
      NSString* useFont = (fontOverride)? fontOverride:_preferredFont;
      unichar chr = [str characterAtIndex:0L];
      NSString* toDraw = str;
      if ([_stringOverrides objectForKey:str])
        toDraw = [_stringOverrides objectForKey:str];
      if (NeedsPlaceholder(chr))
      {
        NSString* ph = [_placeholderOverrides objectForKey:str];
        if (ph) [ph retain];
        else ph = [[NSString alloc] initWithFormat:@"%C", PlaceholderDottedCircle];
        toDraw = [NSString stringWithFormat:@"%@%@", ph, toDraw];
        [ph release];
      }
      chrect.origin.y = r.origin.y + ((rows-row-1)*dy);
    #if !__PDFIMC_RUNTIME_ONLY__
      if (submap) [PDFImageMapCreator drawSubmapIndicatorInRect:chrect context:_ctx];
    #endif
      OSStatus err = TRRenderText(_ctx, chrect, (CFStringRef)toDraw, (CFStringRef)useFont, _fontSize, TRSubstituteFallbackBehavior, baseline);
      if (err) NSLog(@"Error: %ld drawing %@", (long)err, toDraw);
      //NSLog(@"%@ in %@ at %f baseline %f (%d) (%@)", toDraw, NSStringFromRect(*(NSRect*)&chrect), _fontSize, baseline, err, useFont);
      pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                           (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                            chrect.size.width/_rect.size.width,
                            chrect.size.height/_rect.size.height);
      [_xml appendFormat:@"<dict>\n  <key>char</key> <string>%@</string>\n", str];
      [_xml appendFormat:@"  <key>name</key> <string>%@</string>\n", name];
      if (submap) [_xml appendFormat:@"  <key>submap</key> <string>%@</string>\n", submap];
      [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      row++;
    }
    col++;
  }
  CGPDFContextEndPage(_ctx);
}
@end

static size_t local_PutBytesCB(void* info, const void* buffer, size_t count)
{
  NSMutableData* pdfData = info;
  [pdfData appendBytes:buffer length:count];
  return count;
}

static void local_ReleaseInfoCB(void* info)
{
  #pragma unused(info)
  return;
}

