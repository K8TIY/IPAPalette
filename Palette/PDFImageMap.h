#import <Cocoa/Cocoa.h>
#import "MAAttachedWindow.h"

// Same fields as an NSRect, but a SubRect has all fields as
// percentages (<= 1.0) so this describes a portion of some
// other 2D object. In this case, the subrects are the hot
// spots in the image map. If the image is scaled, the new
// hot spots' areas can be recalculated easily.
typedef NSRect SubRect;

@interface PDFImageMap : NSImageView <NSDraggingSource>
{
  NSMutableDictionary*   _data; // key -> stringified SubRect
  NSMutableDictionary*   _hots; // stringified SubRect -> key
  NSMutableDictionary*   _submaps; // key -> PDFImageMap
  // an optional image used for generating drag images in case
  // the regular image has extra "stuff" (like the lines in the vowel chart)
  NSImage*               _dragImage;
  NSImage*               _copyImage; // The scalable one
  NSMutableString*       _lastHot;
  NSMutableString*       _name;
  NSUInteger             _modifiers;
  MAAttachedWindow*      _subwindow;
  NSMutableString*       _subwindowName;
  PDFImageMap*           _submap;
  id                     delegate;
  NSPoint                _lastMouse;
  NSPoint                _dropPoint;
  NSTrackingRectTag      _trackingRect; // for the whole view
  BOOL                   _dragging;
  BOOL                   _draggingSymbol;
  BOOL                   _canDragMap;
}
-(NSString*)stringValue;
-(void)startTracking;
-(void)stopTracking;
-(NSString*)subwindowName;
-(void)showSubwindow:(NSString*)str;
-(void)removeAllTrackingRects;
-(NSString*)name;
-(void)setName:(NSString*)name;
-(void)loadDataFromFile:(NSString*)path withName:(NSString*)name;
-(void)setTrackingRect:(SubRect)r forKey:(NSString*)key;
-(NSUInteger)modifiers;
-(id)delegate;
-(void)setDelegate:(id)del;
-(void)setDragImage:(NSImage*)img;
-(NSRect)imageRect;
-(BOOL)canDragMap;
-(void)setCanDragMap:(BOOL)can;
-(NSPoint)dropPoint;
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
