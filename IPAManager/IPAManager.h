/*
Copyright © 2009-2013 Brian S. Hall

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 or later as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Security/Security.h>

typedef enum
{
  kIPAInstallStatusInstalledInWrongLocation = 0,
  kIPAInstallStatusNotInstalled = 1,
  kIPAInstallStatusOutdatedWithAnotherInWrongLocation = 2,
  kIPAInstallStatusOutdated = 3,
  kIPAInstallStatusInstalledInBothLocations = 4,
  kIPAInstallStatusInstalled = 5
} IPAInstallStatus;

@interface IPAManager : NSObject
{
  IBOutlet NSWindow*    _window;
  IBOutlet NSTextField* _info;
  IBOutlet NSTextField* _version;
  IBOutlet NSButton*    _installButton;
  IBOutlet NSButton*    _allUsersButton;
  IPAInstallStatus      installStatus;
  NSString*             _installedVersion;
  NSString*             _installedVersionHR;
  double                _osVersion;
  BOOL                  _userInstalled;
  BOOL                  _wasSelected;
  AuthorizationRef      auth;
  NSString*             errorString;
}

-(IBAction)installUninstall:(id)sender;
@end
