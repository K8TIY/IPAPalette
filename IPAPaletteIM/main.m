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
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "IPAClientServer.h"

unsigned gDebugLevel = ipaInsaneDebugLevel;

int main(int argc, char *argv[])
{
  #pragma unused(argc,argv)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
  IMKServer* server = [[IMKServer alloc] initWithName:@"IPAPalette_1_Connection" bundleIdentifier:identifier];
  //load the bundle explicitly because in this case the input method is a background only application 
	[NSBundle loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication]];
	[[NSApplication sharedApplication] run];
	[server release];
  [arp release];
  return 0;
}
