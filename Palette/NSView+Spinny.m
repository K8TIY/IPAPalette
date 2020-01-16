#import "NSView+Spinny.h"

@interface HackedProgressIndicator : NSProgressIndicator
{
  NSInteger _tag;
}
@property (assign) NSInteger tag;
@end

@implementation HackedProgressIndicator
@synthesize tag = _tag;
@end

@implementation NSView (Spinny)
-(void)embedSpinny
{
  HackedProgressIndicator* spinny = [self viewWithTag:0xABCDEF];
  if (spinny) return;
  spinny = [[HackedProgressIndicator alloc] init];
  [spinny setControlSize:NSControlSizeRegular]; // aka NSRegularControlSize
  [spinny setStyle:NSProgressIndicatorSpinningStyle];
  NSRect bounds = [self bounds];
  NSRect piFrame = NSMakeRect(bounds.size.width / 2.0,
                              bounds.size.height / 2.0,
                              0.0, 0.0);
  [spinny setFrame:piFrame];
  [spinny setIndeterminate:YES];
  [spinny setDisplayedWhenStopped:NO];
  [spinny setBezeled:NO];
  [spinny setAutoresizingMask:(NSViewMaxXMargin | NSViewMinXMargin |
                               NSViewMaxYMargin | NSViewMinYMargin)]; 
  [spinny sizeToFit];
  piFrame = [spinny frame];
  piFrame.origin.x -= (piFrame.size.width / 2.0);
  piFrame.origin.y -= (piFrame.size.height / 2.0);
  [spinny setFrame:piFrame];
  [spinny sizeToFit];
  [spinny setTag:0xABCDEF];
  [self addSubview:spinny];
  [spinny release];
  [spinny startAnimation:self];
}

-(void)unembedSpinny
{
  NSProgressIndicator* spinny = [self viewWithTag:0xABCDEF];
  if (spinny)
  {
    [spinny stopAnimation:self];
    [spinny removeFromSuperview];
    [self setNeedsDisplay:YES];
  }
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
