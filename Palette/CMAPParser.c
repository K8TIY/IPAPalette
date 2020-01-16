#include "CMAPParser.h"
#include <CoreFoundation/CFByteOrder.h>

static int local_Format2HasChar(uint16_t chr, char* subtableAddr);
static int local_Format4HasChar(uint16_t chr, char* subtableAddr);
static int local_Format6HasChar(uint16_t chr, char* subtableAddr);
static int local_Format12HasChar(uint16_t chr, char* subtableAddr);


typedef struct
{
  uint16_t platformID;
  uint16_t platformSpecificID;
  uint32_t offset;
} CMAPSubtable;

int CMAPHasChar(char* ttf, uint16_t chr)
{
  uint32_t i;
  uint16_t nencs, version, format;
  char* tableStart = ttf;
  int has = 0;
  version = CFSwapInt16BigToHost(*(uint16_t*)ttf);
  ttf += 2;
  nencs = CFSwapInt16BigToHost(*(uint16_t*)ttf);
  ttf += 2;
  if (0 != version && 0 == nencs) nencs = version; // Sometimes they are backwards
  for (i = 0; i < nencs; ++i)
  {
    char* subtableAddr;
    CMAPSubtable sub;
    sub.platformID = CFSwapInt16BigToHost(*(uint16_t*)ttf);
    ttf += 2;
    sub.platformSpecificID = CFSwapInt16BigToHost(*(uint16_t*)ttf);
    ttf += 2;
    sub.offset = CFSwapInt32BigToHost(*(uint32_t*)ttf);
    ttf += 4;
    subtableAddr = tableStart + sub.offset;
    format = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
    if (format != 0)
    {
      // Allow Unicode platform, or Windows platform, Unicode and UCS4
      if (sub.platformID == 0 ||
          (sub.platformID == 3 && (sub.platformSpecificID == 2 || sub.platformSpecificID == 10)))
      {
        if (format == 2) has = local_Format2HasChar(chr, subtableAddr);
        else if (format == 4) has = local_Format4HasChar(chr, subtableAddr);
        else if (format == 6) has = local_Format6HasChar(chr, subtableAddr);
        else if (format == 12) has = local_Format12HasChar(chr, subtableAddr);
        if (has) break;
      }
    }
  }
  return has;
}



typedef struct
{
  uint16_t format;
  uint16_t length;
  uint16_t language;
} Format2Header;
#define kFormat2HeaderLength 6

typedef struct
{
  uint16_t firstCode;
  uint16_t entryCount;
  int16_t idDelta;
  uint16_t idRangeOffset;
} Format2Subheader;

// This is probably never used; it is untested.
// Apple's and Microsoft's docs on this table are well nigh incomprehensible.
// (Didn't it ever occur to them to just include an *example*?!)
static int local_Format2HasChar(uint16_t chr, char *subtableAddr)
{
  int has = 0;
  uint16_t* subHeaderKeysAddr;
  unsigned char hi, lo;
  uint16_t k;
  Format2Subheader sh;
  //Format2Header f2h = *(Format2Header*)subtableAddr;
  subtableAddr += kFormat2HeaderLength;
  subHeaderKeysAddr = (uint16_t*)subtableAddr;
  subtableAddr += (256 * sizeof(uint16_t));
  // subtableAddr now points to variable-length array of Format2Subheader
  hi = chr >> 8;
  lo = chr & 0x00FF;
  //printf("local_Format2HasChar: checking high byte of 0x%x = 0x%x\n", chr, hi);
  k = CFSwapInt16BigToHost(subHeaderKeysAddr[hi]) / 8;
  //printf("local_Format2HasChar: subHeaderKeysAddr[hi]=%d k=%d\n", subHeaderKeysAddr[hi], k);
  if (k == 0)
  {
    // One-byte only if the high byte of chr was zero
    // In IPAServer this will not happen because we are searching for
    // a 2-byte unichar.
    //printf("local_Format2HasChar: single-byte char!\n");
    if (chr == hi)
    {
      sh.firstCode = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
      subtableAddr += 2;
      sh.entryCount = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
      subtableAddr += 2;
      sh.idDelta = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
      subtableAddr += 2;
      sh.idRangeOffset = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
      if (sh.firstCode == 0 &&
          sh.entryCount == 256 &&
          sh.idDelta == 0)
      {
        //printf("local_Format2HasChar: in range!\n");
        has = 1;
      }
    }
  }
  else
  {
    //sh = ((Format2Subheader*)subtableAddr)[k];
    subtableAddr += (k * sizeof(Format2Subheader));
    sh.firstCode = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
    subtableAddr += 2;
    sh.entryCount = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
    subtableAddr += 2;
    sh.idDelta = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
    subtableAddr += 2;
    sh.idRangeOffset = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
    //printf("local_Format2HasChar: multi-byte char; firstCode=%d entryCount=%d\n", sh.firstCode, sh.entryCount);
    if (sh.firstCode <= lo && lo < sh.firstCode + sh.entryCount)
    {
      //printf("local_Format2HasChar: idRangeOffset=%d\n", sh.idRangeOffset);
      has = 1;
    }
  }
  return has;
}

typedef struct
{
  uint16_t format;
  uint16_t length;
  uint16_t language;
  uint16_t segCountX2;
  uint16_t searchRange;
  uint16_t entrySelector;
  uint16_t rangeShift;
} Format4Header;
//#define kFormat4HeaderLength 14

static int local_Format4HasChar(uint16_t chr, char *subtableAddr)
{
  uint32_t j;
  int has = 0;
  uint16_t* endCodes;
  uint16_t* startCodes;
  uint16_t* idDeltas;
  uint16_t* idRangeOffsets;
  //uint16_t* glyphIndices;
  uint16_t segCount;
  Format4Header f4h;
  f4h.format = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.length = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.language = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.segCountX2 = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.searchRange = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.entrySelector = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f4h.rangeShift = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  // subtableAddr now points to endCodes
  segCount = f4h.segCountX2 / 2;
  /*NSLog(@"  Format %d (%d segments) len=%d lang=%d searchRange=%d entrySelector=%d rangeShift=%d",
        f4h.format, segCount, f4h.length, f4h.language, f4h.searchRange, f4h.entrySelector, f4h.rangeShift);*/
  endCodes = (uint16_t*)subtableAddr;
  // Count past segCount of unsigned short, and a padding of one unsigned short
  subtableAddr += f4h.segCountX2 + 2;
  startCodes = (uint16_t*)subtableAddr;
  subtableAddr += f4h.segCountX2;
  idDeltas = (uint16_t*)subtableAddr;
  subtableAddr += f4h.segCountX2;
  idRangeOffsets = (uint16_t*)subtableAddr;
  //subtableAddr += f4h.segCountX2;
  //glyphIndices = (uint16_t*)subtableAddr;
  // Find first end code >= character of interest
  // If there are 4 segments, this ends after the third (fourth is terminator).
  for (j = 0; j < segCount; j++)
  {
    uint16_t endCode = CFSwapInt16BigToHost(endCodes[j]);
    uint16_t startCode = CFSwapInt16BigToHost(startCodes[j]);
    //printf("  j=%ld start=%lX end=%lX\n", j, startCode, endCode);
    if (endCode >= chr)
    {
      if (startCode <= chr)
      {
        // version 0.9: be more careful about swapping EVERYTHING we read from memory.
        uint16_t idRangeOffset = CFSwapInt16BigToHost(idRangeOffsets[j]);
        uint16_t glyphIndex = 0;
        uint16_t idDelta = CFSwapInt16BigToHost(idDeltas[j]);
        if (idRangeOffset == 0) glyphIndex = (idDelta + chr) % 65536;
        else
        {
          uint16_t idr = CFSwapInt16BigToHost(*(idRangeOffset/2 + (chr - startCode) + &idRangeOffsets[j]));
          if (idr) glyphIndex = (idDelta + idr) % 65536;
        }
        if (glyphIndex) has = 1;
        break;
      }
      else break;
    }
  }
  return has;
}

typedef struct
{
  uint16_t format;
  uint16_t length;
  uint16_t language;
  uint16_t firstCode;
  uint16_t entryCount;
} Format6Header;
//#define kFormat6HeaderLength 10

// This code hasn't been tested.
// I have no Unicode fonts with type 6 tables (may not exist)
static int local_Format6HasChar(uint16_t chr, char *subtableAddr)
{
  int has = 0;
  Format6Header f6h;
  f6h.format = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f6h.length = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f6h.language = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f6h.firstCode = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f6h.entryCount = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  //subtableAddr += 2;
  if (f6h.firstCode <= chr && chr <= f6h.firstCode + f6h.length)
  {
    //uint16_t* gia = (uint16_t*)subtableAddr;
    //uint16_t glyph = CFSwapInt16BigToHost(gia[chr - f6h.firstCode]);
    //printf("\nYAY (6)!!! firstCode=%u entryCount=%u glyph=%u\n", f6h.firstCode, f6h.entryCount, glyph);
    has = 1;
  }
  return has;
}

typedef struct
{
  uint16_t format;
  uint16_t padding;
  uint32_t length; // includes header
  uint32_t language;
  uint32_t nGroups;
} Format12Header;
#define kFormat12HeaderLength 16

typedef struct
{
  uint32_t startCharCode;
  uint32_t endCharCode;
  uint32_t startGlyphCode;
} Format12Group;

static int local_Format12HasChar(uint16_t chr, char *subtableAddr)
{
  unsigned long j;
  int has = 0;
  Format12Header f12h;
  f12h.format = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f12h.padding = CFSwapInt16BigToHost(*(uint16_t*)subtableAddr);
  subtableAddr += 2;
  f12h.length = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
  subtableAddr += 4;
  f12h.language = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
  subtableAddr += 4;
  f12h.nGroups = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
  subtableAddr += 4;
  for (j = 0; j < f12h.nGroups; j++)
  {
    Format12Group grp;
    grp.startCharCode = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
    subtableAddr += 4;
    grp.endCharCode = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
    subtableAddr += 4;
    grp.startGlyphCode = CFSwapInt32BigToHost(*(uint32_t*)subtableAddr);
    subtableAddr += 4;
    if (chr <= grp.endCharCode && chr >= grp.startCharCode)
    {
      /*NSLog(@"local_Format12HasChar: YES with GROUP %ld (char codes %ld-%ld) glyph=%ld\n",
        j, grp.startCharCode, grp.endCharCode, grp.startGlyphCode);*/
      has = 1;
      break;
    }
  }
  return has;
}

/*
Copyright © 2005-2020 Brian S. Hall, BLUGS.COM LLC

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
