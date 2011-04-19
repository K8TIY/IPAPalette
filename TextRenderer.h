/*
Copyright © 2005-2010 Brian S. Hall

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
#include <Carbon/Carbon.h>

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
#else	/* !defined(__LP64__) || !__LP64__ */
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_IS_DOUBLE 0
#endif	/* !defined(__LP64__) || !__LP64__ */
#define CGFLOAT_DEFINED 1
#endif

typedef struct
{
  CGFloat  height;
  CGFloat  width;
  CGFloat  ascent;
  CGFloat  descent;
  CGFloat  baseline;
  Boolean fontSupported;
} TRInfo;

typedef enum
{
  TRSubstituteFallbackBehavior,
  TRLastResortFallbackBehavior,
  TRNoRenderFallbackBehavior
} TRFallbackBehavior;

OSStatus TRGetBestFontSize(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, TRFallbackBehavior fallbackBehavior, CGFloat* oFontSize, CGFloat* oBaseline);
OSStatus TRGetTextInfo(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize, TRFallbackBehavior fallbackBehavior, TRInfo* oInfo);
OSStatus TRRenderText(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize, TRFallbackBehavior fallbackBehavior, CGFloat baseline);

