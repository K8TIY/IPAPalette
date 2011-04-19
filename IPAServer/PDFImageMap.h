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
#import <Cocoa/Cocoa.h>

#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSINTEGER_DEFINED 1
#endif

#ifndef CGFLOAT_DEFINED
#if defined(__LP64__) && __LP64__
typedef double CGFloat;
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#define CGFLOAT_IS_DOUBLE 1
#else /* !defined(__LP64__) || !__LP64__ */
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_IS_DOUBLE 0
#endif /* !defined(__LP64__) || !__LP64__ */
#define CGFLOAT_DEFINED 1
#endif

// Same fields as an NSRect, but a SubRect has all fields as
// percentages (<= 1.0) so this describes a portion of some
// other 2D object. In this case, the subrects are the hot
// spots in the image map. If the image is scaled, the new
// hot spots' areas can be recalculated easily.
typedef NSRect SubRect;

@interface PDFImageMap : NSImageView
{
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
  CFMachPortRef          _tap;  // Quartz event tap for tracking rects
#endif
  NSMutableDictionary*   _data; // key -> stringified SubRect
  NSMutableDictionary*   _hots; // stringified SubRect -> key
  // an optional image used for generating drag images in case
  // the regular image has extra "stuff" (like the lines in the vowel chart)
  NSImage*               _dragImage;
  NSMutableString*       _lastHot;
  NSUInteger             _modifiers;
  NSTimer*               _timer;
  id                     delegate;
  NSPoint                _lastMouse;
  NSTrackingRectTag      _trackingRect; // for the whole view
  BOOL                   _dragging;
}
-(NSString*)stringValue;
-(void)startTracking;
-(void)stopTracking;
-(void)removeAllTrackingRects;
-(void)setTrackingRect:(SubRect)r forKey:(NSString*)key;
-(NSUInteger)modifiers;
-(id)delegate;
-(void)setDragImage:(NSImage*)img;
@end
