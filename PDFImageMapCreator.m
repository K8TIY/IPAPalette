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
#import "PDFImageMapCreator.h"
#import "Placeholder.h"
#import "TextRenderer.h"

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
-(void)makeVowelMapWithFrame:(BOOL)frame;
-(void)makeConsonantMap;
-(void)makeColumnarMap;
@end

@implementation PDFImageMapCreator
+(void)setPDFImapgeMap:(PDFImageMap*)map toData:(NSArray*)data ofType:(PDFImageMapType)type
{
  NSSize imgSize = [map bounds].size;
  CGRect imgRect = CGRectMake(0.0L, 0.0L, imgSize.width, imgSize.height);
  NSMutableData* pdfData = [[NSMutableData alloc] init];
  static CGDataConsumerCallbacks const cbs = {local_PutBytesCB, local_ReleaseInfoCB};
  CGDataConsumerRef consumer = CGDataConsumerCreate(pdfData, &cbs);
  CGContextRef ctx = CGPDFContextCreate(consumer, &imgRect, nil);
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator makeImageMapOfType:type];
  NSArray* dat = (NSArray*)[[creator xml] propertyList];
  [creator release];
  CGContextRelease(ctx);
  CGDataConsumerRelease(consumer);
  NSImage* pdf = [[NSImage alloc] initWithData:pdfData];
  [pdfData release];
  [map setImage:pdf];
  [pdf release];
  // Get the hot rect locations
  NSDictionary* entry;
  NSEnumerator* enumerator = [dat objectEnumerator];
  [map removeAllTrackingRects];
  while ((entry = [enumerator nextObject]))
  {
    NSString* key = [entry objectForKey:@"char"];
    SubRect r = NSRectFromString([entry objectForKey:@"rect"]);
    [map setTrackingRect:r forKey:key];
  }
}

-(id)initWithContext:(void*)ctx rect:(CGRect)rect data:(NSArray*)data
{
  self = [super init];
  _xml = [[NSMutableString alloc] init];
  [_xml appendString:
    @"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"\n"];
  [_xml appendString:@"  \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"];
  [_xml appendString:@"<plist version=\"1.0\">\n<array>"];
  _preferredFont = [[NSMutableString alloc] initWithString:@"Doulos SIL"];
  _ctx = CGContextRetain(ctx);
  _rect = rect;
  _fontsize = 28.0f;
  _margin = 10.0f;
  _data = [data retain];
  //_drawLines = YES;
  return self;
}

-(void)dealloc
{
  if (_xml) [_xml release];
  if (_preferredFont) [_preferredFont release];
  CGContextRelease(_ctx);
  [_data release];
  [super dealloc];
}

-(void)setFontSize:(CGFloat)size {_fontsize = size;}
-(void)setPreferredFont:(NSString*)font {if (font) [_preferredFont setString:font];}
-(void)setMargin:(CGFloat)m {_margin = m;}
-(NSString*)xml {return [NSString stringWithString:_xml];}

-(void)makeImageMapOfType:(PDFImageMapType)type
{
  switch (type)
  {
    case PDFImageMapVowel:          [self makeVowelMapWithFrame:YES];  break;
    case PDFImageMapFramelessVowel: [self makeVowelMapWithFrame:NO];   break;
    case PDFImageMapConsonant:      [self makeConsonantMap];           break;
    default:                        [self makeColumnarMap];            break;
  }
}

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
-(void)makeVowelMapWithFrame:(BOOL)frame
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
  imgRect.origin.x = (_rect.size.width * .5f - CGRectGetWidth(imgRect) * .5f);
  imgRect.origin.y = (_rect.size.height * .5f - CGRectGetHeight(imgRect) * .5f);
  CGFloat inset = 0.02f*imgRect.size.width;
  imgRect = CGRectInset(imgRect, inset, inset);
  if (_drawLines) CGContextStrokeRect(_ctx, imgRect);
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
    if (_drawLines) CGContextAddLineToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
    CGContextMoveToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
    CGContextAddLineToPoint(_ctx, vrect.origin.x+vrect.size.width, vrect.origin.y);
    if (_drawLines) CGContextAddLineToPoint(_ctx, vrect.origin.x+vQuadOverhang, vrect.origin.y);
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
    if (_drawLines)
    {
      CGContextBeginPath(_ctx);
      CGContextMoveToPoint(_ctx, xstart, y);
      CGContextAddLineToPoint(_ctx, vrect.origin.x + vrect.size.width, y);
      CGContextStrokePath(_ctx);
    }
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
  if (_drawLines)
  {
    // Middle column
    CGContextBeginPath(_ctx);
    CGContextMoveToPoint(_ctx, vrect.origin.x + (vrect.size.width/2.0f), vrect.origin.y+vrect.size.height);
    CGContextAddLineToPoint(_ctx, vrect.origin.x + vQuadOverhang + ((vrect.size.width-vQuadOverhang)/2.0f), vrect.origin.y);
    CGContextStrokePath(_ctx);
  }
  CGRect prect = CGRectMake(0.0f,0.0f,vQuadWidth/4.0f,vQuadHeight/6.0f);
  CGRect chrect = CGRectMake(0.0f,0.0f,prect.size.width/2.0f,prect.size.height);
  CGFloat baseline;
  CGFloat fontSize;
  (void)TRGetBestFontSize(_ctx, chrect, CFSTR("W"), (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &fontSize, &baseline);
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
      if (_drawLines) CGContextStrokeRect(_ctx,chrect);
      if (info.unrounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.rounded == 0)
        {
          chrect.size.width *= 0.5f;
          chrect.origin.x += (chrect.size.width * 0.5f);
        }
        str = [[NSString alloc] initWithCharacters:&(info.unrounded) length:1];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [_xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
        [_xml appendString:@"  <key>chart</key> <string>vowel</string>\n"];
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
      if (_drawLines) CGContextStrokeRect(_ctx,chrect);
      if (info.rounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.unrounded == 0)
        {
          chrect.size.width *= 0.5f;
          chrect.origin.x += (chrect.size.width * 0.5f);
        }
        str = [[NSString alloc] initWithCharacters:&(info.rounded) length:1];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [_xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
        [_xml appendString:@"  <key>chart</key> <string>vowel</string>\n"];
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
  if (_drawLines) CGContextSetRGBStrokeColor(_ctx,1.0f,0.0f,0.0f,1.0f);
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
  [_xml appendString:@"</array>\n</plist>\n"];
}

CGFloat PDFImageMapConsonantWidthPerHeight = 2.9f;
-(void)makeConsonantMap
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
    NSLog(@"Scaling by %f", scale);
    imgRect.size.width *= scale;
    imgRect.size.height *= scale;
  }
  imgRect.origin.x = (_rect.size.width * .5f - CGRectGetWidth(imgRect) * .5f);
  imgRect.origin.y = (_rect.size.height * .5f - CGRectGetHeight(imgRect) * .5f);
  CGFloat inset = 0.02f*imgRect.size.width;
  imgRect = CGRectInset(imgRect, inset, inset);
  //NSLog(@"%@ centered in %@", NSStringFromRect(*(NSRect*)&imgRect), NSStringFromSize(_size));
  // These are the dimensions of a box containing a voicing pair
  CGFloat dy = imgRect.size.height/8.0f;
  CGFloat dx = imgRect.size.width/11.0f;
  CGFloat halfdx = 0.5f*dx;
  CGRect prect = CGRectMake(0.0f,0.0f,halfdx,dy);
  CGFloat baseline;
  CGFloat fontSize;
  (void)TRGetBestFontSize(_ctx, prect, CFSTR("W"), (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &fontSize, &baseline);
  NSLog(@"baseline %f", baseline);
  unsigned row, col;
  ConsInfo cinfo[8][11] =
  {
    {{0x82B1,'b',0},{0,0,0},{0,0,0},{'t','d',0},{0,0,0},{0x0288,0x0256,0},
                 {'c',0x025F,0},{'k',0x0261,0},{'q',0x0262,0},{0,0,1},{0x0294,0,1}},
    {{0,'m',0},{0,0x271,0},{0,0,0},{0,'n',0},{0,0,0},{0,0x0273,0},
                 {0,0x0272,0},{0,0x014B,0},{0,0x0274,0},{0,0,3},{0,0,3}},
    {{0,0x0299,0},{0,0,0},{0,0,0},{0,'r',0},{0,0,0},{0,0x027D,0},
                 {0,0,0},{0,0,3},{0,0x0280,0},{0,0,0},{0,0,3}},
    {{0,0,0},{0,0x2C71,0},{0,0,0},{0,0x027E,0},{0,0,0},{0,0,0},
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
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                             (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                              chrect.size.width/_rect.size.width,
                              chrect.size.height/_rect.size.height);
        [_xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
        [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
      if (info.voiced != 0)
      {
        chrect = prect;
        chrect.origin.x += halfdx;
        chrect.size.width = halfdx;
        str = [[NSString alloc] initWithCharacters:&(info.voiced) length:1L];
        (void)TRRenderText(_ctx, chrect, (CFStringRef)str, (CFStringRef)_preferredFont, fontSize, TRSubstituteFallbackBehavior, baseline);
        pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                             (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                              chrect.size.width/_rect.size.width,
                              chrect.size.height/_rect.size.height);
        [_xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
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
  [_xml appendString:@"</array>\n</plist>\n"];
}

// data is an array of columns
// columns are arrays of strings
-(void)makeColumnarMap
{
  CGPDFContextBeginPage(_ctx, NULL);
  CGContextSetLineJoin(_ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGContextSetRGBFillColor(_ctx, 0.0f, 0.0f, 0.0f, 1.0f);
  CGRect r = _rect;
  CGRectInset(r, _margin, _margin);
  NSUInteger cols = [_data count];
  NSUInteger rows = 1;
  NSEnumerator* enu = [_data objectEnumerator];
  NSArray* subarray;
  while ((subarray = [enu nextObject]))
  {
    if ([subarray count] > rows) rows = [subarray count];
  }
  if (rows < 6) rows = 6;
  if (_drawLines) CGContextStrokeRect(_ctx,r);
  CGFloat dx = r.size.width/cols;
  CGFloat dy = r.size.height/rows;
  NSUInteger row, col;
  if (_drawLines) 
  {
    // Draw the horizontal lines
    CGContextBeginPath(_ctx);
    for (row = 1; row < rows; row++)
    {
      CGFloat y = r.origin.y+(row*dy);
      CGContextMoveToPoint(_ctx, r.origin.x, y);
      CGContextAddLineToPoint(_ctx, r.origin.x + r.size.width, y);
    }
    CGContextStrokePath(_ctx);
    // Draw the vertical lines
    CGContextBeginPath(_ctx);
    for (col = 1; col < cols; col++)
    {
      CGFloat x = r.origin.x+(col*dx);
      CGContextMoveToPoint(_ctx, x, r.origin.y);
      CGContextAddLineToPoint(_ctx, x, r.origin.y+r.size.height);
    }
    CGContextStrokePath(_ctx);
  }
  CGRect chrect = CGRectMake(0.0f,0.0f,dx,dy);
  CGFloat baseline = 0.0;
  CGFloat fontSize = 200.0f;
  NSArray* colArray;
  NSEnumerator* strEnumerator;
  NSString* str;
  NSEnumerator* colEnumerator = [_data objectEnumerator];
  while ((colArray = [colEnumerator nextObject]))
  {
    strEnumerator = [colArray objectEnumerator];
    while ((str = [strEnumerator nextObject]))
    {
      unichar chr = [str characterAtIndex:0L];
      NSString* toDraw = nil;
      if (NeedsPlaceholder(chr))
        toDraw = [[NSString alloc] initWithFormat:@"%C%@", PlaceholderDottedCircle, str];
      else toDraw = [str retain];
      CGFloat strSize;
      (void)TRGetBestFontSize(_ctx, chrect, (CFStringRef)toDraw, (CFStringRef)_preferredFont, TRSubstituteFallbackBehavior, &strSize, &baseline);
      if (strSize < fontSize) fontSize = strSize;
      [toDraw release];
    }
  }
  colEnumerator = [_data objectEnumerator];
  col = 0;
  NSRect pctRect;
  while ((colArray = [colEnumerator nextObject]))
  {
    chrect.origin.x = r.origin.x + (col*dx);
    row = 0;
    strEnumerator = [colArray objectEnumerator];
    while ((str = [strEnumerator nextObject]))
    {
      if (![str length]) continue;
      unichar chr = [str characterAtIndex:0L];
      NSString* toDraw = nil;
      if (NeedsPlaceholder(chr))
        toDraw = [[NSString alloc] initWithFormat:@"%C%@", PlaceholderDottedCircle, str];
      else toDraw = [str retain];
      chrect.origin.y = r.origin.y + ((rows-row-1)*dy);
      /*OSStatus err =*/ TRRenderText(_ctx, chrect, (CFStringRef)toDraw, (CFStringRef)_preferredFont, fontSize, TRSubstituteFallbackBehavior, baseline);
      //NSLog(@"%@ in %@ at %f baseline %f (%d)", toDraw, NSStringFromRect(*(NSRect*)&chrect), fontSize, baseline, err);
      pctRect = NSMakeRect((chrect.origin.x-_rect.origin.x)/_rect.size.width,
                           (chrect.origin.y-_rect.origin.y)/_rect.size.height,
                            chrect.size.width/_rect.size.width,
                            chrect.size.height/_rect.size.height);
      [_xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
      [_xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      [toDraw release];
      row++;
    }
    col++;
  }
  [_xml appendString:@"</array>\n</plist>\n"];
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
