/*
Copyright © 2009-2011 Brian S. Hall

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
#import "AppController.h"
#import "Placeholder.h"
#import "PDFImageMapCreator.h"
#include <CoreFoundation/CFDictionary.h>

@interface AppController (Private)
-(NSString*)outputLocationInDirectory:(NSString*)path file:(NSString*)file
                              writing:(BOOL)writing;
-(void)genPDFInDirectory:(NSString*)dir;
-(void)makeConsonantChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeVowelChartWithFrame:(BOOL)frame withXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeSupraToneChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeDiacriticChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeOtherChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeExtIPAChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeVPhChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makePalChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
-(void)makeRetroChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
@end

#define kStandardFontSize (26.0)
#define kSubviewFontSize (30.0)

typedef struct
{
  unichar voiceless;
  unichar voiced;
  // 0 if both possible, 1 if voiced impossible, (2 if voiceless), 3 if both
  int possibility;
} ConsInfo;

typedef struct
{
  unichar unrounded;
  unichar rounded;
  double x;
  double y;
} VowInfo;

#define kImgHeight   (256.0)
@implementation AppController
-(void)awakeFromNib
{
  [_window makeKeyAndOrderFront:self];
}

-(IBAction)doIt:(id)sender
{
  #pragma unused (sender)
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  [panel setMessage:@"Choose a directory to save the PDF and data files"];
  [panel setCanChooseFiles:NO];
  [panel setCanChooseDirectories:YES];
  NSInteger result = [panel runModal];
  if (result == NSOKButton)
  {
    NSString* dir = [panel filename];
    [_info setHidden:NO];
    [_spinny setHidden:NO];
    [_spinny setIndeterminate:YES];
    [_spinny startAnimation:self];
    [self genPDFInDirectory:dir];
    [_spinny stopAnimation:self];
    [_spinny setHidden:YES];
    [_info setStringValue:@"All done!"];
  }
  else [NSApp terminate:self];
}

-(void)genPDFInDirectory:(NSString*)dir
{
  NSMutableString* xml = [[NSMutableString alloc] initWithString:
    @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
  [xml appendString:
    @"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"\n"];
  [xml appendString:@"  \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"];
  [xml appendString:@"<plist version=\"1.0\">\n<array>"];
  [self makeConsonantChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_consButton state]];
  [self makeVowelChartWithFrame:YES withXML:xml inDirectory:dir
    writing:NSOnState == [_vowButton state]];
  [self makeVowelChartWithFrame:NO withXML:xml inDirectory:dir
    writing:NSOnState == [_vowDragButton state]];
  [self makeSupraToneChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_supraToneButton state]];
  [self makeDiacriticChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_diacriticButton state]];
  [self makeOtherChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_otherButton state]];
  [self makeExtIPAChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_extIPAButton state]];
  [self makeVPhChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_vPhButton state]];
  [self makePalChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_palButton state]];
  [self makeRetroChartWithXML:xml inDirectory:dir
    writing:NSOnState == [_retroButton state]];
  [xml appendString:@"</array>\n</plist>\n"];
  NSString* path = [dir stringByAppendingPathComponent:@"MapData.plist"];
  NSURL* url = [NSURL fileURLWithPath:path];
  NSData* data = [xml dataUsingEncoding:NSUTF8StringEncoding];
  [data writeToURL:url atomically:YES];
  [xml release];
}

NSString* plistStart = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"\n\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<array>";
NSString* plistEnd = @"</array>\n</plist>\n";

-(NSString*)outputLocationInDirectory:(NSString*)dir file:(NSString*)file
                                      writing:(BOOL)writing
{
  NSString* path = [dir stringByAppendingPathComponent:file];
  if (!writing)
  {
    NSString *tempFileTemplate =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"tf.XXXXXX"];
    const char* tfTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char* tfNameCString = (char*)malloc(strlen(tfTemplateCString) + 1);
    strcpy(tfNameCString, tfTemplateCString);
    mkstemp(tfNameCString);
    // This is the file name if you need to access the file by name, otherwise you can remove
    // this line.
    path = [[NSFileManager defaultManager]
             stringWithFileSystemRepresentation:tfNameCString
               length:strlen(tfNameCString)];
    free(tfNameCString);
  }
  NSLog(@"Using %@ for %@", path, file);
  return path;
}

#define kConsonantWidthPerHeight (2.90)
#define kConsonantMargin         (0.0)
#define kConsonantFontSize       (26.0)
-(void)makeConsonantChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  CGFloat width = kConsonantWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kConsonantMargin), kImgHeight+(2.0*kConsonantMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"Cons.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:nil];
  [creator setFontSize:kConsonantFontSize];
  [creator makeImageMapOfType:PDFImageMapConsonant named:@"Cons"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

#define kVowelWidthPerHeight (1.46)
//#define kVowelQuadWidth (287.0)
//#define kVowelQuadHeight (218.0)
//#define kVowelQuadOverhang (148.0)
//#define kVowelDotSize (9.0)
//#define kVowelFontSize (30.0)
// If not frame, this is the dragging-source-only supplementary image.
// Nothing is done to XML, and lines/dots are not drawn
-(void)makeVowelChartWithFrame:(BOOL)frame withXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  CGFloat width = kVowelWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width, kImgHeight);
  NSString* path = [self outputLocationInDirectory:dir file:(frame)? @"Vow.pdf":@"VowDrag.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:nil];
  [creator makeImageMapOfType:(frame)?PDFImageMapVowel:PDFImageMapFramelessVowel named:@"Vow"];
  CGContextRelease(ctx);
  if (frame) [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}


#define kSupraToneWidthPerHeight (0.8)
#define kSupraToneMargin (0.0)
//#define kSupraToneFontSize (28.0)
//#define kDottedCircle (0x25CC)
#define SupraToneDrawLines 0
-(void)makeSupraToneChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing;
{
  double width = kSupraToneWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kSupraToneMargin), kImgHeight+(2.0*kSupraToneMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"SupraTone.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xCC\x8B", @"\xCC\x81", @"\xCC\x84", @"\xCC\x80", @"\xCC\x8F", @"\xEA\x9C\x9B", @"\xEA\x9C\x9C", @"",
                                              @"\xCB\xA5", @"\xCB\xA6", @"\xCB\xA7", @"\xCB\xA8", @"\xCB\xA9", @"\xE2\x86\x97", @"\xE2\x86\x98", @"",
                                              @"\xCC\x8C", @"\xCC\x82", @"\xE1\xB7\x84", @"\xE1\xB7\x85", @"\xE1\xB7\x88", @"\xE1\xB7\x86", @"\xE1\xB7\x87", @"\xE1\xB7\x89",
                                              @"\xCB\x88", @"\xCB\x8C", @"\xCB\x90", @"\xCB\x91", @"\xCC\x86", @"\xE2\x80\xBF", @"\x7C", @"\xE2\x80\x96", NULL];
  NSArray* data = [glyphs slice:8];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kStandardFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"SupraTone"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}


#define kDiacriticWidthPerHeight (0.7)
#define kDiacriticMargin (0.0)
unichar diacritics[4][8] = {
    {0x0325,0x032C,0x0339,0x031C,0x031F,0x0320,0x0308,0x033D},
    {0x0329,0x032F,0x0324,0x0330,0x033C,0x02DE,0x0334,0x02BC},
    {0x031D,0x02D4,0x031E,0x02D5,0x0318,0x0319,0x0321,0x0322},
    {0x032A,0x033A,0x033B,0x0303,0x031A,0x0361,0x035C,0}
  };

-(void)makeDiacriticChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"Diacritic.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xCC\xA5", @"\xCC\xAC", @"\xCC\xB9", @"\xCC\x9C", @"\xCC\x9F", @"\xCC\xA0", @"\xCC\x88", @"\xCC\xBD",
                                              @"\xCC\xA9", @"\xCC\xAF", @"\xCC\xA4", @"\xCC\xB0", @"\xCC\xBC", @"\xCB\x9E", @"\xCC\xB4", @"\xCA\xBC",
                                              @"\xCC\x9D", @"\xCB\x94", @"\xCC\x9E", @"\xCB\x95", @"\xCC\x98", @"\xCC\x99", @"\xCC\xA1", @"\xCC\xA2",
                                              @"\xCC\xAA", @"\xCC\xBA", @"\xCC\xBB", @"\xCC\x83", @"\xCC\x9A", @"\xCD\xA1", @"\xCD\x9C", @"", NULL];
  NSArray* data = [glyphs slice:8];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setSubmap:@"VPh" forString:@"\xCC\xB4"];
  [creator setSubmap:@"Pal" forString:@"\xCC\xA1"];
  [creator setSubmap:@"Retro" forString:@"\xCC\xA2"];
  [creator setOverrideFont:@"HackedDoulos" forString:@"\xCC\xA1"];
  [creator setOverrideFont:@"HackedDoulos" forString:@"\xCC\xA2"];
  [creator setOverrideString:@"a" forString:@"\xCC\xA1"];
  [creator setOverrideString:@"b" forString:@"\xCC\xA2"];
  [creator setOverridePlaceholder:@"c" forString:@"\xCC\xA1"];
  [creator setOverridePlaceholder:@"c" forString:@"\xCC\xA2"];
  [creator setFontSize:kStandardFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"Diacritic"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

-(void)makeOtherChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"Other.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xCA\x98", @"\xC7\x80", @"\xC7\x83", @"\xC7\x82", @"\xC7\x81", @"", @"", @"",
                                              @"\xC9\x93", @"\xC9\x97", @"\xCA\x84", @"\xC9\xA0", @"\xCA\x9B", @"", @"", @"",
                                              @"\xCA\x8D", @"w", @"\xC9\xA5", @"\xCA\x9C", @"\xCA\xA2", @"\xCA\xA1", @"", @"",
                                              @"\xC9\x95", @"\xCA\x91", @"\xC9\xBA", @"\xC9\xA7", @"", @"", @"", @"", NULL];
  NSArray* data = [glyphs slice:8];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kStandardFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"Other"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

-(void)makeExtIPAChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kDiacriticWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"ExtIPA.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xCA\xAC", @"\xCA\xAD", @"\xCA\xAA", @"\xCA\xAB", @"\xCA\xA9", @"\xC2\xA1", @"\xC7\x83\xC2\xA1", @"\xE2\x80\xBC",
                                              @"\xCD\x8D", @"\xCD\x86", @"\xCD\x86\xCC\xAA", @"\xCD\x88", @"\xCD\x89", @"\xCD\x8E", @"\xCD\x8A", @"\xCD\x8B",
                                              @"\xCD\x8C", @"\xCD\x87", @"\xCD\xA2", @"\xCD\x94", @"\xCD\x95", @"\xEA\x9F\xB8", @"", @"",
                                              //@"\xCD\x8C", @"\xCD\x87", @"\xCD\xA2", @"\xCD\x94", @"\xCD\x95", @"", @"", @"",
                                              @"\xCB\xAD", @"\xE2\x82\x8D", @"\xE2\x82\x8E", @"\xCB\xAC", @"\xE2\x86\x91", @"\xE2\x86\x93", @"", @"",
                                              @"\xC5\x92", @"\xD0\xAE", @"\xD0\x98", @"\xCE\x98", @"\xCC\xA3", @"\xE2\x9D\x8D", NULL];
  NSArray* data = [glyphs slice:8];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kStandardFontSize];
  // FIXME: get rid of this when Doulos supports A7F8
  [creator setOverrideFont:@"HackedDoulosF" forString:@"\xEA\x9F\xB8"];
  [creator setOverridePlaceholder:@"\xEA\x9F\xB9" forString:@"\xEA\x9F\xB8"];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"ExtIPA"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

#define kVPhWidthPerHeight (0.35)
-(void)makeVPhChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kVPhWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"VPh.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xC9\xAB", @"\xE1\xB5\xAC", @"\xE1\xB5\xAD", @"\xE1\xB5\xAE", @"\xE1\xB5\xAF",
                                              @"\xE1\xB5\xB0", @"\xE1\xB5\xB1", @"\xE1\xB5\xB2", @"\xE1\xB5\xB3", @"\xE1\xB5\xB4",
                                              @"\xE1\xB5\xB5", @"\xE1\xB5\xB6", NULL];
  NSArray* data = [glyphs slice:6];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kSubviewFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"VPh"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

#define kPalWidthPerHeight (0.35)
-(void)makePalChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kPalWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"Pal.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xC6\xAB", @"\xE1\xB6\x80", @"\xE1\xB6\x81", @"\xE1\xB6\x82", @"\xE1\xB6\x83",
                                              @"\xE1\xB6\x84", @"\xE1\xB6\x85", @"\xE1\xB6\x86", @"\xE1\xB6\x87", @"\xE1\xB6\x88",
                                              @"\xE1\xB6\x89", @"\xE1\xB6\x8A", @"\xE1\xB6\x8B", @"\xE1\xB6\x8C", @"\xE1\xB6\x8D",
                                              @"\xE1\xB6\x8E", NULL];
  NSArray* data = [glyphs slice:6];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kSubviewFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"Pal"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}

#define kRetroWidthPerHeight (0.35)
-(void)makeRetroChartWithXML:(NSMutableString*)xml
       inDirectory:(NSString*)dir writing:(BOOL)writing
{
  double width = kPalWidthPerHeight*kImgHeight;
  CGRect imgRect = CGRectMake(0, 0, width+(2.0*kDiacriticMargin), kImgHeight+(2.0*kDiacriticMargin));
  NSString* path = [self outputLocationInDirectory:dir file:@"Retro.pdf" writing:writing];
  NSURL* url = [NSURL fileURLWithPath:path];
  CGContextRef ctx = CGPDFContextCreateWithURL((CFURLRef)url, &imgRect, NULL);
  NSArray* glyphs = [NSArray arrayWithObjects:@"\xE1\xB6\x8F", @"\xE1\xB6\x91", @"\xE1\xB6\x92", @"\xE1\xB6\x93", @"\xE1\xB6\x94",
                                              @"\xE1\xB6\x95", @"\xE1\xB6\x96", @"\xE1\xB6\x97", @"\xE1\xB6\x98", @"\xE1\xB6\x99",
                                              @"\xE1\xB6\x9A", NULL];
  NSArray* data = [glyphs slice:6];
  PDFImageMapCreator* creator = [[PDFImageMapCreator alloc] initWithContext:ctx rect:imgRect data:data];
  [creator setFontSize:kSubviewFontSize];
  [creator makeImageMapOfType:PDFImageMapColumnar named:@"Retro"];
  CGContextRelease(ctx);
  [xml appendString:[creator xmlWithContainer:NO]];
  [creator release];
}
@end
