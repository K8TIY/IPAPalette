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
#import "GlyphView.h"
#import <Carbon/Carbon.h>
#import "Onizuka.h"

@interface GlyphView (Private)
-(void)_drawWarning;
-(void)_setupFontWithFrame:(NSRect)r;
@end

@implementation GlyphView
static const CGFloat GlyphViewBevelInset = 8.0L;
-(id)initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  _stringValue = [[NSMutableString alloc] init];
  return self;
}

-(id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  _stringValue = [[NSMutableString alloc] init];
  return self;
}

-(void)dealloc
{
  if (_font) [_font release];
  [_stringValue release];
  [super dealloc];
}

-(void)drawRect:(NSRect)r
{
  [super drawRect:r];
  if ([_stringValue length])
  {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    if (!ctx) return;
    NSRect bounds = [self bounds];
    r = NSInsetRect(bounds, GlyphViewBevelInset, GlyphViewBevelInset);
    CGRect cgr = CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height);
    CGContextClipToRect(ctx, cgr);
    OSStatus err = TRRenderText(ctx, cgr, (CFStringRef)_stringValue,
                                (CFStringRef)_font, _fontSize,
                                _fallbackBehavior, _baseline);
    if (err == kATSUFontsNotMatched) [self _drawWarning];
  }
}

-(void)setFrame:(NSRect)r
{
  [self _setupFontWithFrame:r];
  [super setFrame:r];
}

-(void)setFrameSize:(NSSize)sz
{
  NSRect bounds = [self bounds];
  bounds.size = sz;
  [self _setupFontWithFrame:bounds];
  [super setFrameSize:sz];
}

-(BOOL)mouseDownCanMoveWindow {return YES;}

#pragma mark API
-(void)setStringValue:(NSString*)str
{
  if (!str || ![_stringValue isEqual:str])
  {
    [_stringValue setString:(str)? str:@""];
    [self setNeedsDisplay:YES];
  }
}

-(void)setFont:(NSString*)font
{
  if (!_font) _font = [[NSMutableString alloc] initWithString:font];
  else [_font setString:font];
  [self _setupFontWithFrame:[self bounds]];
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
  [icon drawAtPoint:iconWhere fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:delta];
  NSString* warning = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__FONT_WARNING__"];
  NSDictionary* attrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor],
                                              NSForegroundColorAttributeName, 
                                              [NSFont systemFontOfSize:10.0L], NSFontAttributeName, NULL];
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
  r = NSInsetRect(r, GlyphViewBevelInset, GlyphViewBevelInset);
  (void)TRGetBestFontSize(ctx, *(CGRect*)&r, CFSTR("Wj"), (CFStringRef)_font, _fallbackBehavior, &_fontSize, &_baseline);
}
@end


