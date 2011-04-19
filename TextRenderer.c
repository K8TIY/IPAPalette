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
#include "TextRenderer.h"

// Should we use Core Text?
// CT on Leopard/Snow Leopard/64 bit shows all kinds of weird buggy behavior, and little real documentation.
// So we stick to 32 bit and use ATSUI.
#define USE_CT 0

#if !USE_CT
static ATSUFontID* local_FallbacksWithCount(unsigned* oCount);
#endif

static OSStatus local_CoreTR(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize,
                             TRFallbackBehavior fallbackBehavior, Boolean render, CGFloat baseline, TRInfo* oInfo);

#ifdef __LP64__
#define __fpmin  fmin
#else
#define __fpmin  fminf
#endif

OSStatus TRGetBestFontSize(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName,
                           TRFallbackBehavior fallbackBehavior, CGFloat* oFontSize, CGFloat* oBaseline)
{
  CGFloat fontSize = 0.0f;
  CGFloat baseline = 0.0f;
  if (fontName)
  {
    r = CGRectInset(r, 0.1f*r.size.width, 0.1f*r.size.height);
    Boolean tooBig = true;
    fontSize = 100.0f;
    NSUInteger i = 0;
    while (tooBig && fontSize > 0.0f)
    {
      TRInfo info;
      OSStatus err = TRGetTextInfo(ctx, r, string, fontName, fontSize, fallbackBehavior, &info);
      if (err == paramErr) return err;
      baseline = info.baseline;
      /*printf("_setUpFontWithFrame:{%.2f %.2f} size=%.2fpt w=%.2f h=%.2f asc=%f desc=%f bl=%f\n",
              r.size.width, r.size.height, fontSize, info.width, info.height,
              info.ascent, info.descent, baseline);*/
      if (info.height < r.size.height && info.width < r.size.width) break;
      CGFloat pct = __fpmin((r.size.height/info.height), (r.size.width/info.width));
      //printf("pct %f\n", pct);
      if (pct > .99f && pct < 1.01f) break;
      fontSize *= pct;
      i++;
      if (i > 10) break;
    }
  }
  *oFontSize = fontSize;
  // ATSUI needs to be nudged up a bit. Maybe 10%
#if !USE_CT
  baseline += (baseline * 0.1f);
#endif
  *oBaseline = baseline;
  return noErr;
}

OSStatus TRGetTextInfo(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize,
                       TRFallbackBehavior fallbackBehavior, TRInfo* oInfo)
{
  return local_CoreTR(ctx, r, string, fontName, fontSize, fallbackBehavior, false, -1.0L, oInfo);
}

OSStatus TRRenderText(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize,
                      TRFallbackBehavior fallbackBehavior, CGFloat baseline)
{
  return local_CoreTR(ctx, r, string, fontName, fontSize, fallbackBehavior, true, baseline, NULL);
}


static OSStatus local_CoreTR(CGContextRef ctx, CGRect r, CFStringRef string, CFStringRef fontName, CGFloat fontSize,
                             TRFallbackBehavior fallbackBehavior, Boolean render, CGFloat baseline, TRInfo* oInfo)
{
#if USE_CT
  if (!ctx || !string) return paramErr;
  CGContextSaveGState(ctx);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  CTFontDescriptorRef fdesc = CTFontDescriptorCreateWithNameAndSize(fontName, fontSize);
  CTFontRef font = CTFontCreateWithFontDescriptor(fdesc, fontSize, NULL);
  CFIndex slen = CFStringGetLength(string);
  CFRange range = CFRangeMake(0L,slen);
  UniChar* buff = calloc(slen, sizeof(UniChar));
  CFStringGetCharacters(string, range, buff);
  CGGlyph* glyphs = calloc(slen, sizeof(CGGlyph));
  Boolean fontSupported = CTFontGetGlyphsForCharacters(font, buff, glyphs, slen);
  //NSLog(@"%@ supported for '%@'? %d", fontName, string, fontSupported);
  CFRelease(fdesc);
  if (!fontSupported)
  {
    if (fallbackBehavior == TRLastResortFallbackBehavior)
    {
      CFRelease(font);
      fdesc = CTFontDescriptorCreateWithNameAndSize(CFSTR("LastResort"), fontSize);
      font = CTFontCreateWithFontDescriptor(fdesc, fontSize, NULL);
      CFRelease(fdesc);
      fontSupported = true;
    }
    else
    {
      CTFontRef font2 = CTFontCreateForString(font, string, CFRangeMake(0L, CFStringGetLength(string)));
      CFRelease(font);
      CFStringRef fontName2 = CTFontCopyName(font2, kCTFontFullNameKey);
      fdesc = CTFontDescriptorCreateWithNameAndSize(fontName2, fontSize);
      //NSLog(@"falling back to %@ : %@", fontName2, fdesc);
      CFRelease(fontName2);
      font = CTFontCreateWithFontDescriptor(fdesc, fontSize, NULL);
      CFRelease(fdesc);
      fontSupported = CTFontGetGlyphsForCharacters(font, buff, glyphs, slen);
    }
  }
  free(buff);
  free(glyphs);
  CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1L, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionarySetValue(attrs, kCTFontAttributeName, font);
  CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attrs);
  CFRelease(attrs);
  CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attrString);
  //NSLog(@"Checking %@", attrString);
  CFRelease(attrString);
  CGRect bounds = CTLineGetImageBounds(line, ctx);
  CGFloat descent = CTFontGetDescent(font);
  CGFloat ascent = CTFontGetAscent(font);
  CFRelease(font);
  if (baseline < 0.0L) baseline = ((r.size.height - bounds.size.height + descent)/2.0L);
  if (render && (fontSupported || fallbackBehavior != TRNoRenderFallbackBehavior))
  {
    CGFloat x = r.origin.x + (r.size.width/2.0L) - (bounds.size.width/2.0L) - bounds.origin.x;
    CGFloat y = r.origin.y + baseline;
    CGPoint where = CGPointMake(x, y);
    CGContextSetTextPosition(ctx, where.x, where.y);
    //NSLog(@"Rendering at %@", NSStringFromPoint(*(NSPoint*)&where));
    CTLineDraw(line, ctx);
  }
  CFRelease(line);
  if (oInfo)
  {
    oInfo->height = bounds.size.height + descent;
    oInfo->width = bounds.size.width;
    oInfo->ascent = ascent;
    oInfo->descent = descent;
    oInfo->baseline = baseline;
    oInfo->fontSupported = fontSupported;
  }
  CGContextRestoreGState(ctx);
  
#else
  CGFloat               txHeight = 0.0f;
  CGFloat               txWidth = 0.0f;
  CGFloat               txAsc = 0.0f;
  CGFloat               txDesc = 0.0f;
  ATSUFontID            fid;
  ItemCount             nsb;
  UniCharArrayOffset*   sbs;
  ATSUFontFallbacks     fallbacks;
  unsigned              nfbfonts;
  
  CFIndex nameLength = CFStringGetMaximumSizeForEncoding(CFStringGetLength(fontName), kCFStringEncodingUTF8);
  char* atsuf = malloc(nameLength + 1);
  verify_noerr(CFStringGetCString(fontName, atsuf, nameLength + 1, kCFStringEncodingUTF8));
  verify_noerr(ATSUFindFontFromName(atsuf, strlen(atsuf), kFontFullName,
      kFontNoPlatformCode, kFontNoScriptCode, kFontNoLanguage, &fid));
  free(atsuf);
  ATSUTextLayout layout;
  UniCharArrayOffset layoutStart, currentEnd;
  UniCharCount layoutLength;
  ATSUAttributeTag tags[2] = {kATSUSizeTag,kATSUFontTag};
  ByteCount sizes[2] = {sizeof(Fixed),sizeof(ATSUFontID)};
  ATSUAttributeValuePtr vals[2];
  Fixed fsiz = FloatToFixed(fontSize);
  vals[0] = &fsiz;
  vals[1] = &fid;
  ATSUStyle style;
  verify_noerr(ATSUCreateStyle(&style));
  verify_noerr(ATSUSetAttributes(style, (fontName)? 2:1, tags, sizes, vals));
  CFIndex slen = CFStringGetLength(string);
  CFRange range = CFRangeMake(0,slen);
  UniChar* buff = malloc(slen*sizeof(UniChar));
  CFStringGetCharacters(string, range, buff);
  verify_noerr(ATSUCreateTextLayoutWithTextPtr(buff, 0, slen, slen, 1,
                (UniCharCount*)&slen, &style, &layout));
  ATSUFontID oFontID;
  UniCharArrayOffset oChangedOffset;
  UniCharCount oChangedLength;
  Boolean fontSupported = (noErr == ATSUMatchFontsToText(layout, 0, slen, &oFontID, &oChangedOffset, &oChangedLength));
  verify_noerr(ATSUCreateFontFallbacks(&fallbacks));
  ATSUFontID* fbfonts = local_FallbacksWithCount(&nfbfonts);
  verify_noerr(ATSUSetObjFontFallbacks(fallbacks, nfbfonts, fbfonts,
                (fallbackBehavior == TRLastResortFallbackBehavior)?
                kATSULastResortOnlyFallback:kATSUSequentialFallbacksPreferred));
  tags[0] = kATSULineFontFallbacksTag;
  sizes[0] = sizeof(ATSUFontFallbacks);
  vals[0] = &fallbacks;
  verify_noerr(ATSUSetLayoutControls(layout, 1, tags, sizes, vals));
  verify_noerr(ATSUSetTransientFontMatching(layout, true));
  Fixed lineWidth = X2Fix(r.size.width+1000.0);
  // In this example, we are breaking text into lines.
  // Therefore, we need to make sure the layout knows the width of the line.
  tags[0] = kATSULineWidthTag;
  sizes[0] = sizeof(Fixed);
  vals[0] = &lineWidth;
  verify_noerr( ATSUSetLayoutControls(layout, 1, tags, sizes, vals) );
  // Make sure the layout knows the proper CGContext to use for drawing
  tags[0] = kATSUCGContextTag;
  sizes[0] = sizeof(CGContextRef);
  vals[0] = &ctx;
  verify_noerr(ATSUSetLayoutControls(layout, 1, tags, sizes, vals) );
  // Find out about this layout's text buffer
  verify_noerr(ATSUGetTextLocation(layout, NULL, NULL, &layoutStart, &layoutLength, NULL) );
  //NSLog(@"layout %lu length %lu", layoutStart, layoutLength);
  verify_noerr(ATSUBatchBreakLines(layout, layoutStart, layoutLength, lineWidth, &nsb) );
  // Obtain a list of all the line break positions
  verify_noerr(ATSUGetSoftLineBreaks(layout, layoutStart, layoutLength, 0, NULL, &nsb) );
  sbs = (UniCharArrayOffset*)malloc(nsb * sizeof(UniCharArrayOffset));
  verify_noerr(ATSUGetSoftLineBreaks(layout, layoutStart, layoutLength, nsb, sbs, &nsb));
  currentEnd = (nsb > 0) ? sbs[0] : layoutStart + layoutLength;
  ATSUTextMeasurement before, after, asc, desc;
  verify_noerr(ATSUGetUnjustifiedBounds(layout, layoutStart, currentEnd - layoutStart,
                &before, &after, &asc, &desc));
  txAsc = FixedToFloat(asc);
  txDesc = FixedToFloat(desc);
  txHeight = txAsc + txDesc;
  txWidth = FixedToFloat(before) + FixedToFloat(after);
  if (baseline < 0.0) baseline = ((r.size.height - txHeight)/2.0f) + txDesc;
  if (render && (fontSupported || fallbackBehavior != TRNoRenderFallbackBehavior))
  {
    double x = r.origin.x + ((r.size.width - txWidth)/2.0);
    double y = r.origin.y + baseline;
    // Clip to inset rectangle
    //CGContextBeginPath(ctx);
    //CGContextAddRect(ctx, *(CGRect*)&r);
    //CGContextClip(ctx);
    CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
    verify_noerr(ATSUDrawText(layout, layoutStart, currentEnd - layoutStart, X2Fix(x), X2Fix(y)));
  }
  free(sbs);
  ATSUDisposeFontFallbacks(fallbacks);
  ATSUDisposeStyle(style);
  ATSUDisposeTextLayout(layout);
  free(buff);
  if (oInfo)
  {
    oInfo->height = txHeight;
    oInfo->width = txWidth;
    oInfo->ascent = txAsc;
    oInfo->descent = txDesc;
    oInfo->baseline = baseline;
    oInfo->fontSupported = fontSupported;
  }
#endif
  return (fontSupported)? noErr:kATSUFontsNotMatched;
}

#if !USE_CT
static ATSUFontID* local_FallbacksWithCount(unsigned* oCount)
{
  unsigned n = 0;
  static ATSUFontID fids[4] = {0,0,0,0};
  if (!ATSUFindFontFromName("Doulos SIL", strlen("Doulos SIL"), kFontFullName,
                            kFontNoPlatformCode, kFontNoScriptCode,
                            kFontNoLanguage, &fids[n])) n++;
  if (!ATSUFindFontFromName("Charis SIL", strlen("Charis SIL"), kFontFullName,
                            kFontNoPlatformCode, kFontNoScriptCode,
                            kFontNoLanguage, &fids[n])) n++;
  if (!ATSUFindFontFromName("Gentium", strlen("Gentium"), kFontFullName,
                            kFontNoPlatformCode, kFontNoScriptCode,
                            kFontNoLanguage, &fids[n])) n++;
  *oCount = n;
  return fids;
}
#endif
