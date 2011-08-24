#include <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>

int main(int argc, char *argv[])
{
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  NSString* path = @"/Library/Input Methods/IPAPalette.app";
  CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
  OSStatus status = noErr;
  if (url)
  {
    status = TISRegisterInputSource(url);
    NSLog(@"TISRegisterInputSource(%@): %d", url, status);
    CFRelease(url);
  }
  path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Input Methods/IPAPalette.app"];
  url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, true);
  if (url)
  {
    status = TISRegisterInputSource(url);
    NSLog(@"TISRegisterInputSource(%@): %d", url, status);
    CFRelease(url);
  }
  [arp release];
  system("killall IPAServer");
  system("killall IPAPalette");
  return status;
}
