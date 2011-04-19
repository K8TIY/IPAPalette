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
#ifndef IPAIM_h
#define IPAIM_h
#include <Carbon/Carbon.h>
#include "IPAClientServer.h"

typedef struct
{
  ComponentInstance _comp;
  ATSUFontID        _font;
} IPAIMSessionRecord, **IPAIMSessionHandle;
extern IPAIMSessionHandle gActiveSession;
extern unsigned gDebugLevel;


ComponentResult IPAIMInitialize(ComponentInstance inComponentInstance);
ComponentResult IPAIMSessionOpen(ComponentInstance inComponentInstance, 
                                 IPAIMSessionHandle *outSessionHandle);
OSStatus IPAInitMessageReceiving(void);
OSStatus IPAIMLaunchServer(void);
OSStatus IPASendMessage(IPAMessage inMessage, CFDataRef inData);
void IPALog(char* fmt, ...);
#endif
