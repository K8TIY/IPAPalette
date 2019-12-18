#import <Cocoa/Cocoa.h>
#import "PDFImageMap.h"

@interface AppController : NSObject
{
  IBOutlet NSProgressIndicator* _spinny;
  IBOutlet NSTextField* _info;
  IBOutlet NSWindow* _window;
  
  IBOutlet NSButton* _vowButton;
  IBOutlet NSButton* _vowDragButton;
  IBOutlet NSButton* _supraToneButton;
  IBOutlet NSButton* _consButton;
  IBOutlet NSButton* _diacriticButton;
  IBOutlet NSButton* _palButton;
  IBOutlet NSButton* _retroButton;
  IBOutlet NSButton* _vPhButton;
  IBOutlet NSButton* _otherButton;
  IBOutlet NSButton* _extIPAButton;
  
  NSMutableString*   _xml;
}

-(IBAction)doIt:(id)sender;
@end

/*
Copyright © 2005-2019 Brian S. Hall, BLUGS.COM LLC

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
