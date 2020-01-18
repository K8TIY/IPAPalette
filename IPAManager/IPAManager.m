/*
NOTE: portions of an earlier version of this code is shamelessly stolen
from the Perian QuickTime component collection. Some of which in thrn was\
shamelessly stolen from an older version of Sparkle.
*/
#import "IPAManager.h"
#import "Onizuka.h"
#import "NSApplication+DarkMode.h"
#import "Sparkle/Sparkle.h"


@interface IPAManager (private)
+(CFStringRef)managerID;
+(CFStringRef)paletteID;
-(NSString*) _realHomeDirectory;
-(NSString*)_inputMethodsPath;
-(NSString*)_paletteAppPath;
-(NSString*)_archiveAppPath;
-(IPAInstallStatus)_installStatus;
-(void)_checkForInstallation;
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

+(NSString*)installationBasePath
{
  NSString* root = NSHomeDirectory();
  return [root stringByAppendingPathComponent:@"Input Methods"];
}

-(id)init
{
  if ((self = [super init]) != nil)
  {
    // On Snow Leopard and later we try to use IPAIconTemplate.pdf as the input
    // method icon. Revert the plist to IPAIcon.tif if Leopard is detected.
    SInt32 major = 0;
    SInt32 minor = 0;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    _osVersion = major + ((double)minor/10.0);
  }
  return self;
}

-(void)dealloc
{
  if (_error) [_error release];
  [super dealloc];
}

-(void)awakeFromNib
{
  [[Onizuka sharedOnizuka] localizeMenu:[[NSApplication sharedApplication] mainMenu]];
  [[Onizuka sharedOnizuka] localizeWindow:_window];
  [self _checkForInstallation];
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  if ([defs boolForKey:@"IPAMWillUpdate"])
  {
    [self _update:self];
    [defs setBool:NO forKey:@"IPAMWillUpdate"];
  }
  if ([NSApplication isDarkMode])
  {
    [_vowelChart setImage:[NSImage imageNamed:@"Vow_dk"]];
  }
  [_window makeKeyAndOrderFront:self];
}

#pragma mark Private Functions

#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <assert.h>

-(NSString*) _realHomeDirectory
{
  struct passwd* pw = getpwuid(getuid());
  assert(pw);
  return [NSString stringWithUTF8String:pw->pw_dir];
}

-(NSString*)_inputMethodsPath
{
  return [[self _realHomeDirectory]
                stringByAppendingPathComponent:@"Library/Input Methods"];
}

-(NSString*)_paletteAppPath
{
  return [[self _inputMethodsPath]
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
  path = [self _paletteAppPath];
  infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
  _installedVersion = @"";
  _installedVersionHR = @"";
  if (infoDict != nil)
  {
    _installedVersion = [infoDict objectForKey:@"CFBundleVersion"];
    _installedVersionHR = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSComparisonResult res = [currentVersion compare:_installedVersion options:NSNumericSearch];
    if (res == NSOrderedDescending) ret = kIPAInstallStatusOutdated;
    else ret = kIPAInstallStatusInstalled;
  }
  return ret;
}

-(void)_checkForInstallation
{
  NSString* key = nil;
  NSString* bkey = nil;
  IPAInstallStatus installStatus = [self _installStatus];
  if (installStatus == kIPAInstallStatusNotInstalled)
  {
    key = @"__NOT_INSTALLED__";
    bkey = @"__INSTALL__";
  }
  else if (installStatus == kIPAInstallStatusOutdated)
  {
    key = @"__INSTALLED_OUTDATED__";
    bkey = @"__UPDATE__";
  }
  else
  {
    key = @"__INSTALLED__";
    bkey = @"__UNINSTALL__";
  }
  if (_error)
  {
    [_errorField setStringValue:[_error localizedDescription]];
  }
  Onizuka* oz = [Onizuka sharedOnizuka];
  if (key != nil) [oz localizeObject:_infoField withTitle:key];
  if (bkey != nil) [oz localizeObject:_installButton withTitle:bkey];
  NSString* ver = @"";
  if ([_installedVersionHR length] && [_installedVersion length])
    ver = [NSString stringWithFormat:@"%@ (%@)", _installedVersionHR, _installedVersion];
  [_version setStringValue:ver];
  [_installButton setEnabled:YES];
}

#pragma mark Install/Uninstall
-(BOOL)_installArchive
{
  BOOL ret = YES;
  IPAInstallStatus status = [self _installStatus];
  if (status != kIPAInstallStatusInstalled)
  {
    NSError* err = nil;
    NSString* archivePath = [self _archiveAppPath];
    NSString* palette = [self _paletteAppPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    ret = [fm copyItemAtPath:archivePath toPath:palette
              error:&err];
    if (!ret && err)
    {
      _error = [err retain];
    }
  }
  return ret;
}

-(void)_install:(id)sender
{
  #pragma unused (sender)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  if ([self _installArchive])
  {
    NSString* path = [self _paletteAppPath];
    [self performSelectorOnMainThread:@selector(_register:)
          withObject:path waitUntilDone:YES];
  }
  [self performSelectorOnMainThread:@selector(_installComplete:) withObject:nil
        waitUntilDone:NO];
  [arp release];
}

-(void)_uninstall:(id)sender
{
  #pragma unused (sender)
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  NSFileManager* fm = [NSFileManager defaultManager];
  NSError* err = nil;
  [self performSelectorOnMainThread:@selector(_setPaletteEnabled:)
        withObject:(id)kCFBooleanFalse waitUntilDone:YES];
  NSString* componentPath = [self _paletteAppPath];
  BOOL ok = [fm removeItemAtPath:componentPath error:&err];
  if (!ok && err)
  {
    _error = [err retain];
  }
  else
  {
    system("killall IPAServer > /dev/null 2>&1");
    system("killall IPAPalette > /dev/null 2>&1");
  }
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
  if (_error) [_errorField setStringValue:[_error localizedDescription]];
  [self _checkForInstallation];
}

#pragma mark Action
-(IBAction)installUninstall:(id)sender
{
  #pragma unused (sender)
  if (_error)
  {
    [_error release];
    _error = nil;
  }
  IPAInstallStatus status = [self _installStatus];
  if (status == kIPAInstallStatusInstalled)
    [NSThread detachNewThreadSelector:@selector(_uninstall:) toTarget:self withObject:nil];
  else if (status == kIPAInstallStatusOutdated)
    [NSThread detachNewThreadSelector:@selector(_update:) toTarget:self withObject:nil];
  else
    [NSThread detachNewThreadSelector:@selector(_install:) toTarget:self withObject:nil];
}

#pragma mark TIS Functions
-(void)_register:(NSString*)path
{
  NSURL* url = [[NSURL alloc] initWithString:path];
  OSStatus status = noErr;
  if (url)
  {
    status = TISRegisterInputSource((CFURLRef)url);
    if (status != noErr)
    {
       NSDictionary* userInfo = @{NSLocalizedDescriptionKey:
                                [NSString stringWithFormat:@"TISRegisterInputSource: error %ld", (long)status]};
      _error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:status
                                userInfo:userInfo];
    }
    [url release];
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
    NSString* fn = nil;
    TISInputSourceRef me = (TISInputSourceRef)[list objectAtIndex:0L];
    CFBooleanRef selected = TISGetInputSourceProperty(me, kTISPropertyInputSourceIsSelected);
    if (flag == kCFBooleanTrue)
    {
      err = TISEnableInputSource(me);
      if (err == noErr)
      {
        if (_wasSelected)
        {
          err = TISSelectInputSource(me);
          if (err != noErr) fn = @"TISSelectInputSource";
        }
      }
      else
      {
        fn = @"TISEnableInputSource";
      }
    }
    else
    {
      if (selected == kCFBooleanTrue)
      {
        _wasSelected = YES;
        err = TISDeselectInputSource(me);
        if (err != noErr) fn = @"TISDeselectInputSource";
      }
      else _wasSelected = NO;
      if (err == noErr)
      {
        err = TISDisableInputSource(me);
        if (err != noErr)
        {
          fn = @"TISDisableInputSource";
        }
      }
    }
    if (err != noErr)
    {
       NSDictionary* userInfo = @{NSLocalizedDescriptionKey:
                                [NSString stringWithFormat:@"%@: error %ld", fn, (long)err]};
      _error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:err
                                userInfo:userInfo];
    }
  }
  [list release];
}

/*-(BOOL)_isFlagMenuEnabled
{
  BOOL flagMenu = NO;
  CFPropertyListRef sdefs =  CFPreferencesCopyAppValue(CFSTR("menuExtras"), CFSTR("com.apple.systemuiserver"));
  if ([(id)sdefs isKindOfClass:[NSArray class]])
  {
    for (NSString* str in (NSArray*)sdefs)
    {
      if ([str containsString:@"TextInput.menu"])
      {
        flagMenu = YES;
        break;
      }
    }
  }
  return flagMenu;
}*/

#pragma mark SUUpdater Delegate
-(void)updaterWillRelaunchApplication:(SUUpdater*)updater
{
  #pragma unused (updater)
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  [defs setBool:YES forKey:@"IPAMWillUpdate"];
}
@end

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
