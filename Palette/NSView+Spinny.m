/*
Copyright © 2005-2012 Brian S. Hall

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
