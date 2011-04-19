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
          (ch == 0x2071 || ch == 0x207F)    // Superscripts and subscripts
  );
}
