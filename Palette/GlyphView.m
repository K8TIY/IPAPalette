#import "GlyphView.h"
#import <Carbon/Carbon.h>
#import "Onizuka.h"
#import "NSApplication+DarkMode.h"

/* Note: in order to work around a Core Text cacheing bug in Snow Leopard,
   the TextRenderer routines must work on a copy of our mutable string,
   because it uses the object itself as a key into the font name -> info
   cache(s).

   In a sense, Core Text was saying, "Oh, I see your string (which currently
   holds the value 'Doulos SIL') was previously used to ask for this font
   'Everson Mono', here you go!"
   
   Not fun.
*/
@interface GlyphView (Private)
-(void)_coreInit;
-(void)_drawWarning;
-(void)_setupFontWithFrame:(NSRect)r;
@end

@implementation GlyphView
static const CGFloat GlyphViewBevelInset = 8.0L;
-(id)initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  [self _coreInit];
  return self;
}

-(id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self _coreInit];
  return self;
}

-(void)_coreInit
{
  _font = [[NSMutableString alloc] init];
  _stringValue = [[NSMutableString alloc] init];
  _setup = NO;
}

-(void)dealloc
{
  [_font release];
  [_stringValue release];
  [super dealloc];
}

-(void)drawRect:(NSRect)r
{
  [super drawRect:r];
  if (!_setup)
  {
    [self _setupFontWithFrame:[self bounds]];
    _setup = YES;
  }
  if ([_stringValue length] && [_font length])
  {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    if (!ctx) return;
    NSRect bounds = [self bounds];
    r = NSInsetRect(bounds, GlyphViewBevelInset, GlyphViewBevelInset);
    CGRect cgr = CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height);
    CGContextClipToRect(ctx, cgr);
    if ([NSApplication isDarkMode]) CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
    else CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
    NSString* tmp = [_font copy];
    OSStatus err = TRRenderText(ctx, cgr, (CFStringRef)_stringValue,
                                (CFStringRef)tmp, _fontSize,
                                _fallbackBehavior, _baseline);
    [tmp release];
    if (err == kATSUFontsNotMatched) [self _drawWarning];
  }
}

-(void)setFrame:(NSRect)r
{
  [super setFrame:r];
  _setup = NO;
}

-(void)setFrameSize:(NSSize)sz
{
  [super setFrameSize:sz];
  _setup = NO;
}

#pragma mark API
-(void)setStringValue:(NSString*)str
{
  if (!str || ![_stringValue isEqualToString:str])
  {
    [_stringValue setString:(str)? str:@""];
    [self setNeedsDisplay:YES];
  }
}

-(void)setFont:(NSString*)font
{
  if (!font || ![_font isEqualToString:font])
  {
    [_font setString:font];
    [self setNeedsDisplay:YES];
  }
}

-(void)setFallbackBehavior:(uint8_t)flag
{
  if (_fallbackBehavior != flag)
  {
    _fallbackBehavior = flag;
    [self setNeedsDisplay:YES];
  }
}

#pragma mark Private
-(void)_drawWarning
{
  NSRect r = [self bounds];
  NSString* typeStr = NSFileTypeForHFSTypeCode(kAlertCautionIcon);
  NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType:typeStr];
  CGFloat delta = 1.0L;
  NSPoint iconWhere, textWhere;
  NSSize iconSize = [icon size];
  if (_fallbackBehavior == GlyphViewWarningOnly)
  {
    iconWhere = NSMakePoint(r.origin.x + ((r.size.width - iconSize.width)/2.0L),
                            r.origin.y + ((r.size.height - iconSize.height)/2.0L));
    textWhere = NSMakePoint(r.origin.x+10.0L, r.origin.y+10.0L);
  }
  else
  {
    delta = 0.8L;
    iconWhere = NSMakePoint(r.origin.x+10.0L, r.origin.y+10.0L);
    textWhere.x = iconWhere.x+iconSize.width+2.0L;
    textWhere.y = iconWhere.y;
  }
  [icon drawAtPoint:iconWhere fromRect:NSZeroRect
        operation:NSCompositingOperationSourceOver fraction:delta];
  NSString* warning = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__FONT_WARNING__"];
  NSDictionary* attrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor],
                                              NSForegroundColorAttributeName, 
                                              [NSFont systemFontOfSize:10.0L],
                                              NSFontAttributeName, NULL];
  [warning drawAtPoint:textWhere withAttributes:attrs];
  [attrs release];
  [warning release];
}

-(void)_setupFontWithFrame:(NSRect)r
{
  NSGraphicsContext* gc = [NSGraphicsContext currentContext];
  if (!gc) return;
  CGContextRef ctx = [gc graphicsPort];
  if (!ctx) return;
  NSString* tmp = [_font copy];
  r = NSInsetRect(r, GlyphViewBevelInset, GlyphViewBevelInset);
  (void)TRGetBestFontSize(ctx, *(CGRect*)&r, CFSTR("Wj"),
                          (CFStringRef)tmp, _fallbackBehavior,
                          &_fontSize, &_baseline);
  [tmp release];
}
@end

/*
Copyright © 2005-2019 Brian S. Hall, BLUGS.COM LLC

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
