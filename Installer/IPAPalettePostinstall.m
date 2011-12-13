#include <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <sys/stat.h>

int main(int argc, char *argv[])
{
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  /*unsigned i;
  for (i = 0; i < argc; i++)
  NSLog(@"argv[%d] '%s'", i, argv[i]);*/
  // Param 2 is the path to the destination, sans trailing slash.*/
  NSMutableString* path = [[NSMutableString alloc] initWithFormat:@"%s", argv[2]];
  // On Snow Leopard and later we try to use IPAIconTemplate.pdf as the input
  // method icon. Revert the plist to IPAIcon.tif if Leopard is detected.
  SInt32 major = 0;
  SInt32 minor = 0;   
  Gestalt(gestaltSystemVersionMajor, &major);
  Gestalt(gestaltSystemVersionMinor, &minor);
  if (major == 10 && minor == 5)
  {
    NSMutableString* plistPath = [path mutableCopy];
    [plistPath appendString:@"/Contents/Info"];
    NSString* cmd = [NSString stringWithFormat:@"defaults write \"%@\" tsInputMethodIconFileKey IPAIcon.tif", plistPath];
    [plistPath appendString:@".plist"];
    const char* file = [plistPath UTF8String];
    struct stat st;
    stat(file, &st);
    uid_t usr = st.st_uid;
    gid_t grp = st.st_gid;
    mode_t md = st.st_mode;
    NSLog(@"Command: >>>%@<<<", cmd);
    system([cmd UTF8String]);
    NSLog(@"Leopard detected; trying to swap in tiff menu icon. (%d,%d,%d)", usr, grp, md);
    int err = chmod(file, md);
    /*if (err)*/ NSLog(@"chmod %s -> %d error %d (%s)", file, md, err, strerror(err));
    err = chown(file, usr, grp);
    /*if (err)*/ NSLog(@"chown %s -> %d,%d error %d (%s)", file, usr, grp, err, strerror(err));
    [plistPath release];
  }
  CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
  OSStatus status = noErr;
  if (url)
  {
    status = TISRegisterInputSource(url);
    NSLog(@"TISRegisterInputSource(%@): %d", url, status);
    CFRelease(url);
  }
  system("killall IPAServer");
  system("killall IPAPalette");
  [path release];
  [arp release];
  return status;
}
