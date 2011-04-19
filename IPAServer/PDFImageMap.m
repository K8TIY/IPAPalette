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
#import "PDFImageMap.h"
#import <Carbon/Carbon.h>

@interface PDFImageMap (Private)
-(void)_coreInit;
-(void)_hover:(NSTimer*)timer;
-(void)_checkMouse;
-(NSRect)imageRect;
-(NSString*)_keyForPoint:(NSPoint)p;
-(NSRect)_rectFromKey:(NSString*)key;
-(NSRect)_centerRect:(NSRect)rect inRect:(NSRect)host;
@end

static NSUInteger local_CurrentModifiers(void);
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
static CGEventRef local_TapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon);
#endif

@implementation PDFImageMap
-(id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self _coreInit];
  return self;
}

-(id)initWithCoder:(NSCoder*)decoder
{
  self = [super initWithCoder:decoder];
  [self _coreInit];
  return self;
}

-(void)_coreInit
{
  if (!_data) _data = [[NSMutableDictionary alloc] init];
  if (!_hots) _hots = [[NSMutableDictionary alloc] init];
  if (!_lastHot) _lastHot = [[NSMutableString alloc] init];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  _tap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly,
                          CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventFlagsChanged),
                          local_TapCallback, self);
  if (_tap)
  {
    CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes);
    CFRelease(src);
    CGEventTapEnable(_tap, false);
  }
#endif
}

-(void)dealloc
{
  [self stopTracking];
  if (_dragImage) [_dragImage release];
  if (_data) [_data release];
  if (_hots) [_hots release];
  if (_lastHot) [_lastHot release];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  if (_tap) CFRelease(_tap);
#endif
  [super dealloc];
}

-(void)removeAllTrackingRects
{
  [_data removeAllObjects];
  [_hots removeAllObjects];
}

-(void)setTrackingRect:(SubRect)r forKey:(NSString*)key
{
  NSString* asStr = NSStringFromRect(r);
  [_data setObject:asStr forKey:key];
  [_hots setObject:key forKey:asStr];
}

-(void)startTracking
{
  if (_trackingRect) [self removeTrackingRect:_trackingRect];
  _trackingRect = [self addTrackingRect:[self imageRect] owner:self userData:self assumeInside:NO];
  //NSLog(@"startTracking: adding %X", _trackingRect);
}

-(void)stopTracking
{
  //NSLog(@"stopTracking: removing %X", _trackingRect);
  [self removeTrackingRect:_trackingRect];
  _trackingRect = 0;
}

-(void)resetCursorRects
{
  [self stopTracking];
  [self startTracking];
}

-(void)drawRect:(NSRect)inval
{
  if ([_lastHot length])
  {
    NSRect r = [self _rectFromKey:_lastHot];
    if (NSIntersectsRect(r,inval))
    {
      NSBezierPath* path = [NSBezierPath bezierPathWithRect:r];
      NSColor* col = [NSColor selectedControlColor];
      [col set];
      [path fill];
    }
  }
  NSImage* image = [self image];
  if (image)
  {
    NSRect bounds = [self bounds];
    NSImage* copy = [image copy];
    [copy setScalesWhenResized:YES];
    NSSize size = [copy size];
    NSPoint pt;
    CGFloat rx = bounds.size.width / size.width;
    CGFloat ry = bounds.size.height / size.height;
    CGFloat r = rx < ry ? rx : ry;
    size.width *= r;
    size.height *= r;
    [copy setSize:size];
    pt.x = (bounds.size.width - size.width) / 2.0L;
    pt.y = (bounds.size.height - size.height) / 2.0L;
    [copy compositeToPoint:pt operation:NSCompositeSourceOver];
    [copy release];
  }
}

-(BOOL)acceptsFirstMouse:(NSEvent*)evt
{
  #pragma unused (evt)
  return YES;
}

-(BOOL)acceptsFirstResponder
{
  return YES;
}

-(void)mouseDown:(NSEvent*)evt
{
  _modifiers = [evt modifierFlags];
  NSEvent* down = evt;
  BOOL wasDrag = NO;
  // Make sure stringValue gets updated
  [self _hover:nil];
  NSString* str = [self stringValue];
  NSRect r = [self _rectFromKey:_lastHot];
  while (str)
  {
    evt = [[self window] nextEventMatchingMask:NSLeftMouseDraggedMask | NSLeftMouseUpMask];
    if (evt)
    {
      if ([evt type] == NSLeftMouseUp) break;
      NSData* encoded = [str dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
      if (encoded)
      {
        NSImage* img = _dragImage;
        if (nil == img) img = [self image];
        if (img)
        {
          img = [img copy];
          NSSize imgSize = [img size];
          NSRect sourcer = NSRectFromString([_data objectForKey:str]);
          sourcer.origin.x = sourcer.origin.x * imgSize.width;
          sourcer.origin.y = sourcer.origin.y * imgSize.height;
          sourcer.size.width *= imgSize.width;
          sourcer.size.height *= imgSize.height;
          sourcer = NSInsetRect(sourcer, 1.0L, 1.0L);
          NSRect destrect = r;
          destrect.origin = NSZeroPoint;
          NSPoint dragPoint = NSMakePoint(r.origin.x, r.origin.y);
          NSImage* draggingImage = [[NSImage alloc] initWithSize:r.size];
          [draggingImage lockFocus];
          [img drawInRect:destrect fromRect:sourcer operation:NSCompositeSourceOver fraction:1.0L];
          [img release];
          [draggingImage unlockFocus];
          NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
          NSArray* types = [NSArray arrayWithObjects:NSStringPboardType, NULL];
          [pboard declareTypes:types owner:self];
          [pboard setData:encoded forType:NSStringPboardType];
          _dragging = YES;
          [self dragImage:draggingImage at:dragPoint offset:NSZeroSize
                event:evt pasteboard:pboard source:self slideBack:YES];
          [draggingImage release];
          _dragging = NO;
        }
      }
      wasDrag = YES;
      break;
    }
  }
  if (_lastHot)
  {
    [[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:down];
    if (!wasDrag)
    {
      //NSLog(@"Click on %d", _mouse);
      id target = [self target];
      SEL action = [self action];
      //NSLog(@"target %@, action %@", target, action);
      if (target && action)
      {
        [target performSelector:action withObject:self];
      }
    }
  }
}

-(NSString*)stringValue
{
  NSString* str = nil;
  if (_lastHot && _trackingRect) str = [_hots objectForKey:_lastHot];
  return str;
}

-(void)setBounds:(NSRect)bounds
{
  [super setBounds:bounds];
  [self resetCursorRects];
}

-(void)setFrame:(NSRect)frame
{
  [super setFrame:frame];
  [self resetCursorRects];
}

-(NSUInteger)modifiers {return _modifiers;}

-(id)delegate {return delegate;}

-(void)_hover:(NSTimer*)timer
{
  #pragma unused (timer)
  [self _checkMouse];
}

-(void)_checkMouse
{
  //NSLog(@"checkMouse _dragging=%d, %d _hots", _dragging, [_hots count]);
  if (!_dragging && [_hots count])
  {
    NSPoint where = [[[self window] contentView] convertPoint:[[self window] mouseLocationOutsideOfEventStream] toView:self];
    NSUInteger mods = local_CurrentModifiers();
    if (_lastMouse.x != where.x || _lastMouse.y != where.y || mods != _modifiers)
    {
      BOOL changed = NO;
      NSString* key = [self _keyForPoint:where];
      NSRect r;
      if (key && ![key isEqualToString:_lastHot])
      {
        r = [self _rectFromKey:key];
        [self setNeedsDisplayInRect:r];
        changed = YES;
        //NSLog(@"changed because new key (%@ != %@)", key, _lastHot);
      }
      if ([_lastHot length] && (!key || ![key isEqualToString:_lastHot]))
      {
        r = [self _rectFromKey:_lastHot];
        [self setNeedsDisplayInRect:r];
        changed = YES;
        //NSLog(@"changed because _lastHot != key (%@ != %@)", _lastHot, key);
      }
      if (changed || mods != _modifiers)
      {
        _modifiers = mods;
        [_lastHot setString:(key)? key:@""];
        //NSLog(@"_lastHot now %@", _lastHot);
        id del = [self delegate];
        if (del)
        {
          SEL sel = @selector(PDFImageMapDidChange:);
          if ([del respondsToSelector:sel])
            [del performSelector:sel withObject:self];
        }
      }
    }
    _lastMouse = where;
  }
}

-(NSString*)_keyForPoint:(NSPoint)p
{
  NSRect r = [self imageRect];
  NSString* key = nil;
  if ([self mouse:p inRect:r])
  {
    NSPoint where = NSMakePoint(p.x, p.y);
    // Convert to percentage
    where.x = (where.x-r.origin.x)/r.size.width;
    where.y = (where.y-r.origin.y)/r.size.height;
    NSEnumerator* e = [_hots keyEnumerator];
    NSString* rstring;
    while ((rstring = [e nextObject]))
    {
      SubRect hot = NSRectFromString(rstring);
      if ([self mouse:where inRect:hot])
      {
        key = rstring;
        break;
      }
    }
  }
  return key;
}

-(void)mouseEntered:(NSEvent*)evt
{
  if ([evt trackingNumber] != _trackingRect) return;
  BOOL useTimer = YES;
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  if (_tap)
  {
    CGEventTapEnable(_tap, true);
    useTimer = NO;
  }
#endif
  if (useTimer)
  {
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
                      selector:@selector(_hover:) userInfo:nil repeats:YES];
    if (_timer) [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
  }
}

-(void)mouseExited:(NSEvent*)evt
{
  if ([evt trackingNumber] != _trackingRect) return;
  BOOL useTimer = YES;
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  if (_tap)
  {
    CGEventTapEnable(_tap, false);
    useTimer = NO;
  }
#endif
  if (useTimer)
  {
    [_timer invalidate];
    _timer = nil;
  }
  if ([_lastHot length])
    [self setNeedsDisplayInRect:[self _rectFromKey:_lastHot]];
  [_lastHot setString:@""];
  id del = [self delegate];
  if (del)
  {
    SEL sel = @selector(PDFImageMapDidChange:);
    if ([del respondsToSelector:sel])
      [del performSelector:sel withObject:self];
  }
}

-(NSRect)imageRect
{
  NSSize imgSize = [[self image] size];
  NSRect bounds = [self bounds];
  NSRect imgRect = NSZeroRect;
  imgRect.size = imgSize;
  NSRect ir = [self _centerRect:imgRect inRect:bounds];
  //NSLog(@"imageRect %@ in %@", NSStringFromRect(ir), NSStringFromRect(bounds));
  return ir;
}

-(NSRect)_rectFromKey:(NSString*)key
{
  NSRect imgRect = [self imageRect];
  NSRect r = NSRectFromString(key);
  r.origin.x = imgRect.origin.x + r.origin.x * imgRect.size.width;
  r.origin.y = imgRect.origin.y + r.origin.y * imgRect.size.height;
  r.size.width *= imgRect.size.width;
  r.size.height *= imgRect.size.height;
  return r;
}

-(NSRect)_centerRect:(NSRect)rect inRect:(NSRect)host
{
  NSRect r = rect;
  CGFloat w2h = r.size.height/r.size.width;
  CGFloat h2w = r.size.width/r.size.height;
  // First scale it up if possible, then scale it down where necessary
  if (r.size.width < host.size.width)
  {
    r.size.width = host.size.width;
    r.size.height = w2h * r.size.width;
  }
  if (r.size.height < host.size.height)
  {
    r.size.height = host.size.height;
    r.size.width = h2w * r.size.height;
  }
  if (r.size.width > host.size.width)
  {
    r.size.width = host.size.width;
    r.size.height = w2h * r.size.width;
  }
  if (r.size.height > host.size.height)
  {
    r.size.height = host.size.height;
    r.size.width = h2w * r.size.height;
  }
  r.origin.x = host.origin.x + ((host.size.width-r.size.width)*0.5L);
  r.origin.y = host.origin.y + ((host.size.height-r.size.height)*0.5L);
  return r;
}

-(void)setDragImage:(NSImage*)img
{
  [img retain];
  if (_dragImage) [_dragImage release];
  _dragImage = img;
}
@end

static NSUInteger local_CurrentModifiers(void)
{
  UInt32 carbon = GetCurrentKeyModifiers();
  NSUInteger mods = 0;
  if (carbon & alphaLock) mods |= NSAlphaShiftKeyMask;
  if (carbon & shiftKey) mods |= NSShiftKeyMask;
  if (carbon & controlKey) mods |= NSControlKeyMask;
  if (carbon & optionKey) mods |= NSAlternateKeyMask;
  if (carbon & cmdKey) mods |= NSCommandKeyMask;
  return mods;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
static CGEventRef local_TapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)
{
  #pragma unused (proxy,type)
  PDFImageMap* me = refcon;
  [me _checkMouse];
  return event;
}
#endif
