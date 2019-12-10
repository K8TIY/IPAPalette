/*
Copyright © 2005-2012 Brian S. Hall

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


