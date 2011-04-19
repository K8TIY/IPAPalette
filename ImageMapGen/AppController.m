/*
Copyright © 2005-2009 Brian S. Hall

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
#import "AppController.h"
#import "Placeholder.h"
#include <CoreFoundation/CFDictionary.h>

@interface AppController (Private)
-(void)genPDFInDirectory:(NSString*)dir;
-(void)makeConsonantChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir;
-(void)makeVowelChartWithXML:(NSMutableString*)xml withFrame:(BOOL)frame inDirectory:(NSString*)dir;
-(void)makeSupraToneChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir;
-(void)makeDiacriticChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir;
-(void)makeOtherChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir;
-(void)makeExtIPAChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir;
-(void)drawString:(NSString*)str inRect:(CGRect)r
       inContext:(void*)ctx atSize:(double)size;
@end


typedef struct
{
  unichar voiceless;
  unichar voiced;
  // 0 if both possible, 1 if voiced impossible, (2 if voiceless), 3 if both
  int possibility;
} ConsInfo;

typedef struct
{
  unichar unrounded;
  unichar rounded;
  double x;
  double y;
} VowInfo;

#define kImgHeight   (256.0)
@implementation AppController
-(void)awakeFromNib
{
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  [panel setMessage:@"Choose a directory to save the PDF and data files"];
  [panel setCanChooseFiles:NO];
  [panel setCanChooseDirectories:YES];
  NSInteger result = [panel runModal];
  if (result == NSOKButton)
  {
    [_window makeKeyAndOrderFront:self];
    NSString* dir = [panel filename];
    [_spinny setIndeterminate:YES];
    [_spinny startAnimation:self];
    [self genPDFInDirectory:dir];
    [_spinny stopAnimation:self];
    [_spinny removeFromSuperview];
    [_info setStringValue:@"All done!"];
  }
  else [NSApp terminate:self];
}

-(void)genPDFInDirectory:(NSString*)dir
{
  NSMutableString* xml = [[NSMutableString alloc] initWithString:
    @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
  [xml appendString:
    @"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"\n"];
  [xml appendString:@"  \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"];
  [xml appendString:@"<plist version=\"1.0\">\n<array>"];
  [self makeConsonantChartWithXML:xml inDirectory:dir];
  [self makeVowelChartWithXML:xml withFrame:YES inDirectory:dir];
  [self makeVowelChartWithXML:nil withFrame:NO inDirectory:dir];
  [self makeSupraToneChartWithXML:xml inDirectory:dir];
  [self makeDiacriticChartWithXML:xml inDirectory:dir];
  [self makeOtherChartWithXML:xml inDirectory:dir];
  [self makeExtIPAChartWithXML:xml inDirectory:dir];
  [xml appendString:@"</array>\n</plist>\n"];
  NSString* path = [dir stringByAppendingPathComponent:@"MapData.plist"];
  NSURL* url = [NSURL fileURLWithPath:path];
  NSData* data = [xml dataUsingEncoding:NSUTF8StringEncoding];
  [data writeToURL:url atomically:YES];
  [xml release];
}


#define kConsonantWidthPerHeight (2.90)
#define kConsonantMargin         (2.0)
#define kFontSize                (22.0)
-(void)makeConsonantChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir
{
  [xml appendString:@"\n\n\n<!-- BEGIN (PULMONIC) CONSONANT DATA -->\n"];
  double width = kConsonantWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kConsonantMargin), kImgHeight+(2.0*kConsonantMargin));
  NSString* path = [dir stringByAppendingPathComponent:@"Cons.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGRect r = CGRectInset(imgRect,kConsonantMargin,kConsonantMargin);
  // These are the dimensions of a box containing a voicing pair
  double dy = r.size.height/8.0;
  double dx = r.size.width/11.0;
  double halfdx = 0.5*dx;
  //double halfdy = 0.5*dy;
  unsigned row, col;
  ConsInfo cinfo[8][11] =
  {
    {{'p','b',0},{0,0,0},{0,0,0},{'t','d',0},{0,0,0},{0x0288,0x0256,0},
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
    double y2 = r.origin.y+r.size.height-(row*dy);
    double y1 = y2 - dy;
    for (col = 0; col < 11; col++)
    {
      double x1 = r.origin.x+(col*dx);
      //double x2 = x1 + dx;
      //NSLog(@"y1 %f y2 %f x1 %f x2 %f", y1, y2, x1, x2);
      ConsInfo info = cinfo[row][col];
      CGRect prect = CGRectMake(x1,y1,dx,dy);
      CGRect chrect = prect;
      if (info.possibility > 0)
      {
        if (info.possibility == 1) chrect.origin.x += halfdx;
        if (info.possibility < 3) chrect.size.width = halfdx;
        CGContextSetRGBFillColor(ctx,0.78,0.78,0.78,1.0);
        CGContextFillRect(ctx, chrect);
        if (info.possibility < 3)
        {
          CGContextBeginPath(ctx);
          CGContextMoveToPoint(ctx,x1+halfdx,y1);
          CGContextAddLineToPoint(ctx,x1+halfdx,y2);
          CGContextStrokePath(ctx);
        }
      }
      NSString* str;
      NSRect pctRect;
      if (info.voiceless != 0)
      {
        chrect = prect;
        chrect.size.width = halfdx;
        str = [[NSString alloc] initWithCharacters:&(info.voiceless) length:1];
        [self drawString:str inRect:chrect inContext:ctx atSize:kFontSize];
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
        [xml appendString:@"  <key>chart</key> <string>consonant</string>\n"];
        [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
      if (info.voiced != 0)
      {
        chrect = prect;
        chrect.origin.x += halfdx;
        chrect.size.width = halfdx;
        str = [[NSString alloc] initWithCharacters:&(info.voiced) length:1];
        [self drawString:str inRect:chrect inContext:ctx atSize:kFontSize];
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
        [xml appendString:@"  <key>chart</key> <string>consonant</string>\n"];
        [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        [str release];
      }
    }
  }
  // Enclose chart
  CGContextStrokeRect(ctx, r);
  // Put horizontal lines
  CGContextBeginPath(ctx);
  // Draw the horizontal lines
  for (row = 1; row < 8; row++)
  {
    double y = r.origin.y+(row*dy);
    CGContextMoveToPoint(ctx, r.origin.x, y);
    CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(ctx);
  // Draw the vertical lines
  CGContextBeginPath(ctx);
  for (col = 1; col < 11; col++)
  {
    double x = r.origin.x+(col*dx);
    if (col < 3 || col > 4)
    {
      CGContextMoveToPoint(ctx, x, r.origin.y);
      CGContextAddLineToPoint(ctx, x, r.origin.y+r.size.height);
    }
    else
    {
      CGContextMoveToPoint(ctx, x, r.origin.y+(dy*4));
      CGContextAddLineToPoint(ctx, x, r.origin.y+(dy*3));
    }
  }
  CGContextStrokePath(ctx);
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

#define kVowelWidthPerHeight (1.46)
#define kVowelQuadWidth (287.0)
#define kVowelQuadHeight (218.0)
#define kVowelQuadOverhang (148.0)
#define kVowelDotSize (9.0)
#define kVowelFontSize (30.0)
#define VowelDebug 0
// If not frame, this is the dragging-source-only supplementary image.
// Nothing is done to XML, and lines/dots are not drawn
-(void)makeVowelChartWithXML:(NSMutableString*)xml withFrame:(BOOL)frame inDirectory:(NSString*)dir
{
  if (frame) [xml appendString:@"\n\n\n<!-- BEGIN VOWEL DATA -->\n"];
  double width = kVowelWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width, kImgHeight);
  NSString* path = [dir stringByAppendingPathComponent:(frame)? @"Vow.pdf":@"VowDrag.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
#if VowelDebug
  CGContextStrokeRect(ctx, imgRect);
#endif
  // The rectangle enclosing the vowel quad
  CGRect vrect = CGRectMake(0, 0, kVowelQuadWidth, kVowelQuadHeight);
  // Center it in the PDF and draw
  vrect.origin.x = imgRect.origin.x + ((imgRect.size.width-vrect.size.width)*0.5);
  vrect.origin.y = imgRect.origin.y + ((imgRect.size.height-vrect.size.height)*0.5);
  //NSLog(@"vrect at %f,%f  %f,%f", vrect.origin.x, vrect.origin.y, vrect.size.width, vrect.size.height);
  if (frame)
  {
    CGContextBeginPath(ctx);
    // Stroke the left and right sort-of verticals
    CGContextMoveToPoint(ctx, vrect.origin.x+kVowelQuadOverhang, vrect.origin.y);
    CGContextAddLineToPoint(ctx, vrect.origin.x, vrect.origin.y+vrect.size.height);
  #if VowelDebug
    CGContextAddLineToPoint(ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
  #endif
    CGContextMoveToPoint(ctx, vrect.origin.x+vrect.size.width, vrect.origin.y+vrect.size.height);
    CGContextAddLineToPoint(ctx, vrect.origin.x+vrect.size.width, vrect.origin.y);
  #if VowelDebug
    CGContextAddLineToPoint(ctx, vrect.origin.x+kVowelQuadOverhang, vrect.origin.y);
  #endif
    CGContextStrokePath(ctx);
  }
  double dy = vrect.size.height/3.0;
  unsigned row, col;
  // Draw dots top to bottom
  for (row = 0; row < 4; row++)
  {
    if (!frame) break;
    double y = vrect.origin.y + ((3-row)*dy);
    double indent = kVowelQuadOverhang * ((double)row/3.0);
    double xstart = vrect.origin.x + indent;
    double dx = (vrect.size.width - indent)/2.0;
    double x = xstart;
    //NSLog(@"row %d: indent %f dx %f x %f y %f", row, indent, dx, x, y);
  #if VowelDebug
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, xstart, y);
    CGContextAddLineToPoint(ctx, vrect.origin.x + vrect.size.width, y);
    CGContextStrokePath(ctx);
  #endif
    for (col = 0; col < 3; col++)
    {
      if (row < 3 || col != 1)
      {
        CGRect dot = CGRectMake(x-(kVowelDotSize*0.5),y-(kVowelDotSize*0.5),kVowelDotSize,kVowelDotSize);
        //NSLog(@"  col %d: dot at %f,%f", col, dot.origin.x, dot.origin.y);
        CGContextFillEllipseInRect(ctx, dot);
      }
      x += dx;
    }
  }
#if VowelDebug
  // Middle column
  CGContextBeginPath(ctx);
  CGContextMoveToPoint(ctx, vrect.origin.x + (vrect.size.width/2.0), vrect.origin.y+vrect.size.height);
  CGContextAddLineToPoint(ctx, vrect.origin.x + kVowelQuadOverhang + ((vrect.size.width-kVowelQuadOverhang)/2.0), vrect.origin.y);
  CGContextStrokePath(ctx);
#endif
  CGRect prect = CGRectMake(0.0,0.0,kVowelQuadWidth/4.0,kVowelQuadHeight/6.0);
  // The zero for both vowels is a sentinel
  VowInfo vinfo[] = {
    {'i','y',0.02,0.86},{0x0268,0x0289,0.405,0.86},{0x026F,'u',0.79,0.86},
    {0x026A,0x028F,0.20,0.72},{1,0x028A,0.62,0.72},
    {'e',0x00F8,0.15,0.58},{0x0258,0x0275,0.47,0.58},{0x0264,'o',0.79,0.58},
    {0x0259,0,0.50,0.44},
    {0x025B,0x0153,0.285,0.299},{0x025C,0x025E,0.535,0.299},{0x028C,0x0254,0.79,0.299},
    {0x00E6,1,0.35,0.156},{0x0250,0,0.56,0.156},
    {0x025A,0x025D,0.02,0.01},{'a',0x0276,0.418,0.01},{0x0251,0x0252,0.79,0.01},
    {0,0,0.0,0.0}
  };
  unsigned i = 0;
  while (YES)
  {
    VowInfo info = vinfo[i];
    if (info.unrounded == 0 && info.rounded == 0) break;
    CGRect chrect;
    prect.origin.x = imgRect.origin.x + (info.x * imgRect.size.width);
    prect.origin.y = imgRect.origin.y + (info.y * imgRect.size.height);
    NSString* str;
    NSRect pctRect;
    //CGContextStrokeRect(ctx,prect);
    if (info.unrounded != 0)
    {
      chrect = prect;
      if (info.rounded != 0) chrect.size.width *= 0.5;
    #if VowelDebug
      CGContextStrokeRect(ctx,chrect);
    #endif
      if (info.unrounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.rounded == 0)
        {
          chrect.size.width *= 0.5;
          chrect.origin.x += (chrect.size.width * 0.5);
        }
        str = [[NSString alloc] initWithCharacters:&(info.unrounded) length:1];
        [self drawString:str inRect:chrect inContext:ctx atSize:kVowelFontSize];
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        if (frame)
        {
          [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
          [xml appendString:@"  <key>chart</key> <string>vowel</string>\n"];
          [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        }
        [str release];
      }
    }
    if (info.rounded != 0)
    {
      chrect = prect;
      if (info.unrounded != 0)
      {
        chrect.size.width *= 0.5;
        chrect.origin.x += chrect.size.width;
      }
    #if VowelDebug
      CGContextStrokeRect(ctx,chrect);
    #endif
      if (info.rounded != 1)
      {
        // If the other is zero, contract the tracking rect to standard size
        if (info.unrounded == 0)
        {
          chrect.size.width *= 0.5;
          chrect.origin.x += (chrect.size.width * 0.5);
        }
        str = [[NSString alloc] initWithCharacters:&(info.rounded) length:1];
        [self drawString:str inRect:chrect inContext:ctx atSize:kVowelFontSize];
        pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                             (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                              chrect.size.width/imgRect.size.width,
                              chrect.size.height/imgRect.size.height);
        if (frame)
        {
          [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", str];
          [xml appendString:@"  <key>chart</key> <string>vowel</string>\n"];
          [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
        }
        [str release];
      }
    }
    i++;
  }
  CGPoint frags[] = {
    // Horizontal
    {0.22,0.925},{0.41,0.925}, {0.60,0.925},{0.79,0.925},
    {0.34,0.64},{0.48,0.64},   {0.66,0.64},{0.79,0.64},
    {0.47,0.36},{0.545,0.36},  {0.72,0.36},{0.79,0.36},
                {0.61,0.075},  {0.79,0.075},
    // Vertical
    {0.50,0.925},{0.59,0.545},
    {0.61,0.45},{0.65,0.28},
    {0.675,0.17},{0.695,0.075},
    //Sentinel
    {0.0,0.0},{0.0,0.0}
  };
#if VowelDebug
  CGContextSetRGBStrokeColor(ctx,1.0,0.0,0.0,1.0);
#endif
  CGContextBeginPath(ctx);
  i = 0;
  while (YES && frame)
  {
    CGPoint p1 = frags[i];
    if (p1.x == 0.0 && p1.y == 0.0) break;
    p1.x = imgRect.origin.x + (p1.x * imgRect.size.width);
    p1.y = imgRect.origin.y + (p1.y * imgRect.size.height);
    CGPoint p2 = frags[i+1];
    CGContextMoveToPoint(ctx,p1.x,p1.y);
    p2.x = imgRect.origin.x + (p2.x * imgRect.size.width);
    p2.y = imgRect.origin.y + (p2.y * imgRect.size.height);
    CGContextAddLineToPoint(ctx,p2.x,p2.y);
    i += 2;
  }
  CGContextStrokePath(ctx);
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

#define kSupraToneWidthPerHeight (0.8)
#define kSupraToneMargin (0.0)
#define kSupraToneFontSize (28.0)
#define kDottedCircle (0x25CC)
#define SupraToneDrawLines 0
-(void)makeSupraToneChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir
{
  double width = kSupraToneWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kSupraToneMargin), kImgHeight+(2.0*kSupraToneMargin));
  NSString* path = [dir stringByAppendingPathComponent:@"SupraTone.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGRect r = imgRect;
#if SupraToneDrawLines
  r = CGRectInset(r,kSupraToneMargin,kSupraToneMargin);
  CGContextStrokeRect(ctx,r);
#endif
  double dx = r.size.width/4.0;
  double dy = r.size.height/8.0;
  unsigned row, col;
#if SupraToneDrawLines
  // Draw the horizontal lines
  CGContextBeginPath(ctx);
  for (row = 1; row < 8; row++)
  {
    double y = r.origin.y+(row*dy);
    CGContextMoveToPoint(ctx, r.origin.x, y);
    CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(ctx);
#endif
#if SupraToneDrawLines
  // Draw the vertical lines
  CGContextBeginPath(ctx);
  for (col = 1; col < 4; col++)
  {
    double x = r.origin.x+(col*dx);
    CGContextMoveToPoint(ctx, x, r.origin.y);
    CGContextAddLineToPoint(ctx, x, r.origin.y+r.size.height);
  }
  CGContextStrokePath(ctx);
#endif
  CGRect chrect = CGRectMake(0.0,0.0,dx,dy);
  unichar supratones[4][8] = {
    {0x030B,0x0301,0x0304,0x0300,0x030F,0xA71B,0xA71C,0},
    {0x02E5,0x02E6,0x02E7,0x02E8,0x02E9,0x2197,0x2198,0},
    {0x030C,0x0302,0x1DC4,0x1DC5,0x1DC8,0x1DC6,0x1DC7,0x1DC9},
    {0x02C8,0x02CC,0x02D0,0x02D1,0x0306,0x203F,0x007C,0x2016}
  };
  NSRect pctRect;
  for (col = 0; col < 4; col++)
  {
    chrect.origin.x = r.origin.x + (col*dx);
    for (row = 0; row < 8; row++)
    {
      unichar chr = supratones[col][row];
      if (!chr) continue;
      NSString* str;
      if (NeedsPlaceholder(chr)) str = [[NSString alloc] initWithFormat:@"%C%C", kDottedCircle,chr];
      else str = [[NSString alloc] initWithCharacters:&(chr) length:1];
      NSString* justChr = [[NSString alloc] initWithCharacters:&(chr) length:1];
      chrect.origin.y = r.origin.y + ((7-row)*dy);
      [self drawString:str inRect:chrect inContext:ctx atSize:kSupraToneFontSize];
      pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                           (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                            chrect.size.width/imgRect.size.width,
                            chrect.size.height/imgRect.size.height);
      [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", justChr];
      [xml appendString:@"  <key>chart</key> <string>supratone</string>\n"];
      [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      [str release];
      [justChr release];
    }
  }
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

#define kDiacriticWidthPerHeight (0.7)
#define kDiacriticMargin (10.0)
#define kDiacriticFontSize (28.0)
-(void)makeDiacriticChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir
{
  [xml appendString:@"\n\n\n<!-- BEGIN DIACRITIC DATA -->\n"];
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [dir stringByAppendingPathComponent:@"Diacritic.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGRect r = CGRectInset(imgRect,kSupraToneMargin,kSupraToneMargin);
#if SupraToneDrawLines
  CGContextStrokeRect(ctx,r);
#endif
  double dx = r.size.width/4.0;
  double dy = r.size.height/8.0;
  unsigned row, col;
#if SupraToneDrawLines
  // Draw the horizontal lines
  CGContextBeginPath(ctx);
  for (row = 1; row < 8; row++)
  {
    double y = r.origin.y+(row*dy);
    CGContextMoveToPoint(ctx, r.origin.x, y);
    CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(ctx);
#endif
#if SupraToneDrawLines
  // Draw the vertical lines
  CGContextBeginPath(ctx);
  for (col = 1; col < 4; col++)
  {
    double x = r.origin.x+(col*dx);
    CGContextMoveToPoint(ctx, x, r.origin.y);
    CGContextAddLineToPoint(ctx, x, r.origin.y+r.size.height);
  }
  CGContextStrokePath(ctx);
#endif
  CGRect chrect = CGRectMake(0.0,0.0,dx,dy);
  unichar diacritics[4][8] = {
    {0x0325,0x032C,0x0339,0x031C,0x031F,0x0320,0x0308,0x033D},
    {0x0329,0x032F,0x0324,0x0330,0x033C,0x02DE,0x0334,0x02BC},
    {0x031D,0x02D4,0x031E,0x02D5,0x0318,0x0319,0,0},
    {0x032A,0x033A,0x033B,0x0303,0x031A,0x0361,0x035C,0}
  };
  NSRect pctRect;
  for (col = 0; col < 4; col++)
  {
    chrect.origin.x = r.origin.x + (col*dx);
    for (row = 0; row < 8; row++)
    {
      unichar chr = diacritics[col][row];
      if (!chr) continue;
      NSString* str;
      if (NeedsPlaceholder(chr)) str = [[NSString alloc] initWithFormat:@"%C%C", kDottedCircle,chr];
      else str = [[NSString alloc] initWithCharacters:&(chr) length:1];
      NSString* justChr = [[NSString alloc] initWithCharacters:&(chr) length:1];
      chrect.origin.y = r.origin.y + ((7-row)*dy);
      [self drawString:str inRect:chrect inContext:ctx atSize:kSupraToneFontSize];
      pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                           (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                            chrect.size.width/imgRect.size.width,
                            chrect.size.height/imgRect.size.height);
      [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", justChr];
      [xml appendString:@"  <key>chart</key> <string>diacritic</string>\n"];
      [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      [str release];
      [justChr release];
    }
  }
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

-(void)makeOtherChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir
{
  [xml appendString:@"\n\n\n<!-- BEGIN OTHER DATA -->\n"];
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [dir stringByAppendingPathComponent:@"Other.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGRect r = CGRectInset(imgRect,kSupraToneMargin,kSupraToneMargin);
#if SupraToneDrawLines
  CGContextStrokeRect(ctx,r);
#endif
  double dx = r.size.width/4.0;
  double dy = r.size.height/8.0;
  unsigned row, col;
#if SupraToneDrawLines
  // Draw the horizontal lines
  CGContextBeginPath(ctx);
  for (row = 1; row < 8; row++)
  {
    double y = r.origin.y+(row*dy);
    CGContextMoveToPoint(ctx, r.origin.x, y);
    CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(ctx);
#endif
#if SupraToneDrawLines
  // Draw the vertical lines
  CGContextBeginPath(ctx);
  for (col = 1; col < 4; col++)
  {
    double x = r.origin.x+(col*dx);
    CGContextMoveToPoint(ctx, x, r.origin.y);
    CGContextAddLineToPoint(ctx, x, r.origin.y+r.size.height);
  }
  CGContextStrokePath(ctx);
#endif
  CGRect chrect = CGRectMake(0.0,0.0,dx,dy);
  unichar others[4][8] = {
    {0x0298,0x01C0,0x01C3,0x01C2,0x01C1,0,0,0},
    {0x0253,0x0257,0x0284,0x0260,0x029B,0,0,0},
    {0x028D,0x0077,0x0265,0x029C,0x02A2,0x02A1,0,0},
    {0x0255,0x0291,0x027A,0x0267,0,0,0,0}
  };
  NSRect pctRect;
  for (col = 0; col < 4; col++)
  {
    chrect.origin.x = r.origin.x + (col*dx);
    for (row = 0; row < 8; row++)
    {
      unichar chr = others[col][row];
      if (!chr) continue;
      NSString* str;
      if (NeedsPlaceholder(chr)) str = [[NSString alloc] initWithFormat:@"%C%C", kDottedCircle,chr];
      else str = [[NSString alloc] initWithCharacters:&(chr) length:1];
      NSString* justChr = [[NSString alloc] initWithCharacters:&(chr) length:1];
      chrect.origin.y = r.origin.y + ((7-row)*dy);
      [self drawString:str inRect:chrect inContext:ctx atSize:kSupraToneFontSize];
      pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                           (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                            chrect.size.width/imgRect.size.width,
                            chrect.size.height/imgRect.size.height);
      [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", justChr];
      [xml appendString:@"  <key>chart</key> <string>other</string>\n"];
      [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      [str release];
      [justChr release];
    }
  }
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

-(void)makeExtIPAChartWithXML:(NSMutableString*)xml inDirectory:(NSString*)dir
{
  [xml appendString:@"\n\n\n<!-- BEGIN EXTIPA DATA -->\n"];
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [dir stringByAppendingPathComponent:@"ExtIPA.pdf"];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  CGPDFContextBeginPage(ctx, NULL);
  CGContextSetLineJoin(ctx, kCGLineJoinMiter);
  CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0);
  CGRect r = CGRectInset(imgRect,kSupraToneMargin,kSupraToneMargin);
#if SupraToneDrawLines
  CGContextStrokeRect(ctx,r);
#endif
  double dx = r.size.width/5.0;
  double dy = r.size.height/8.0;
  unsigned row, col;
#if SupraToneDrawLines
  // Draw the horizontal lines
  CGContextBeginPath(ctx);
  for (row = 1; row < 8; row++)
  {
    double y = r.origin.y+(row*dy);
    CGContextMoveToPoint(ctx, r.origin.x, y);
    CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, y);
  }
  CGContextStrokePath(ctx);
#endif
#if SupraToneDrawLines
  // Draw the vertical lines
  CGContextBeginPath(ctx);
  for (col = 1; col < 5; col++)
  {
    double x = r.origin.x+(col*dx);
    CGContextMoveToPoint(ctx, x, r.origin.y);
    CGContextAddLineToPoint(ctx, x, r.origin.y+r.size.height);
  }
  CGContextStrokePath(ctx);
#endif
  CGRect chrect = CGRectMake(0.0,0.0,dx,dy);
  unichar extipas[5][8] = {
    // 0xFFFE is a placeholder for the two-character cluck-click symbol
    // 0xFFFF is a placeholder for the two-character interdental/bidental symbol
    {0x02AC,0x02AD,0x02AA,0x02AB,0x02A9,0x00A1,0xFFFE,0x203C},
    {0x034D,0x0346,0xFFFF,0x0348,0x0349,0x034E,0x34A,0x34B},
    {0x034C,0x0347,0x0362,0x0354,0x0355,0,0,0},
    {0x02ED,0x208D,0x208E,0x02EC,0x2191,0x2193,0,0},
    {0x0152,0x042E,0x0418,0x0398,0x0323,0x274D,0,0}
  };
  NSRect pctRect;
  for (col = 0; col < 5; col++)
  {
    chrect.origin.x = r.origin.x + (col*dx);
    for (row = 0; row < 8; row++)
    {
      unichar chr = extipas[col][row];
      if (!chr) continue;
      NSString* str;
      NSString* justChr = nil;
      if (chr == 0xFFFE)
      {
        str = [[NSString alloc] initWithFormat:@"%C%C", 0x01C3, 0x00A1];
      }
      else if (chr == 0xFFFF)
      {
        str = [[NSString alloc] initWithFormat:@"%C%C%C", kDottedCircle, 0x0346, 0x032A];
        justChr = [[NSString alloc] initWithFormat:@"%C%C", 0x0346, 0x032A];
      }
      else if (NeedsPlaceholder(chr))
      {
        str = [[NSString alloc] initWithFormat:@"%C%C", kDottedCircle, chr];
        justChr = [[NSString alloc] initWithCharacters:&(chr) length:1];
      }
      else
      {
        str = [[NSString alloc] initWithCharacters:&(chr) length:1];
      }
      if (!justChr) justChr = [str copy];
      chrect.origin.y = r.origin.y + ((7-row)*dy);
      [self drawString:str inRect:chrect inContext:ctx atSize:kSupraToneFontSize];
      pctRect = NSMakeRect((chrect.origin.x-imgRect.origin.x)/imgRect.size.width,
                           (chrect.origin.y-imgRect.origin.y)/imgRect.size.height,
                            chrect.size.width/imgRect.size.width,
                            chrect.size.height/imgRect.size.height);
      [xml appendFormat:@"<dict><key>char</key> <string>%@</string>\n", justChr];
      [xml appendString:@"  <key>chart</key> <string>extipa</string>\n"];
      [xml appendFormat:@"  <key>rect</key> <string>%@</string>\n</dict>\n", NSStringFromRect(pctRect)];
      [str release];
      [justChr release];
    }
  }
  CGPDFContextEndPage(ctx);
  CGContextRelease(ctx);
}

#if 0
-(void)drawString:(NSString*)str inRect:(CGRect)r inContext:(void*)ctx atSize:(double)size
{
  CTFontDescriptorRef fdesc = CTFontDescriptorCreateWithNameAndSize(CFSTR("Doulos SIL"), size);
  CTFontRef font = CTFontCreateWithFontDescriptor(fdesc, size, NULL);
  CFRelease(fdesc);
  NSDictionary* attrs = [[NSDictionary alloc] initWithObjectsAndKeys:(id)font, kCTFontAttributeName, NULL];
  CFRelease(font);
  CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)str, (CFDictionaryRef)attrs);
  CFRelease(attrs);
  CTLineRef line = CTLineCreateWithAttributedString(attrString);
  CGRect bounds = CTLineGetImageBounds(line, ctx);
  CGFloat x = r.origin.x + (r.size.width/2.0) - (bounds.size.width/2.0);
  // Fixme: this is wrong. It should be a constant baseline based on descent.
  CGFloat y = r.origin.y + (r.size.height/2.0) - (bounds.size.height/2.0);
  CGContextSetTextPosition(ctx, x, y);
  CTLineDraw(line, ctx);
  CFRelease(line);
}
#else
#define kNudgeUp (2.0)
-(void)drawString:(NSString*)str inRect:(CGRect)r inContext:(void*)ctx atSize:(double)size
{
	ATSUTextLayout				  layout;
  UniCharArrayOffset		  layoutStart, currentStart, currentEnd;
	UniCharCount				    layoutLength;
  ByteCount					      sizes[2];
  ATSUAttributeValuePtr		values[2];
	Fixed						        lineWidth;
  ItemCount					      nsb;
  UniCharArrayOffset*     sbs;
	int							        j;

  //NSLog(@"drawing '%@' in %@", str, NSStringFromRect(*(NSRect*)&r));
  ATSUFontID fid;
  ATSUStyle style;
  OSStatus err;
  ATSUAttributeTag tags[2] = {kATSUFontTag,kATSUSizeTag};
  ByteCount counts[2] = {sizeof(ATSUFontID),sizeof(Fixed)};
  ATSUAttributeValuePtr vals[2];
  Fixed fsiz = FloatToFixed(size);
  const char* fname = "Doulos SIL";
  err = ATSUFindFontFromName(fname, strlen(fname), kFontFullName,
        kFontNoPlatformCode, kFontNoScriptCode, kFontNoLanguage, &fid);
  if (err) NSLog(@"%d ATSUFindFontFromName", err);
  err = ATSUCreateStyle(&style);
  if (err) NSLog(@"%d ATSUCreateStyle", err);
  vals[0] = &fid;
  vals[1] = &fsiz;
  err = ATSUSetAttributes(style, 2, tags, counts, vals);
  if (err) NSLog(@"%d ATSUSetAttributes", err);
  CFIndex slen = CFStringGetLength((CFStringRef)str);
  CFRange range = CFRangeMake(0,slen);
  unichar* buff = malloc(slen*sizeof(unichar));
  CFStringGetCharacters((CFStringRef)str, range, buff);
  err = ATSUCreateTextLayoutWithTextPtr(buff,0,slen,slen,1,(UInt32*)&slen,&style,&layout);
  if (err) NSLog(@"%d ATSUCreateTextLayoutWithTextPtr", err);
  err = ATSUSetTransientFontMatching(layout, true);
  if (err) NSLog(@"%d ATSUSetTransientFontMatching", err);
  lineWidth = X2Fix(r.size.width);
	// In this example, we are breaking text into lines.
  // Therefore, we need to make sure the layout knows the width of the line.
  tags[0] = kATSULineWidthTag;
  sizes[0] = sizeof(Fixed);
  values[0] = &lineWidth;
  verify_noerr( ATSUSetLayoutControls(layout, 1, tags, sizes, values) );
  // Make sure the layout knows the proper CGContext to use for drawing
  tags[0] = kATSUCGContextTag;
  sizes[0] = sizeof(CGContextRef);
  values[0] = &ctx;
  verify_noerr(ATSUSetLayoutControls(layout, 1, tags, sizes, values) );
  // Find out about this layout's text buffer
  verify_noerr(ATSUGetTextLocation(layout, NULL, NULL, &layoutStart, &layoutLength, NULL) );
  //NSLog(@"layout %lu length %lu", layoutStart, layoutLength);
  verify_noerr(ATSUBatchBreakLines(layout, layoutStart, layoutLength, lineWidth, &nsb) );
  // Obtain a list of all the line break positions
  verify_noerr(ATSUGetSoftLineBreaks(layout, layoutStart, layoutLength, 0, NULL, &nsb) );
  sbs = (UniCharArrayOffset*) malloc(nsb * sizeof(UniCharArrayOffset));
  verify_noerr(ATSUGetSoftLineBreaks(layout, layoutStart, layoutLength, nsb, sbs, &nsb));
  CGContextSetRGBFillColor(ctx,0.0,0.0,0.0,1.0);
  // Loop over all the lines and draw them
  currentStart = layoutStart;
  for (j=0; j <= nsb; j++)
  {
    currentEnd = ((nsb > 0) && (nsb > j)) ? sbs[j] : layoutStart + layoutLength;
    ATSUTextMeasurement before, after, asc, desc;
    err = ATSUGetUnjustifiedBounds(layout,currentStart,currentEnd - currentStart,&before,&after,&asc,&desc);
    if (err) NSLog(@"%d ATSUGetUnjustifiedBounds", err);
    double x = r.origin.x;
    double y = r.origin.y;
    //NSLog(@"%@: %f %f %f %f", str, FixedToFloat(before), FixedToFloat(after), FixedToFloat(asc), FixedToFloat(desc));
    double txheight = FixedToFloat(asc) + FixedToFloat(desc);
    double txwidth = FixedToFloat(before) + FixedToFloat(after);
    x += ((r.size.width - txwidth) / 2.0);
    //NSLog(@"r.size.height %f txheight %f", r.size.height, txheight);
    //NSLog(@"y %f from %f and bump %f", y - ((r.size.height - txheight) / 2.0), y, ((r.size.height - txheight) / 2.0));
    y += ((r.size.height - txheight) / 2.0);
    y += FixedToFloat(desc);
    //y += kNudgeUp;
    // Draw the text
    verify_noerr( ATSUDrawText(layout, currentStart, currentEnd - currentStart, X2Fix(x), X2Fix(y)) );
    //NSLog(@"-- drawing %lu to %lu at %f,%f", currentStart, currentEnd - currentStart, x, y);
    // Prepare for next line
    currentStart = currentEnd;
  }
  free(sbs);
  ATSUDisposeStyle(style);
  ATSUDisposeTextLayout(layout);
}
#endif
@end
