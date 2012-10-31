/*
Copyright © 2009-2012 Brian S. Hall

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
#import "PDFImageMap.h"
#import <Carbon/Carbon.h>
#import "PDFImageMapCreator.h"

@interface PDFImageMap (Private)
-(void)_coreInit;
-(void)_detachWindow;
-(void)_checkMouse;
-(NSString*)_keyForPoint:(NSPoint)p;
-(NSRect)_rectFromKey:(NSString*)key;
-(NSRect)_centerRect:(NSRect)rect inRect:(NSRect)host;
@end

static NSUInteger local_CurrentModifiers(void);
static CGEventRef local_TapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon);



@implementation PDFImageMap
static CFMachPortRef gTap = NULL;  // Quartz event tap for tracking rects
static NSMapTable*   gObservers;

+(void)registerForEvents:(id)target action:(SEL)action
{
  if (!gTap)
  {
    gTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly,
                            CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventFlagsChanged),
                            local_TapCallback, nil);
    if (gTap)
    {
      CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gTap, 0);
      CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes);
      CFRelease(src);
      CGEventTapEnable(gTap, false);
    }
  }
  if (action)
  {
    if (!gObservers)
      gObservers = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory capacity:1];
    (void)NSMapInsert(gObservers, target, [NSValue valueWithPointer:action]);
    //[gObservers setObject:[NSValue valueWithPointer:action] forKey:target];
  }
  else
  {
    if (gObservers) NSMapRemove(gObservers, target);
  }
  //NSLog(@"Observers: %@", gObservers);
  if (gTap) CGEventTapEnable(gTap, (gObservers && [gObservers count] > 0));
}

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
  [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  if (!_data) _data = [[NSMutableDictionary alloc] init];
  if (!_hots) _hots = [[NSMutableDictionary alloc] init];
  if (!_lastHot) _lastHot = [[NSMutableString alloc] init];
  if (!_name) _name = [[NSMutableString alloc] init];
  if (!_subwindowName) _subwindowName = [[NSMutableString alloc] init];
  _canDragMap = YES;
  if ([self image])
  {
    _copyImage = [[self image] copy];
    [_copyImage setScalesWhenResized:YES];
  }
}

-(void)dealloc
{
  [self stopTracking];
  if (_dragImage) [_dragImage release];
  if (_copyImage) [_copyImage release];
  if (_data) [_data release];
  if (_hots) [_hots release];
  if (_submaps) [_submaps release];
  if (_lastHot) [_lastHot release];
  //if (_tap) CFRelease(_tap);
  [super dealloc];
}

-(void)setImage:(NSImage*)newImage
{
  if (_copyImage) [_copyImage release];
  _copyImage = [newImage copy];
  [_copyImage setScalesWhenResized:YES];
  [super setImage:newImage];
}

-(void)removeAllTrackingRects
{
  [_data removeAllObjects];
  [_hots removeAllObjects];
}

-(NSString*)name
{
  return _name;
}

-(void)setName:(NSString*)name
{
  [_name setString:name];
}

-(void)loadDataFromFile:(NSString*)path withName:(NSString*)name;
{
  NSArray* dat = [[NSArray alloc] initWithContentsOfFile:path];
  if (name) [_name setString:name];
  else name = _name;
  for (NSDictionary* entry in dat)
  {
    NSString* name2 = [entry objectForKey:@"name"];
    if (name && ![name isEqualToString:name2]) continue;
    NSString* key = [entry objectForKey:@"char"];
    SubRect r = NSRectFromString([entry objectForKey:@"rect"]);
    NSString* submapName = [entry objectForKey:@"submap"];
    if (submapName)
    {
      if (!_submaps) _submaps = [[NSMutableDictionary alloc] initWithCapacity:1];
      NSImage* image = [NSImage imageNamed:submapName];
      NSRect frame = NSZeroRect;
      frame.size = [image size];
      PDFImageMap* submap = [[PDFImageMap alloc] initWithFrame:frame];
      [submap setImage:image];
      [submap setName:submapName];
      [submap setDelegate:delegate];
      [submap setTarget:[self target]];
      [submap setAction:[self action]];
      [submap setTag:31337];
      [submap loadDataFromFile:path withName:nil];
      [_submaps setObject:submap forKey:key];
      [submap release];
    }
    [self setTrackingRect:r forKey:key];
  }
  [dat release];
  [self setNeedsDisplay:YES];
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
  _trackingRect = [self addTrackingRect:[self imageRect] owner:self
                        userData:self assumeInside:NO];
  NSPoint where = [[self window] mouseLocationOutsideOfEventStream];
  if (NSPointInRect(where, [self bounds]))
  {
    NSEvent* evt = [NSEvent enterExitEventWithType:NSMouseEntered
                    location:where modifierFlags:0 timestamp:0.0
                    windowNumber:0 context:[NSGraphicsContext currentContext]
                    eventNumber:0 trackingNumber:_trackingRect userData:NULL];
    [self mouseEntered:evt];
  }
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
  //[self addCursorRect:[self bounds] cursor:[NSCursor arrowCursor]];
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
    NSRect ir = [self imageRect];
    [_copyImage setSize:ir.size];
    [_copyImage compositeToPoint:ir.origin operation:NSCompositeSourceOver];
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

-(NSString*)subwindowName
{
  return _subwindowName;
}

-(void)showSubwindow:(NSString*)str
{
  if (!str || [str length] == 0) [self _detachWindow];
  else
  {
    _submap = [_submaps objectForKey:str];
    NSRect frame = [[self window] frame];
    NSPoint base = frame.origin;
    base.y += frame.size.height;
    base = [[self window] convertScreenToBase:base];
    if (_subwindow)
    {
      PDFImageMap* oldSub = [[_subwindow contentView] viewWithTag:31337];
      if (oldSub != _submap)
      {
        NSRect oldFrame = [oldSub frame];
        [[_subwindow contentView] replaceSubview:oldSub with:_submap];
        [_submap setFrame:oldFrame];
      }
      [_subwindow setPoint:base side:MAPositionBottomLeft];
      [_subwindowName setString:str];
    }
    else
    {
      _subwindow = [[MAAttachedWindow alloc] initWithView:_submap
                                             attachedToPoint:base
                                             inWindow:[self window]
                                             onSide:MAPositionBottomLeft
                                             atDistance:0.0f];
      //[_subwindow setViewMargin:2.0f]; // this is the MAAW default
      [_subwindow setHasArrow:0.0f];
      [_subwindow setCornerRadius:0.0f];
    }
    [[self window] addChildWindow:_subwindow ordered:NSWindowAbove];
    [_subwindow setLevel:[[self window] level]+1];
    [_subwindow orderFront:self];
    [_submap startTracking];
  }
}

-(void)_detachWindow
{
  if (_submap)
  {
    [_submap stopTracking];
    _submap = nil;
  }
  if (_subwindow)
  {
    [[self window] removeChildWindow:_subwindow];
    [_subwindow orderOut:self];
  }
  [_subwindowName setString:@""];
}

-(void)mouseDown:(NSEvent*)evt
{
  _modifiers = [evt modifierFlags];
  NSEvent* down = evt;
  BOOL wasDrag = NO;
  // Make sure stringValue gets updated
  [self _checkMouse];
  NSString* str = [self stringValue];
  NSRect r = [self _rectFromKey:_lastHot];
  if (str && [_submaps objectForKey:str])
  {
    NSBezierPath* tri = [PDFImageMapCreator newSubmapIndicatorCocoaInRect:r];
    NSPoint mouse = [self convertPoint:[evt locationInWindow] fromView:nil];
    if ([tri containsPoint:mouse])
    {
      if ([_subwindowName isEqualToString:str]) [self _detachWindow];
      else [self showSubwindow:str];
      [tri release];
      return;
    }
    [tri release];
  }
  while (YES)
  {
    evt = [[self window] nextEventMatchingMask:NSLeftMouseDraggedMask | NSLeftMouseUpMask];
    if (evt)
    {
      if ([evt type] == NSLeftMouseUp) break;
      NSData* encoded = [str dataUsingEncoding:NSUTF8StringEncoding
                             allowLossyConversion:NO];
      if (encoded || (_canDragMap && !str))
      {
        NSImage* img = _dragImage;
        if (nil == img || !str) img = [self image];
        if (img)
        {
          //img = [img copy];
          NSSize imgSize = [img size];
          NSRect srcr, destr;
          if (str)
          {
            srcr = NSRectFromString([_data objectForKey:str]);
            srcr.origin.x *= imgSize.width;
            srcr.origin.y *= imgSize.height;
            srcr.size.width *= imgSize.width;
            srcr.size.height *= imgSize.height;
            srcr = NSInsetRect(srcr, 1.0L, 1.0L);
            destr = r;
            _draggingSymbol = YES;
          }
          else
          {
            srcr = NSZeroRect;
            srcr.size = [img size];
            destr = [self imageRect];
            r = destr;
            _draggingSymbol = NO;
          }
          destr.origin = NSZeroPoint;
          NSPoint dragPoint = NSMakePoint(r.origin.x, r.origin.y);
          NSImage* draggingImage = [[NSImage alloc] initWithSize:r.size];
          [draggingImage lockFocus];
          [img drawInRect:destr fromRect:srcr
               operation:NSCompositeSourceOver fraction:1.0L];
          //[img release];
          [draggingImage unlockFocus];
          NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
          NSArray* types = [NSArray arrayWithObjects:NSStringPboardType, NULL];
          [pboard declareTypes:types owner:self];
          [pboard setData:encoded forType:NSStringPboardType];
          _dragging = YES;
          [self dragImage:draggingImage at:dragPoint offset:NSZeroSize
                event:evt pasteboard:pboard source:self
                slideBack:_draggingSymbol];
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
      id target = [self target];
      SEL action = [self action];
      if (target && action)
      {
        //NSLog(@"target %@, action 0x%X _lastHot '%@' string '%@'", target, action, _lastHot, [self stringValue]);
        [target performSelector:action withObject:self];
      }
    }
  }
}

-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)loc
{
  #pragma unused (loc)
  return (loc)? NSDragOperationCopy | NSDragOperationPrivate :
                ((_draggingSymbol)? NSDragOperationCopy : NSDragOperationNone);
}

-(void)draggedImage:(NSImage*)img endedAt:(NSPoint)p
       operation:(NSDragOperation)op
{
  #pragma unused (img,op)
  if (!_draggingSymbol)
  {
    //NSPoint where = p;//[self convertPointToBase:p];
    //NSRect f = [[self window] frame];
    //NSLog(@"Is %@ outside %@?", NSStringFromPoint(where), NSStringFromRect(f));
    //if (NSPointInRect(where, f)/* && NSPointInRect([NSEvent mouseLocation], f)*/)
    if (NO)
    {
      //NSLog(@"Nope!");
    }
    else
    {
      _dropPoint = p;
      id del = [self delegate];
      if (del)
      {
        SEL sel = @selector(PDFImageMapDidDrag:);
        if ([del respondsToSelector:sel])
          [del performSelector:sel withObject:self];
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

-(void)setDelegate:(id)del
{
  [del retain];
  [delegate release];
  delegate = del;
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
    //NSLog(@"%@: %@ in %@?", _name, NSStringFromPoint(where),NSStringFromRect([self frame]);
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
    for (NSString* rstring in _hots)
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
  [[self class] registerForEvents:self action:@selector(_checkMouse)];
  //if (_tap) CGEventTapEnable(_tap, true);
}

-(void)mouseExited:(NSEvent*)evt
{
  if ([evt trackingNumber] != _trackingRect) return;
  [[self class] registerForEvents:self action:nil];
  //if (_tap) CGEventTapEnable(_tap, false);
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

-(BOOL)canDragMap { return _canDragMap; }
-(void)setCanDragMap:(BOOL)can { _canDragMap = can; }
-(NSPoint)dropPoint { return _dropPoint; }

@end

// We talk to the hardware because we are an LSUIElement and we don't seem
// to get modifier key changes.
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

static CGEventRef local_TapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)
{
  #pragma unused (proxy,type,refcon)
  if (gObservers)
  {
    for (id target in NSAllMapTableKeys(gObservers))
    {
      NSValue* val = NSMapGet(gObservers, target);
      SEL action = [val pointerValue];
      //NSLog(@"%@ has %s", target, action);
      if (action && [target respondsToSelector:action])
        [target performSelector:action];
    }
  }
  return event;
}

