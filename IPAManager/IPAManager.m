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

/*
NOTE: much of this code is shamelessly stolen from the Perian
QuickTime component collection. Some of which in thrn was shamelessly
stolen from an older version of Sparkle.
*/
#import "IPAManager.h"
#import "Onizuka.h"
#import "Sparkle/Sparkle.h"

static inline IPAInstallStatus currentInstallStatus(IPAInstallStatus status);
static inline BOOL isWrongLocationInstalled(IPAInstallStatus status);
static inline IPAInstallStatus setWrongLocationInstalled(IPAInstallStatus status);

@interface IPAManager (private)
+(CFStringRef)managerID;
+(CFStringRef)paletteID;
-(NSString*)_installationBasePath:(BOOL)userInstallation;
-(NSString*)_inputMethodsPath:(BOOL)userInstallation;
-(NSString*)_paletteAppPath:(BOOL)userInstallation;
-(NSString*)_archiveAppPath;
-(IPAInstallStatus)_installStatus;
-(void)_checkForInstallation;
-(BOOL)_extractArchivePath:(NSString*)archivePath
       toDestination:(NSString*)destination finalPath:(NSString*)finalPath;
-(BOOL)_authenticatedExtractArchivePath:(NSString*)archivePath
       toDestination:(NSString*)destination finalPath:(NSString*)finalPath;
-(BOOL)_authenticatedRemove:(NSString*)componentPath;
-(BOOL)_installArchive;
-(void)_install:(id)sender;
-(void)_uninstall:(id)sender;
-(void)_update:(id)sender;
-(void)_installComplete:(id)sender;
-(void)_register:(NSString*)path;
-(void)_setPaletteEnabled:(CFBooleanRef)flag;
@end

@implementation IPAManager
+(CFStringRef)managerID
{
  return CFSTR("com.blugs.IPAManager");
}

+(CFStringRef)paletteID
{
  return CFSTR("com.blugs.inputmethod.IPAPalette");
}

+(NSString*)installationBasePath:(BOOL)userInstallation
{
  NSString* root = (userInstallation)? NSHomeDirectory():@"/";
  return [root stringByAppendingPathComponent:@"Input Methods"];
}

-(id)init
{
  if ((self = [super init]) != nil)
  {
    _userInstalled = YES;
    NSString* path = @"/Library/Input Methods/IPAPalette.app";
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
      _userInstalled = NO;
    }
    // On Snow Leopard and later we try to use IPAIconTemplate.pdf as the input
    // method icon. Revert the plist to IPAIcon.tif if Leopard is detected.
    SInt32 major = 0;
    SInt32 minor = 0;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    _osVersion = major + ((double)minor/10.0);
    //NSLog(@"OS Version %f", _osVersion);
  }
  return self;
}

-(void)dealloc
{
  if (auth != nil) AuthorizationFree(auth, 0);
  [errorString release];
  [super dealloc];
}


-(void)awakeFromNib
{
  [[Onizuka sharedOnizuka] localizeMenu:[[NSApplication sharedApplication] mainMenu]];
  [[Onizuka sharedOnizuka] localizeWindow:_window];
  [self _checkForInstallation];
  if (!_userInstalled) [_allUsersButton setState:NSOnState];
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  if ([defs boolForKey:@"IPAMWillUpdate"])
  {
    [self _update:self];
    [defs setBool:NO forKey:@"IPAMWillUpdate"];
  }
  [_window makeKeyAndOrderFront:self];
  
}

#pragma mark Private Functions
-(NSString*)_installationBasePath:(BOOL)userInstallation
{
  if (userInstallation) return NSHomeDirectory();
  return @"/";
}

-(NSString*)_inputMethodsPath:(BOOL)userInstallation
{
  return [[self _installationBasePath:userInstallation]
             stringByAppendingPathComponent:@"Library/Input Methods"];
}

-(NSString*)_paletteAppPath:(BOOL)userInstallation
{
  return [[self _inputMethodsPath:userInstallation]
             stringByAppendingPathComponent:@"IPAPalette.app"];
}

-(NSString*)_archiveAppPath
{
  NSString* supportPath = [[NSBundle mainBundle] sharedSupportPath];
  return [supportPath stringByAppendingPathComponent:@"IPAPalette.app"];
}

-(IPAInstallStatus)_installStatus
{
  IPAInstallStatus ret = kIPAInstallStatusNotInstalled;
  NSString* path = [self _archiveAppPath];
  NSString* currentVersion = @"";
  NSDictionary* infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
  if (infoDict != nil)
  {
    currentVersion = [infoDict objectForKey:@"CFBundleVersion"];
  }
  path = [self _paletteAppPath:_userInstalled];
  infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
  _installedVersion = @"";
  _installedVersionHR = @"-";
  if (infoDict != nil)
  {
    _installedVersion = [infoDict objectForKey:@"CFBundleVersion"];
    _installedVersionHR = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSComparisonResult res = [currentVersion compare:_installedVersion options:NSNumericSearch];
    //NSLog(@"Current %@, installed %@, result %s", currentVersion, _installedVersion,
    //      (res == NSOrderedAscending)? "NSOrderedAscending":((res == NSOrderedDescending)? "NSOrderedDescending":"NSOrderedSame"));
    if (res == NSOrderedDescending) ret = kIPAInstallStatusOutdated;
    else ret = kIPAInstallStatusInstalled;
  }
  /* Check other installation type */
  path = [self _paletteAppPath:!_userInstalled];
  infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
  if (infoDict == nil)
    /* Above result is all there is */
    return ret;
  return setWrongLocationInstalled(ret);
}

-(void)_checkForInstallation
{
  NSString* key = nil;
  NSString* bkey = nil;
  installStatus = [self _installStatus];
  if (currentInstallStatus(installStatus) == kIPAInstallStatusNotInstalled)
  {
    key = @"__NOT_INSTALLED__";
    bkey = @"__INSTALL__";
  }
  else if (currentInstallStatus(installStatus) == kIPAInstallStatusOutdated)
  {
    key = @"__INSTALLED_OUTDATED__";
    bkey = @"__UPDATE__";
  }
  else if (isWrongLocationInstalled(installStatus))
  {
    key = @"__INSTALLED_TWICE__";
    bkey = @"__FIX__";
  }
  else
  {
    key = @"__INSTALLED__";
    bkey = @"__UNINSTALL__";
  }
  if (errorString)
  {
    [_info setStringValue:[NSString stringWithFormat:@"Error: %@", errorString]];
  }
  Onizuka* oz = [Onizuka sharedOnizuka];
  if (key != nil) [oz localizeObject:_info withTitle:key];
  if (bkey != nil) [oz localizeObject:_installButton withTitle:bkey];
  NSString* ver = [NSString stringWithFormat:@"%@ (%@)", _installedVersionHR, _installedVersion];
  [_version setStringValue:ver];
  [_installButton setEnabled:YES];
}

#pragma mark Install/Uninstall

/* Shamelessly ripped from Sparkle (and now different) */
-(BOOL)_extractArchivePath:(NSString*)archivePath
       toDestination:(NSString*)destination finalPath:(NSString*)finalPath
{
  BOOL ret = NO, oldExist;
  NSFileManager* defaultFileManager = [NSFileManager defaultManager];
  char* cmd;
  oldExist = [defaultFileManager fileExistsAtPath:finalPath];
  if (oldExist)
    cmd = "rm -rf \"$DST_COMPONENT\" && "
    "mkdir -p \"$DST_COMPONENT\" && "
    "ditto --rsrc \"$SRC_ARCHIVE\" \"$DST_COMPONENT\"";
  else
    cmd = "mkdir -p \"$DST_COMPONENT\" && "
    "ditto --rsrc \"$SRC_ARCHIVE\" \"$DST_COMPONENT\"";
  setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
  setenv("DST_PATH", [destination fileSystemRepresentation], 1);
  setenv("DST_COMPONENT", [finalPath fileSystemRepresentation], 1);
  int status = system(cmd);
  if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
    ret = YES;
  else
    errorString = [[NSString alloc] initWithFormat:@"extraction of %@ failed\n",
                                    [finalPath lastPathComponent]];
  unsetenv("SRC_ARCHIVE");
  unsetenv("DST_COMPONENT");
  unsetenv("DST_PATH");
  return ret;
}

-(BOOL)_authenticatedExtractArchivePath:(NSString*)archivePath
       toDestination:(NSString*)destination finalPath:(NSString*)finalPath
{
  BOOL ret = NO, oldExist;
  NSFileManager* defaultFileManager = [NSFileManager defaultManager];
  char* cmd;
  oldExist = [defaultFileManager fileExistsAtPath:finalPath];
  if (oldExist)
    cmd = "rm -rf \"$DST_COMPONENT\" && "
    "mkdir -p \"$DST_COMPONENT\" && "
    "ditto --rsrc \"$SRC_ARCHIVE\" \"$DST_COMPONENT\"";
  else
    cmd = "mkdir -p \"$DST_COMPONENT\" && "
    "ditto --rsrc \"$SRC_ARCHIVE\" \"$DST_COMPONENT\"";
  setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
  setenv("DST_COMPONENT", [finalPath fileSystemRepresentation], 1);
  setenv("DST_PATH", [destination fileSystemRepresentation], 1);
  char* const arguments[] = { "-c", cmd, NULL };
  if (auth && AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
  {
    int status;
    int pid = wait(&status);
    if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
      ret = YES;
    else
      errorString = [[NSString stringWithFormat:@"extraction of %@ failed\n", [finalPath lastPathComponent]] retain];
  }
  else
    errorString = [[NSString stringWithFormat:@"authentication failed while extracting %@\n", [finalPath lastPathComponent]] retain];
    
  unsetenv("SRC_ARCHIVE");
  unsetenv("DST_COMPONENT");
  unsetenv("DST_PATH");
  return ret;
}

-(BOOL)_authenticatedRemove:(NSString*)componentPath
{
  BOOL ret = NO;
  NSFileManager* defaultFileManager = [NSFileManager defaultManager];
  if(![defaultFileManager fileExistsAtPath:componentPath])
    return YES; // No error, just forget it
  char* cmd = "rm -rf \"$COMP_PATH\"";
  setenv("COMP_PATH", [componentPath fileSystemRepresentation], 1);
  char* const arguments[] = { "-c", cmd, NULL };
  if(auth && AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
  {
    int status;
    int pid = wait(&status);
    if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
      ret = YES;
    else
      errorString = [[NSString stringWithFormat:@"removal of %@ failed\n", [componentPath lastPathComponent]] retain];
  }
  else
    errorString = [[NSString stringWithFormat:@"authentication failed while removing %@\n", [componentPath lastPathComponent]] retain];
  unsetenv("COMP_PATH");
  return ret;
}

-(BOOL)_installArchive
{
  NSString* archivePath = [self _archiveAppPath];
  NSString* containingDir = [self _inputMethodsPath:_userInstalled];
  NSString* palette = [self _paletteAppPath:_userInstalled];
  BOOL ret = YES;

  IPAInstallStatus status = [self _installStatus];
  if (!_userInstalled && currentInstallStatus(status) != kIPAInstallStatusInstalled)
  {
    BOOL result = [self _authenticatedExtractArchivePath:archivePath toDestination:containingDir finalPath:palette];
    if (result == NO) ret = NO;
  }
  else
  {
    if (currentInstallStatus(status) != kIPAInstallStatusInstalled)
    {
      //Decompress and install new one
      BOOL result = [self _extractArchivePath:archivePath toDestination:containingDir finalPath:palette];
      if (result == NO) ret = NO;
    }    
  }
  if (ret != NO && isWrongLocationInstalled(status) != 0)
  {
    /* Let's try and remove the wrong one, if we can, but only if install succeeded */
    palette = [self _paletteAppPath:!_userInstalled];
    if (_userInstalled)
      ret = [self _authenticatedRemove:palette];
    else
    {
      ret = [[NSFileManager defaultManager] removeItemAtPath:palette error:nil];
      if (ret == NO)
        errorString = [[NSString alloc] initWithString:@"removal of duplicate failed\n"];
    }
  }
  return ret;
}

-(void)_install:(id)sender
{
  #pragma unused (sender)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  [errorString release];
  errorString = nil;
  /* This doesn't ask the user, so create it anyway.  If we don't need it, no problem */
  if (AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) != errAuthorizationSuccess)
    /* Oh well, hope we don't need it */
    auth = nil;
  [self _installArchive];
  if (auth != nil)
  {
    AuthorizationFree(auth, 0);
    auth = nil;
  }
  NSString* path = [self _paletteAppPath:_userInstalled];
  [self performSelectorOnMainThread:@selector(_register:)
        withObject:path waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(_installComplete:) withObject:nil waitUntilDone:NO];
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  /* FIXME: should also do a defaults read on 
     com.apple.systemuiserver and look for
     {
        menuExtras = (
            "/System/Library/CoreServices/Menu Extras/TextInput.menu",
            ...)
     }
     But need to check for OS version variation on this.
  */
  if (_osVersion < 10.9 && ![defs boolForKey:@"IPAMHaveOpenedPrefs"])
  {
    NSString* path = [[NSBundle mainBundle] pathForResource:@"ActivatePrefs" ofType:@"scpt"];
    NSString* cmd = [NSString stringWithFormat:@"osascript \"%@\" > /dev/null 2>&1", path];
    //NSLog(@"Command: >>>%@<<<", cmd);
    system([cmd UTF8String]);
    [defs setBool:YES forKey:@"IPAMHaveOpenedPrefs"];
  }
  [arp release];
}

-(void)_uninstall:(id)sender
{
  #pragma unused (sender)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSError* err = nil;
  [self performSelectorOnMainThread:@selector(_setPaletteEnabled:)
        withObject:(id)kCFBooleanFalse waitUntilDone:YES];
  [errorString release];
  errorString = nil;
  /* This doesn't ask the user, so create it anyway.  If we don't need it, no problem */
  if (AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
      kAuthorizationFlagDefaults, &auth) != errAuthorizationSuccess)
    /* Oh well, hope we don't need it */
    auth = nil;
  NSString* componentPath = [self _paletteAppPath:_userInstalled];
  BOOL ok = YES;
  if (auth != nil && !_userInstalled)
    ok = [self _authenticatedRemove:componentPath];
  else
    ok = [fileManager removeItemAtPath:componentPath error:&err];
  if (!ok && err)
  {
    [_info setStringValue:[err localizedDescription]];
  }
  if (auth != nil)
  {
    AuthorizationFree(auth, 0);
    auth = nil;
  }
  system("killall IPAServer > /dev/null 2>&1");
  system("killall IPAPalette > /dev/null 2>&1");
  [self performSelectorOnMainThread:@selector(_installComplete:) withObject:nil
        waitUntilDone:NO];
  [arp release];
}

-(void)_update:(id)sender
{
  #pragma unused (sender)
  [self _uninstall:self];
  [self _install:self];
}

-(void)_installComplete:(id)sender
{
  #pragma unused (sender)
  [self _checkForInstallation];
}

#pragma mark Action
-(IBAction)installUninstall:(id)sender
{
  #pragma unused (sender)
  _userInstalled = ([_allUsersButton state] != NSOnState);
  if (installStatus == kIPAInstallStatusInstalled)
    [NSThread detachNewThreadSelector:@selector(_uninstall:) toTarget:self withObject:nil];
  else if (currentInstallStatus(installStatus) == kIPAInstallStatusOutdated)
    [NSThread detachNewThreadSelector:@selector(_update:) toTarget:self withObject:nil];
  else
    [NSThread detachNewThreadSelector:@selector(_install:) toTarget:self withObject:nil];
}

#pragma TIS Functions
-(void)_register:(NSString*)path
{
  CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
  OSStatus status = noErr;
  if (url)
  {
    status = TISRegisterInputSource(url);
    if (status) errorString = [[NSString alloc] initWithFormat:@"TISRegisterInputSource(%@): %ld", url, (long)status];
    CFRelease(url);
    [self _setPaletteEnabled:kCFBooleanTrue];
  }
}

-(void)_setPaletteEnabled:(CFBooleanRef)flag
{
  NSMutableDictionary* filter = [[NSMutableDictionary alloc] init];
  [filter setObject:(id)[IPAManager paletteID] forKey:(id)kTISPropertyBundleID];
  NSArray* list = (NSArray*)TISCreateInputSourceList((CFDictionaryRef)filter, true);
  [filter release];
  if ([list count])
  {
    OSStatus err = noErr;
    TISInputSourceRef me = (TISInputSourceRef)[list objectAtIndex:0L];
    CFBooleanRef selected = TISGetInputSourceProperty(me, kTISPropertyInputSourceIsSelected);
    if (flag == kCFBooleanTrue)
    {
      err = TISEnableInputSource(me);
      if (_wasSelected) err = TISSelectInputSource(me);
    }
    else
    {
      if (selected == kCFBooleanTrue)
      {
        _wasSelected = YES;
        err = TISDeselectInputSource(me);
        if (err != noErr) NSLog(@"TISDeselectInputSource: error %d", (int)err);
      }
      else _wasSelected = NO;
      err = TISDisableInputSource(me);
    } 
    if (err != noErr) NSLog(@"TIS*ableInputSource: error %d", (int)err);
  }
  [list release];
}

#pragma mark SUUpdater Delegate
-(void)updaterWillRelaunchApplication:(SUUpdater*)updater
{
  #pragma unused (updater)
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  [defs setBool:YES forKey:@"IPAMWillUpdate"];
}
@end

static inline IPAInstallStatus currentInstallStatus(IPAInstallStatus status)
{
  return (status | 1);
}

static inline BOOL isWrongLocationInstalled(IPAInstallStatus status)
{
  return ((status & 1) == 0);
}

static inline IPAInstallStatus setWrongLocationInstalled(IPAInstallStatus status)
{
  return (status & ~1);
}
