#import "PDFImageMap.h"
#import <Carbon/Carbon.h>
#import "PDFImageMapCreator.h"
#import "NSApplication+DarkMode.h"

@interface PDFImageMap (Private)
-(void)_coreInit;
-(void)_detachWindow;
-(void)_checkMouse;
-(NSString*)_keyForPoint:(NSPoint)p;
-(NSRect)_rectFromKey:(NSString*)key;
-(NSRect)_centerRect:(NSRect)rect inRect:(NSRect)host;
@end

static NSUInteger local_CurrentModifiers(void);

@implementation PDFImageMap
static NSMapTable*   gObservers;
static id gEventMonitor = NULL;

+(void)registerForEvents:(id)target action:(SEL)action
{
  if (action && !gEventMonitor)
  {
    if (!gEventMonitor)
    {
      NSEventMask mask = NSEventMaskMouseMoved | NSEventMaskFlagsChanged;
      gEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mask
             handler:^(NSEvent* event)
             {
               #pragma unused (event)
               if (gObservers)
               {
                 for (id target2 in NSAllMapTableKeys(gObservers))
                 {
                   NSValue* val = NSMapGet(gObservers, target2);
                   SEL action2 = [val pointerValue];
                   if (action2 && [target2 respondsToSelector:action2])
                     [target2 performSelector:action2];
                 }
               }
             }];
    }
  }
  else
  {
    [NSEvent removeMonitor:gEventMonitor];
    gEventMonitor = NULL;
  }
  if (action)
  {
    if (!gObservers)
      gObservers = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory capacity:1];
    (void)NSMapInsert(gObservers, target, [NSValue valueWithPointer:action]);
  }
  else
  {
    if (gObservers) NSMapRemove(gObservers, target);
  }
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
    // Deprecated
    //[_copyImage setScalesWhenResized:YES];
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
  //[_copyImage setScalesWhenResized:YES];
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
      NSString* submapPDF = [PDFImageMapCreator copyPDFFileNameForName:submapName
                                                dark:[NSApplication isDarkMode]];
      NSImage* image = [NSImage imageNamed:submapPDF];
      [submapPDF release];
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
    NSEvent* evt = [NSEvent enterExitEventWithType:NSEventTypeMouseEntered
                    location:where modifierFlags:0 timestamp:0.0
                    windowNumber:0 context:[NSGraphicsContext currentContext]
                    eventNumber:0 trackingNumber:_trackingRect userData:NULL];
    [self mouseEntered:evt];
  }
}

-(void)stopTracking
{
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
    // Deprecated
    //[_copyImage compositeToPoint:ir.origin operation:NSCompositeSourceOver];
    [_copyImage drawInRect:ir fromRect:NSZeroRect
                operation:NSCompositingOperationSourceOver fraction:1.0];
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
    NSRect frame = [[self window] convertRectFromScreen:[[self window] frame]];
    NSPoint base = frame.origin;
    base.y += frame.size.height;
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
    evt = [[self window] nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
    if (evt)
    {
      if ([evt type] == NSEventTypeLeftMouseUp) break;
      if (str || _canDragMap)
      {
        NSImage* img = _dragImage;
        if (nil == img || !str) img = [self image];
        if (img)
        {
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
            str = @"";
          }
          destr.origin = NSZeroPoint;
          NSImage* draggingImage = [[NSImage alloc] initWithSize:r.size];
          [draggingImage lockFocus];
          [img drawInRect:destr fromRect:srcr
               operation:NSCompositingOperationSourceOver fraction:1.0L];
          [draggingImage unlockFocus];
          _dragging = YES;
          NSDraggingItem* drag = [[NSDraggingItem alloc] initWithPasteboardWriter:str];
          //drag.draggingFrame = r;
          [drag setDraggingFrame:r contents:draggingImage];
          NSArray* drags = [[NSArray alloc] initWithObjects:drag, NULL];
          [drag release];
          NSDraggingSession* session = [self beginDraggingSessionWithItems:drags event:evt source:self];
          if (!_draggingSymbol) session.animatesToStartingPositionsOnCancelOrFail = NO;
          [drags release];
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
    [[self window] discardEventsMatchingMask:NSEventMaskAny beforeEvent:down];
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

-(NSDragOperation)draggingSession:(NSDraggingSession*)session
                  sourceOperationMaskForDraggingContext:(NSDraggingContext)ctx
{
  #pragma unused (session)
  switch (ctx)
  {
    case NSDraggingContextOutsideApplication:
    return (_draggingSymbol)? NSDragOperationCopy : NSDragOperationNone;
    break;

    case NSDraggingContextWithinApplication:
    default:
    return (_draggingSymbol)? NSDragOperationNone : NSDragOperationGeneric;
    break;
  }
}

-(BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession*)session
{
  #pragma unused (session)
  return YES;
}

-(void)draggingSession:(NSDraggingSession*)session
       endedAtPoint:(NSPoint)p
       operation:(NSDragOperation)op
{
  #pragma unused (session,op)
  if (!_draggingSymbol)
  {
    _dropPoint = p;
    id del = [self delegate];
    if (del)
    {
      #pragma clang diagnostic push
      #pragma clang diagnostic ignored "-Wundeclared-selector"
      SEL sel = @selector(PDFImageMapDidDrag:);
      if ([del respondsToSelector:sel])
        [del performSelector:sel withObject:self];
      #pragma clang diagnostic pop
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
          #pragma clang diagnostic push
          #pragma clang diagnostic ignored "-Wundeclared-selector"
          SEL sel = @selector(PDFImageMapDidChange:);
          if ([del respondsToSelector:sel])
            [del performSelector:sel withObject:self];
          #pragma clang diagnostic pop
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
  //NSLog(@"Entered");
  if ([evt trackingNumber] != _trackingRect) return;
  [[self class] registerForEvents:self action:@selector(_checkMouse)];
  //if (_tap) CGEventTapEnable(_tap, true);
}

-(void)mouseExited:(NSEvent*)evt
{
  //NSLog(@"Exited");
  if ([evt trackingNumber] != _trackingRect) return;
  [[self class] registerForEvents:self action:nil];
  //if (_tap) CGEventTapEnable(_tap, false);
  if ([_lastHot length])
    [self setNeedsDisplayInRect:[self _rectFromKey:_lastHot]];
  [_lastHot setString:@""];
  id del = [self delegate];
  if (del)
  {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    SEL sel = @selector(PDFImageMapDidChange:);
    if ([del respondsToSelector:sel])
      [del performSelector:sel withObject:self];
    #pragma clang diagnostic pop
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
  if (carbon & alphaLock) mods |= NSEventModifierFlagCapsLock;
  if (carbon & shiftKey) mods |= NSEventModifierFlagShift;
  if (carbon & controlKey) mods |= NSEventModifierFlagControl;
  if (carbon & optionKey) mods |= NSEventModifierFlagOption;
  if (carbon & cmdKey) mods |= NSEventModifierFlagCommand;
  return mods;
}

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
