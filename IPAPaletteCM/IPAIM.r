/*
Copyright © 2005-2010 Brian S. Hall
Portions may be Copyright © 2000-2001 Apple Computer, Inc.

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
#define UseExtendedThingResource 1
#include <Carbon/Carbon.r>

type 'cbnm'
{
  pstring;
};

resource 'thng' (128)
{
  'tsvc',
  'cplt',
  'blug',
  0x0,
  kAnyComponentFlagsMask,
  'dlle', -1,
  'STR ', -1,
  'STR ', -1,
  'ICON', -1,
  0x00010000,
  componentHasMultiplePlatforms | componentDoAutoVersion | componentWantsUnregister,
  -1,
  {
    0xFE00, 'dlle', -1, platformPowerPCNativeEntryPoint,
    0xFE00, 'dlle', -1, platformIA32NativeEntryPoint
  }
};

resource 'dlle' (-1)
{
  "IPAIMComponentDispatch"
};

resource 'STR ' (-1)
{
  "IPA Palette"
};

resource 'cbnm' (0, "Component Bundle Name", sysheap, purgeable)
{
  "com.blugs.IPAPalette"
};