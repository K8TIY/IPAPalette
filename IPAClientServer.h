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
#ifndef IPAClientServer_h
#define IPAClientServer_h

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

#define kIPAClientListenPortName @"com.blugs.IPAPalette.client"
#if __IPA_CM__
#define kIPAServerPortName "com.blugs.IPAServer"
#define kIPAServerListenPortName CFSTR("com.blugs.IPAServer")
#define kServerName CFSTR("IPAServerCM.app")
#define kBundleIdentifier CFSTR("com.blugs.IPAPalette")
#else
#define kIPAServerListenPortName @"com.blugs.IPAPalette.server"
#define kServerName CFSTR("IPAServer.app")
#define kBundleIdentifier CFSTR("com.blugs.inputmethod.IPAPalette")
#endif



typedef SInt32 IPAMessage;
enum
{
  ipaActivatedMsg = 100,   // Notify server that a text service was activated
  ipaActivatedShowOnlyMsg, // (CM only) Notify server that a text service was activated,
                           //   but tell it not to send input to SystemUIServer
  ipaHidePaletteMsg,       // Notify server that TSM sent a hide palettes request
  ipaWindowLevelMsg,       // (CM only) Set the window level above the Dashboard level
  ipaErrorMsg              // Send the text of an error message
};

enum
{
  ipaPaletteHiddenMsg = 201, // Notify IM that palette is hidden
  ipaFontMsg,                // Notify IM that next input should be in this font
  ipaInputMsg,               // Notify IM that a symbol was clicked
  ipaDebugMsg                // Notify IM of debug level
};

// Shared debug levels
enum
{
  ipaSilentDebugLevel,
  ipaDebugDebugLevel,
  ipaVerboseDebugLevel,
  ipaInsaneDebugLevel
};

#endif
