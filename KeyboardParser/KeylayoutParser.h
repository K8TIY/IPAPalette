#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#ifndef __KEYLAYOUTPARSER_INCLUDE_DUMP__
#define __KEYLAYOUTPARSER_INCLUDE_DUMP__ 0
#endif

@interface KeylayoutParser : NSObject
{
  NSMutableDictionary* _modMap; // NSNumber -> Modifier seq
  NSMutableDictionary* _stateMap; // NSString (key seq) -> NSNumber
  UInt8*               _buff;
  UInt8                _kbType;
  
}
+(NSComparisonResult)compareKeyboardSequence:(NSString*)s1
                     withSequence:(NSString*)s2;
+(BOOL)isModifier:(unichar)ch;
-(unsigned)matchingKeyboardType;
-(void)parseKeyboardType:(unsigned)kbtype withObject:(id)obj
       selector:(SEL)selector;
-(NSString*)copySequenceForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx;
-(unichar)state0OutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
          nextState:(UInt16*)oNextState;
-(NSString*)copyOutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
            inState:(UInt16)state;
-(unsigned)countTerminatorsForKeyboardType:(unsigned)kbtype;
-(NSString*)copyTerminatorForKeyboardType:(unsigned)kbtype
            forState:(unsigned)state;
#if __KEYLAYOUTPARSER_INCLUDE_DUMP__
-(void)dumpKeyboardType:(unsigned)kbtype;
#endif
@end

char* VKKName(unsigned idx);
char* VKKSymbol(unsigned idx);

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
