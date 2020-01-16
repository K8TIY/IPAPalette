#include "Placeholder.h"

const unsigned short PlaceholderDottedCircle = 0x25CC;
// Returns 1 for nonspacing characters and, generally, for
// characters such as diacritics that do not touch the baseline
// but look like they could.
int NeedsPlaceholder(unsigned short ch)
{
  return ((ch >= 0x0300 && ch <= 0x036F) || // Combining diacritical marks
          (ch >= 0x20D0 && ch <= 0x20FF) || // Combining Marks for Symbols
          (ch >= 0xFE20 && ch <= 0xFE2F) || // Combining Half Marks
          (ch >= 0x1DC0 && ch <= 0x1DFF) || // Combining Diacritical Marks Supplement
          (ch >= 0x1D9B && ch <= 0x1DBF) || // Superscripts from Phonetic Extensions Supplement
          (ch >= 0x02B0 && ch <= 0x02B8) || // Superscripts from Spacing Modifier Letters
          (ch == 0x02BC || ch == 0x02DE) || // Ditto
          (ch >= 0x02C0 && ch <= 0x02C1) || // Ditto
          (ch >= 0x02E0 && ch <= 0x02E4) || // Ditto
          (ch >= 0x1D2C && ch <= 0x1D6A) || // Phonetic Extensions -- super and sub (just in case)
          (ch == 0x2071 || ch == 0x207F) || // Superscripts and subscripts
          (ch == 0xA7F8 || ch == 0xA7F9)    // Superscripts from Latin Extended D (Unicode 6.1)
  );
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
