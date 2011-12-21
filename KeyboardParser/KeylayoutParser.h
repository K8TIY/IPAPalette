/*
Copyright © 2011 Brian S. Hall

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
-(void)parseKeyboardType:(unsigned)kbtype withObject:(id)obj selector:(SEL)selector;
-(NSString*)copySequenceForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx;
-(unichar)state0OutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
          nextState:(UInt16*)oNextState;
-(NSString*)copyOutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
            inState:(UInt16)state;
-(unsigned)countTerminatorsForKeyboardType:(unsigned)kbtype;
-(NSString*)copyTerminatorForKeyboardType:(unsigned)kbtype forState:(unsigned)state;
-(void)dumpKeyboardType:(unsigned)kbtype;
@end

char* VKKName(unsigned idx);
char* VKKSymbol(unsigned idx);
