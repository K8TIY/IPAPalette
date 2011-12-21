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
#import "KeylayoutParser.h"

@interface KeylayoutParser (Private)
-(void)invokeSelector:(SEL)sel forFoundSequence:(NSString*)seq
       output:(NSString*)output withObject:(id)obj;
@end

@interface NSMutableString (KLPAdditions)
-(void)setFormat:(NSString*)fmt, ...;
@end

@implementation NSMutableString (KLPAdditions)
-(void)setFormat:(NSString*)fmt, ...
{
  va_list args;
  va_start(args, fmt);
  NSString* tmp = [[NSString alloc] initWithFormat:fmt  arguments:args];
  va_end(args);
  [self setString:tmp];
  [tmp release];
}
@end

@implementation KeylayoutParser
// Chooses which keyboard sequence is "better", i.e. more terse.
// Shorter wins
// Mod weight is also taken into account: the lighter the better
// Shift and option are weight 0, cmd is 1, ctrl is 2, lock is 3. 
+(NSComparisonResult)compareKeyboardSequence:(NSString*)s1
                     withSequence:(NSString*)s2
{
  if (s1 == nil && s2 != nil) return NSOrderedDescending;
  if (s1 != nil && s2 == nil) return NSOrderedAscending;
  if (s1 == nil && s2 == nil) return NSOrderedSame;
  unsigned l1 = [s1 length];
  unsigned l2 = [s2 length];
  //NSLog(@"compareKeyboardSequence:'%@' withSequence:'%@'", s1, s2);
  if (l1 < l2) return NSOrderedAscending;
  if (l1 > l2) return NSOrderedDescending;
  unsigned w1 = 0;
  unsigned w2 = 0;
  unsigned i;
  for (i = 0; i < l1; i++)
  {
    unichar c1 = [s1 characterAtIndex:i];
    if (c1 == 0x21EA) w1 += 3;
    else if (c1 == kCommandUnicode) w1 += 2;
    else if (c1 == kControlUnicode) w1 += 1;
  }
  for (i = 0; i < l1; i++)
  {
    unichar c2 = [s2 characterAtIndex:i];
    if (c2 == 0x21EA) w2 += 3;
    else if (c2 == kCommandUnicode) w2 += 2;
    else if (c2 == kControlUnicode) w2 += 1;
  }
  if (w1 < w2) return NSOrderedAscending;
  if (w1 > w2) return NSOrderedDescending;
  return NSOrderedSame;
}

+(BOOL)isModifier:(unichar)ch
{
  switch (ch)
  {
    case kCommandUnicode: return YES;
    case kShiftUnicode: return YES;
    case 0x21EA: return YES;
    case kOptionUnicode: return YES;
    case kControlUnicode: return YES;
  }
  return NO;
}

-(id)init
{
  self = [super init];
  _kbType = LMGetKbdType();
  _modMap = [[NSMutableDictionary alloc] init];
  _stateMap = [[NSMutableDictionary alloc] init];
  TISInputSourceRef isr = TISCopyCurrentKeyboardLayoutInputSource();
  void* vp = TISGetInputSourceProperty(isr, kTISPropertyUnicodeKeyLayoutData);
  CFDataRef data = (CFDataRef)vp;
  unsigned n = CFDataGetLength(data);
  _buff = malloc(n);
  CFDataGetBytes(data, CFRangeMake(0,n), _buff);
  CFRelease(isr);
  return self;
}

-(void)dealloc
{
  if (_buff) free(_buff);
  if (_modMap) [_modMap release];
  if (_stateMap) [_stateMap release];
  [super dealloc];
}

-(unsigned)matchingKeyboardType
{
  unsigned match = 0;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[0]);
  unsigned i;
  for (i = 0; i < uckl->keyboardTypeCount; i++, uckth++)
  {
    if (_kbType >= uckth->keyboardTypeFirst && _kbType <= uckth->keyboardTypeLast)
    {
      match = i;
      break;
    }
  }
  return match;
}

-(void)parseKeyboardType:(unsigned)kbtype withObject:(id)obj selector:(SEL)sel
{
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  UCKeyModifiersToTableNum* uckmttn = (UCKeyModifiersToTableNum*)(_buff + uckth->keyModifiersToTableNumOffset);
  unsigned j, k;
  NSMutableString* modString = [[NSMutableString alloc] init];
  NSNumber* tableNum;
  for (j = 0; j < uckmttn->modifiersCount; j++)
  {
    [modString setString:@""];
    tableNum = [[NSNumber alloc] initWithUnsignedInt:uckmttn->tableNum[j]];
    if (j & (1 << (cmdKeyBit - 8))) [modString appendFormat:@"%C", kCommandUnicode];
    if (j & (1 << (shiftKeyBit - 8)) || j & (1 << (rightShiftKeyBit - 8))) [modString appendFormat:@"%C", kShiftUnicode];
    if (j & (1 << (alphaLockBit - 8))) [modString appendFormat:@"%C", 0x21EA];
    if (j & (1 << (optionKeyBit - 8)) || j & (1 << (rightOptionKeyBit - 8))) [modString appendFormat:@"%C", kOptionUnicode];
    if (j & (1 << (controlKeyBit - 8)) || j & (1 << (rightControlKeyBit - 8))) [modString appendFormat:@"%C", kControlUnicode];
    NSString* existing = [_modMap objectForKey:tableNum];
    if (!existing || [existing length] > [modString length])
    {
      NSString* cpy = [modString copy];
      [_modMap setObject:cpy forKey:tableNum];
      [cpy release];
    }
    [tableNum release];
  }
  UCKeyToCharTableIndex* ucktcti = (UCKeyToCharTableIndex*)(_buff + uckth->keyToCharTableIndexOffset);
  for (j = 0; j < ucktcti->keyToCharTableCount; j++)
  {
    tableNum = [[NSNumber alloc] initWithUnsignedInt:j];
    [modString setString:[_modMap objectForKey:tableNum]];
    [tableNum release];
    UCKeyOutput* ucko = (UCKeyOutput*)(_buff + ucktcti->keyToCharTableOffsets[j]);
    for (k = 0; k < ucktcti->keyToCharTableSize; k++, ucko++)
    {
      UCKeyOutput ko = *ucko;
      NSString* output = nil;
      NSString* sym = [[NSString alloc] initWithUTF8String:VKKSymbol(k)];
      NSString* seq = [[NSString alloc] initWithFormat:@"%@%@", modString, sym];
      [sym release];
      if ((ko & kUCKeyOutputTestForIndexMask) == kUCKeyOutputStateIndexMask)
      {
        UInt16 next = 0;
        unichar ch = [self state0OutputForKeyboardType:kbtype atIndex:ko & kUCKeyOutputGetIndexMask nextState:&next];
        if (ch) output = [[NSString alloc] initWithFormat:@"%C", ch];
        if (next)
        {
          NSNumber* nextNum = [[NSNumber alloc] initWithUnsignedInt:next];
          //id existing = [_stateMap objectForKey:seq];
          //if (existing) NSLog("Warning: existing state (%@) for sequence %@", existing, seq);
          [_stateMap setObject:nextNum forKey:seq];
          [nextNum release];
        }
      }
      else if ((ko & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask)
      {
        output = [self copySequenceForKeyboardType:kbtype atIndex:ko & kUCKeyOutputGetIndexMask];
      }
      else if (ko < 0xFFFE)
      {
        output = [[NSString alloc] initWithFormat:@"%C", ko];
      }
      if (output)
      {
        [self invokeSelector:sel forFoundSequence:seq output:output withObject:obj];
        [output release];
        output = nil;
      }
      [seq release];
    }
  }
  // Second pass
  for (j = 0; j < ucktcti->keyToCharTableCount; j++)
  {
    tableNum = [[NSNumber alloc] initWithUnsignedInt:j];
    [modString setString:[_modMap objectForKey:tableNum]];
    [tableNum release];
    UCKeyOutput* ucko = (UCKeyOutput*)(_buff + ucktcti->keyToCharTableOffsets[j]);
    for (k = 0; k < ucktcti->keyToCharTableSize; k++, ucko++)
    {
      char* symstr = VKKSymbol(k);
      UCKeyOutput ko = *ucko;
      if ((ko & kUCKeyOutputTestForIndexMask) == kUCKeyOutputStateIndexMask &&
          strlen(symstr))
      {
        NSString* output = nil;
        NSString* sym = [[NSString alloc] initWithCString:symstr encoding:NSUTF8StringEncoding];
        NSString* seq = [[NSString alloc] initWithFormat:@"%@%@", modString, sym];
        [sym release];
        for (NSString* key in [_stateMap allKeys])
        {
          NSNumber* stateNum = [_stateMap objectForKey:key];
          unsigned state = [stateNum unsignedIntValue];
          output = [self copyOutputForKeyboardType:kbtype atIndex:ko & kUCKeyOutputGetIndexMask
                         inState:state];
          if (output)
          {
            NSString* fullSeq = [[NSString alloc] initWithFormat:@"%@%@", key, seq];
            [self invokeSelector:sel forFoundSequence:fullSeq output:output withObject:obj];
            [fullSeq release];
            [output release];
          }
        }
        [seq release];
      }
    }
  }
  for (NSString* s in [_stateMap allKeys])
  {
    NSNumber* stateNum = [_stateMap objectForKey:s];
    NSString* ahnold = [self copyTerminatorForKeyboardType:kbtype forState:[stateNum unsignedIntValue]];
    [self invokeSelector:sel forFoundSequence:s output:ahnold withObject:obj];
  }
  [modString release];
}

-(NSString*)copySequenceForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
{
  NSString* s = nil;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  if (uckth->keySequenceDataIndexOffset)
  {
    UCKeySequenceDataIndex* ucksdi = (UCKeySequenceDataIndex*)(_buff + uckth->keySequenceDataIndexOffset);
    if (idx < ucksdi->charSequenceCount)
    {
      UInt8* start = (UInt8*)ucksdi + ucksdi->charSequenceOffsets[idx];
      UInt8* end = (UInt8*)ucksdi + ucksdi->charSequenceOffsets[idx+1];
      NSStringEncoding enc = (CFByteOrderGetCurrent() == CFByteOrderLittleEndian)?
          NSUTF16LittleEndianStringEncoding:NSUTF16BigEndianStringEncoding;
      s = [[NSString alloc] initWithBytes:start length:end-start encoding:enc];
    }
  }
  return s;
}

-(unichar)state0OutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
          nextState:(UInt16*)oNextState
{
  unichar ch = 0;
  UInt16 next = 0;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  if (uckth->keyStateRecordsIndexOffset)
  {
    UCKeyStateRecordsIndex* ucksri = (UCKeyStateRecordsIndex*)(_buff + uckth->keyStateRecordsIndexOffset);
    if (idx < ucksri->keyStateRecordCount)
    {
      UCKeyStateRecord* ucksr = (UCKeyStateRecord*)(_buff + ucksri->keyStateRecordOffsets[idx]);
      if (ucksr->stateZeroCharData && ucksr->stateZeroCharData < 0xFFFE)
        ch = ucksr->stateZeroCharData;
      next = ucksr->stateZeroNextState;
    }
  }
  if (oNextState) *oNextState = next;
  return ch;
}

-(NSString*)copyOutputForKeyboardType:(unsigned)kbtype atIndex:(unsigned)idx
            inState:(UInt16)state
{
  NSString* s = nil;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  if (uckth->keyStateRecordsIndexOffset)
  {
    UCKeyStateRecordsIndex* ucksri = (UCKeyStateRecordsIndex*)(_buff + uckth->keyStateRecordsIndexOffset);
    do
    {
      UCKeyStateRecord* ucksr = (UCKeyStateRecord*)(_buff + ucksri->keyStateRecordOffsets[idx]);
      char* sed = (char*)&(ucksr->stateEntryData[0]);
      unsigned k;
      for (k = 0; k <= ucksr->stateEntryCount; k++)
      {
        unsigned cs = 0;
        UCKeyCharSeq kcs;
        if (k == 0)
        {
          kcs = ucksr->stateZeroCharData;
        }
        else
        {
          if (ucksr->stateEntryFormat == kUCKeyStateEntryTerminalFormat)
          {
            UCKeyStateEntryTerminal* kset = (UCKeyStateEntryTerminal*)sed;
            kcs = kset->charData;
            cs = kset->curState;
          }
          else
          {
            UCKeyStateEntryRange* kser = (UCKeyStateEntryRange*)sed;
            kcs = kser->charData;
          }
        }
        if ((k == 0 && state == 0) || (k > 0 && state > 0 && state == cs))
        {
          if ((kcs & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask && uckth->keySequenceDataIndexOffset)
          {
            return [self copySequenceForKeyboardType:kbtype atIndex:kcs & kUCKeyOutputGetIndexMask];
          }
          else if (kcs > 0 && kcs < 0xFFFE)
          {
            return [[NSString alloc] initWithFormat:@"%C", kcs];
          }
        }
        if (k > 0)
        {
          if (ucksr->stateEntryFormat == kUCKeyStateEntryTerminalFormat)
          {
            sed += sizeof(UCKeyStateEntryTerminal);
          }
          else if (ucksr->stateEntryFormat == kUCKeyStateEntryRangeFormat)
          {
            sed += sizeof(UCKeyStateEntryRange);
          }
        }
      }
      break;
    } while (1);
  }
  return s;
}

-(unsigned)countTerminatorsForKeyboardType:(unsigned)kbtype
{
  unsigned count = 0;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  if (uckth->keyStateTerminatorsOffset)
  {
    UCKeyStateTerminators* uckst = (UCKeyStateTerminators*)(_buff + uckth->keyStateTerminatorsOffset);
    count = uckst->keyStateTerminatorCount;
  }
  return count;
}

-(NSString*)copyTerminatorForKeyboardType:(unsigned)kbtype forState:(unsigned)state
{
  NSString* s = nil;
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  if (uckth->keyStateTerminatorsOffset)
  {
    UCKeyStateTerminators* uckst = (UCKeyStateTerminators*)(_buff + uckth->keyStateTerminatorsOffset);
    if (state <= uckst->keyStateTerminatorCount)
    {
      do
      {
        UCKeyCharSeq kcs = uckst->keyStateTerminators[state-1];
        if ((kcs & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask && uckth->keySequenceDataIndexOffset)
        {
          s = [self copySequenceForKeyboardType:kbtype atIndex:kcs & kUCKeyOutputGetIndexMask];
        }
        else if (kcs < 0xFFFE)
        {
          s = [[NSString alloc] initWithFormat:@"%C", kcs];
        }
        break;
      } while (YES);
    }
  }
  return s;
}

-(void)invokeSelector:(SEL)sel forFoundSequence:(NSString*)seq
       output:(NSString*)output withObject:(id)obj
{
  if (obj && sel && [obj respondsToSelector:sel])
  {
    NSMethodSignature* sig = [obj methodSignatureForSelector:sel];
    if (sig)
    {
      NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
      [inv setSelector:sel];
      [inv setTarget:obj];
      [inv setArgument:&self atIndex:2];
      [inv setArgument:&seq atIndex:3];
      [inv setArgument:&output atIndex:4];
      [inv invoke];
    }
  }
}

-(void)dumpKeyboardType:(unsigned)kbtype
{
  UCKeyboardLayout* uckl = (UCKeyboardLayout*)_buff;
  NSLog(@"Parsing keyboard type #%d", kbtype);
  UCKeyboardTypeHeader* uckth = &(uckl->keyboardTypeList[kbtype]);
  UCKeyModifiersToTableNum* uckmttn = (UCKeyModifiersToTableNum*)(_buff + uckth->keyModifiersToTableNumOffset);
  NSLog(@"  KeyModifiersToTableNum: fmt 0x%X (should be 0x%X) default tbl %d, %d recs", uckmttn->keyModifiersToTableNumFormat,
        kUCKeyModifiersToTableNumFormat, uckmttn->defaultTableNum, uckmttn->modifiersCount);
  unsigned j, k;
  NSMutableString* modString = [[NSMutableString alloc] init];
  NSNumber* tableNum;
  NSMutableString* output = [[NSMutableString alloc] init];
   NSLog(@"===== Modifiers =====");
  for (j = 0; j < uckmttn->modifiersCount; j++)
  {
    [modString setString:@""];
    tableNum = [[NSNumber alloc] initWithUnsignedInt:uckmttn->tableNum[j]];
    if (j & (1 << (cmdKeyBit - 8))) [modString appendFormat:@"%C", kCommandUnicode];
    if (j & (1 << (shiftKeyBit - 8)) || j & (1 << (rightShiftKeyBit - 8))) [modString appendFormat:@"%C", kShiftUnicode];
    if (j & (1 << (alphaLockBit - 8))) [modString appendFormat:@"%C", 0x21EA];
    if (j & (1 << (optionKeyBit - 8)) || j & (1 << (rightOptionKeyBit - 8))) [modString appendFormat:@"%C", kOptionUnicode];
    if (j & (1 << (controlKeyBit - 8)) || j & (1 << (rightControlKeyBit - 8))) [modString appendFormat:@"%C", kControlUnicode];
    //if (![modString length]) [modString setString:@"(no modifiers)"];
    //NSLog(@"    %d (0x%X, %@): table %d", j, j, modString, uckmttn->tableNum[j]);
    NSString* existing = [_modMap objectForKey:tableNum];
    if (!existing ||
        NSOrderedAscending == [KeylayoutParser compareKeyboardSequence:modString
                                               withSequence:existing])
    {
      NSString* cpy = [modString copy];
      [_modMap setObject:cpy forKey:tableNum];
      [cpy release];
    }
    [tableNum release];
  }
  for (tableNum in [[_modMap allKeys] sortedArrayUsingSelector:@selector(compare:)])
    NSLog(@"    %@: table %@", [_modMap objectForKey:tableNum], tableNum);
  UCKeyToCharTableIndex* ucktcti = (UCKeyToCharTableIndex*)(_buff + uckth->keyToCharTableIndexOffset);
  NSLog(@"  KeyToCharTableIndex: fmt 0x%X (should be 0x%X) size %d, %d recs", ucktcti->keyToCharTableIndexFormat,
        kUCKeyToCharTableIndexFormat, ucktcti->keyToCharTableSize, ucktcti->keyToCharTableCount);
  for (j = 0; j < ucktcti->keyToCharTableCount; j++)
  {
    tableNum = [[NSNumber alloc] initWithUnsignedInt:j];
    [modString setString:[_modMap objectForKey:tableNum]];
    [tableNum release];
    NSLog(@"    Table %d: offset %d", j, ucktcti->keyToCharTableOffsets[j]);
    UCKeyOutput* ucko = (UCKeyOutput*)(_buff + ucktcti->keyToCharTableOffsets[j]);
    for (k = 0; k < ucktcti->keyToCharTableSize; k++, ucko++)
    {
      UCKeyOutput ko = *ucko;
      NSString* sym = [[NSString alloc] initWithUTF8String:VKKSymbol(k)];
      NSString* seq = [[NSString alloc] initWithFormat:@"%@%@", modString, sym];
      [sym release];
      [output setString:@""];
      if ((ko & kUCKeyOutputTestForIndexMask) == kUCKeyOutputStateIndexMask)
      {
        [output setFormat:@"state table %d", ko & kUCKeyOutputGetIndexMask];
      }
      else if ((ko & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask)
      {
        [output setFormat:@"sequence %d", ko & kUCKeyOutputGetIndexMask];
      }
      else if (ko < 0xFFFE)
      {
        [output setFormat:@"%C", ko];
      }
      if ([output length]) NSLog(@"      %d: %@ -> %@ (UCKeyOutput 0x%04X)", k, seq, output, ko);
      [seq release];
    }
  }
  [modString release];
  if (uckth->keyStateRecordsIndexOffset)
  {
    UCKeyStateRecordsIndex* ucksri = (UCKeyStateRecordsIndex*)(_buff + uckth->keyStateRecordsIndexOffset);
    do
    {
      NSLog(@"  KeyStateRecordsIndex: fmt 0x%X (should be 0x%X) size %d", ucksri->keyStateRecordsIndexFormat,
            kUCKeyStateRecordsIndexFormat, ucksri->keyStateRecordCount);
      for (j = 0; j < ucksri->keyStateRecordCount; j++)
      {
        UCKeyStateRecord* ucksr = (UCKeyStateRecord*)(_buff + ucksri->keyStateRecordOffsets[j]);
        NSLog(@"    KeyStateRecord %d (0x%X): seq 0x%X (%C), state 0 next %d, cnt %d, fmt %d", j, ucksr, ucksr->stateZeroCharData,
              ucksr->stateZeroCharData, ucksr->stateZeroNextState, ucksr->stateEntryCount, ucksr->stateEntryFormat);
        char* sed = (char*)&(ucksr->stateEntryData[0]);
        if ((unsigned long)sed & 1) sed++;
        if ((unsigned long)sed & 2) sed += 2;
        for (k = 1; k <= ucksr->stateEntryCount; k++)
        {
          UCKeyCharSeq kcs;
          if (ucksr->stateEntryFormat == kUCKeyStateEntryTerminalFormat)
          {
            UCKeyStateEntryTerminal* kset = (UCKeyStateEntryTerminal*)sed;
            kcs = kset->charData;
          }
          else
          {
            UCKeyStateEntryRange* kser = (UCKeyStateEntryRange*)sed;
            kcs = kser->charData;
          }
          if ((kcs & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask && uckth->keySequenceDataIndexOffset)
          {
            [output setFormat:@"sequence %d", kcs & kUCKeyOutputGetIndexMask];
          }
          else if (kcs > 0 && kcs < 0xFFFE)
          {
            [output setFormat:@"character '%C' (U+%04X)", kcs, kcs];
          }
          if (ucksr->stateEntryFormat == kUCKeyStateEntryTerminalFormat)
          {
            UCKeyStateEntryTerminal* kset = (UCKeyStateEntryTerminal*)sed;
            NSLog(@"      State %d: %@", kset->curState, output);
            sed += sizeof(UCKeyStateEntryTerminal);
          }
          else if (ucksr->stateEntryFormat == kUCKeyStateEntryRangeFormat)
          {
            UCKeyStateEntryRange* kser = (UCKeyStateEntryRange*)sed;
            UCKeyCharSeq charData = kser->charData;
            BOOL needRel = NO;
            NSString* desc;
            if (charData && charData < 0xFFFE)
            {
              desc = [[NSString alloc] initWithCharacters:&charData length:1];
              needRel = YES;
            }
            else desc = @"(no description)";
            NSLog(@"      State %d: 0x%X, %@ (from 0x%X) state start %d range %d mult %d next %d",
                  k, charData, desc, kcs, kser->curStateStart, kser->curStateRange, kser->deltaMultiplier,
                  kser->nextState);
            if (desc && needRel) [desc release];
            sed += sizeof(UCKeyStateEntryRange);
          }
          else
          {
            NSLog(@"      State %d: unknown format", k);
          }
        }
      } break;
    } while (1);
  }
  if (uckth->keyStateTerminatorsOffset)
  {
    NSLog(@"===== Terminators =====");
    UCKeyStateTerminators* uckst = (UCKeyStateTerminators*)(_buff + uckth->keyStateTerminatorsOffset);
    do
    {
      NSString* s = nil;
      NSLog(@"  KeyStateTerminators: fmt 0x%X (should be 0x%X) size %d", uckst->keyStateTerminatorsFormat,
            kUCKeyStateTerminatorsFormat, uckst->keyStateTerminatorCount);
      for (j = 0; j < uckst->keyStateTerminatorCount; j++)
      {
        UCKeyCharSeq kcs = uckst->keyStateTerminators[j];
        if ((kcs & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask && uckth->keySequenceDataIndexOffset)
        {
          s = [self copySequenceForKeyboardType:kbtype atIndex:kcs & kUCKeyOutputGetIndexMask];
        }
        else if (kcs < 0xFFFE)
        {
          s = [[NSString alloc] initWithFormat:@"%C", kcs];
        }
        NSLog(@"    State %d: '%@' (from 0x%X)", j+1, s, kcs);
        if (s) [s release];
      }
      break;
    } while (YES);
  }
  if (uckth->keySequenceDataIndexOffset)
  {
    NSLog(@"===== Key Sequences =====");
   /*struct UCKeySequenceDataIndex {
    UInt16              keySequenceDataIndexFormat; // =kUCKeySequenceDataIndexFormat
    UInt16              charSequenceCount;      // Dimension of charSequenceOffsets[] is charSequenceCount+1
    UInt16              charSequenceOffsets[1];
                                                // Each offset in charSequenceOffsets is in bytes, from the beginning of
                                                // UCKeySequenceDataIndex to a sequence of UniChars; the next offset indicates the
                                                // end of the sequence. The UniChar sequences follow the UCKeySequenceDataIndex.
                                                // Then there is padding to a 4-byte boundary with bytes containing 0, if necessary.
    */
    UCKeySequenceDataIndex* ucksdi = (UCKeySequenceDataIndex*)(_buff + uckth->keySequenceDataIndexOffset);
    NSLog(@"  KeySequenceDataIndex: fmt 0x%X (should be 0x%X) size %d", ucksdi->keySequenceDataIndexFormat,
            kUCKeySequenceDataIndexFormat, ucksdi->charSequenceCount);
    for (j = 0; j < ucksdi->charSequenceCount; j++)
    {
      UInt8* start = (UInt8*)ucksdi + ucksdi->charSequenceOffsets[j];
      UInt8* end = (UInt8*)ucksdi + ucksdi->charSequenceOffsets[j+1];
      NSStringEncoding enc = (CFByteOrderGetCurrent() == CFByteOrderLittleEndian)?
          NSUTF16LittleEndianStringEncoding:NSUTF16BigEndianStringEncoding;
      NSString* s = [[NSString alloc] initWithBytes:start length:end-start encoding:enc];
      NSLog(@"    %d: '%@' 0x%X to 0x%X (%d bytes)", j, s, start, end, end-start);
      [s release];
    }
  }
  [output release];
}
@end

char* VKKName(unsigned idx)
{
 static char* names[] = {
"kVK_ANSI_A", //0x00
"kVK_ANSI_S", //0x01
"kVK_ANSI_D", //0x02
"kVK_ANSI_F", //0x03
"kVK_ANSI_H", //0x04
"kVK_ANSI_G", //0x05
"kVK_ANSI_Z", //0x06
"kVK_ANSI_X", //0x07
"kVK_ANSI_C", //0x08
"kVK_ANSI_V", //0x09
"kVK_ISO_Section", //0x0A
"kVK_ANSI_B", //0x0B
"kVK_ANSI_Q", //0x0C
"kVK_ANSI_W", //0x0D
"kVK_ANSI_E", //0x0E
"kVK_ANSI_R", //0x0F
"kVK_ANSI_Y", //0x10
"kVK_ANSI_T", //0x11
"kVK_ANSI_1", //0x12
"kVK_ANSI_2", //0x13
"kVK_ANSI_3", //0x14
"kVK_ANSI_4", //0x15
"kVK_ANSI_6", //0x16
"kVK_ANSI_5", //0x17
"kVK_ANSI_Equal", //0x18
"kVK_ANSI_9", //0x19
"kVK_ANSI_7", //0x1A
"kVK_ANSI_Minus", //0x1B
"kVK_ANSI_8", //0x1C
"kVK_ANSI_0", //0x1D
"kVK_ANSI_RightBracket", //0x1E
"kVK_ANSI_O", //0x1F
"kVK_ANSI_U", //0x20
"kVK_ANSI_LeftBracket", //0x21
"kVK_ANSI_I", //0x22
"kVK_ANSI_P", //0x23
"kVK_Return", //0x24
"kVK_ANSI_L", //0x25
"kVK_ANSI_J", //0x26
"kVK_ANSI_Quote", //0x27
"kVK_ANSI_K", //0x28
"kVK_ANSI_Semicolon", //0x29
"kVK_ANSI_Backslash", //0x2A
"kVK_ANSI_Comma", //0x2B
"kVK_ANSI_Slash", //0x2C
"kVK_ANSI_N", //0x2D
"kVK_ANSI_M", //0x2E
"kVK_ANSI_Period", //0x2F
"kVK_Tab", //0x30
"kVK_Space", //0x31
"kVK_ANSI_Grave", //0x32
"kVK_Delete", //0x33
"kVK_Unknown_0x34",
"kVK_Escape", //0x35
"kVK_Unknown_0x36",
"kVK_Command", //0x37
"kVK_Shift", //0x38
"kVK_CapsLock", //0x39
"kVK_Option", //0x3A
"kVK_Control", //0x3B
"kVK_RightShift", //0x3C
"kVK_RightOption", //0x3D
"kVK_RightControl", //0x3E
"kVK_Function", //0x3F
"kVK_F17", //0x40
"kVK_ANSI_KeypadDecimal", //0x41
"kVK_Unknown_0x42",
"kVK_ANSI_KeypadMultiply", //0x43
"kVK_Unknown_0x44",
"kVK_ANSI_KeypadPlus", //0x45
"kVK_Unknown_0x46",
"kVK_ANSI_KeypadClear", //0x47
"kVK_VolumeUp", //0x48
"kVK_VolumeDown", //0x49
"kVK_Mute", //0x4A
"kVK_ANSI_KeypadDivide", //0x4B
"kVK_ANSI_KeypadEnter", //0x4C
"kVK_Unknown_0x4D",
"kVK_ANSI_KeypadMinus", //0x4E
"kVK_F18", //0x4F
"kVK_F19", //0x50
"kVK_ANSI_KeypadEquals", //0x51
"kVK_ANSI_Keypad0", //0x52
"kVK_ANSI_Keypad1", //0x53
"kVK_ANSI_Keypad2", //0x54
"kVK_ANSI_Keypad3", //0x55
"kVK_ANSI_Keypad4", //0x56
"kVK_ANSI_Keypad5", //0x57
"kVK_ANSI_Keypad6", //0x58
"kVK_ANSI_Keypad7", //0x59
"kVK_F20", //0x5A
"kVK_ANSI_Keypad8", //0x5B
"kVK_ANSI_Keypad9", //0x5C
"kVK_JIS_Yen", //0x5D
"kVK_JIS_Underscore", //0x5E
"kVK_JIS_KeypadComma", //0x5F
"kVK_F5", //0x60
"kVK_F6", //0x61
"kVK_F7", //0x62
"kVK_F3", //0x63
"kVK_F8", //0x64
"kVK_F9", //0x65
"kVK_JIS_Eisu", //0x66
"kVK_F11", //0x67
"kVK_JIS_Kana", //0x68
"kVK_F13", //0x69
"kVK_F16", //0x6A
"kVK_F14", //0x6B
"kVK_Unknown_0x6C",
"kVK_F10", //0x6D
"kVK_Unknown_0x6E",
"kVK_F12", //0x6F
"kVK_Unknown_0x70",
"kVK_F15", //0x71
"kVK_Help", //0x72
"kVK_Home", //0x73
"kVK_PageUp", //0x74
"kVK_ForwardDelete", //0x75
"kVK_F4", //0x76
"kVK_End", //0x77
"kVK_F2", //0x78
"kVK_PageDown", //0x79
"kVK_F1", //0x7A
"kVK_LeftArrow", //0x7B
"kVK_RightArrow", //0x7C
"kVK_DownArrow", //0x7D
"kVK_UpArrow", //0x7E
};
  return (0x7E >= idx)? names[idx]:"unknown index";
}

char* VKKSymbol(unsigned idx)
{
 static char* syms[] = {
"A",//"kVK_ANSI_A", //0x00
"S",//"kVK_ANSI_S", //0x01
"D",//"kVK_ANSI_D", //0x02
"F",//"kVK_ANSI_F", //0x03
"H",//"kVK_ANSI_H", //0x04
"G",//"kVK_ANSI_G", //0x05
"Z",//"kVK_ANSI_Z", //0x06
"X",//"kVK_ANSI_X", //0x07
"C",//"kVK_ANSI_C", //0x08
"V",//"kVK_ANSI_V", //0x09
"\xC2\xA7",//"kVK_ISO_Section", //0x0A
"B",//"kVK_ANSI_B", //0x0B
"Q",//"kVK_ANSI_Q", //0x0C
"W",//"kVK_ANSI_W", //0x0D
"E",//"kVK_ANSI_E", //0x0E
"R",//"kVK_ANSI_R", //0x0F
"Y",//"kVK_ANSI_Y", //0x10
"T",//"kVK_ANSI_T", //0x11
"1",//"kVK_ANSI_1", //0x12
"2",//"kVK_ANSI_2", //0x13
"3",//"kVK_ANSI_3", //0x14
"4",//"kVK_ANSI_4", //0x15
"6",//"kVK_ANSI_6", //0x16
"5",//"kVK_ANSI_5", //0x17
"=",//"kVK_ANSI_Equal", //0x18
"9",//"kVK_ANSI_9", //0x19
"7",//"kVK_ANSI_7", //0x1A
"-",//"kVK_ANSI_Minus", //0x1B
"8",//"kVK_ANSI_8", //0x1C
"0",//"kVK_ANSI_0", //0x1D
"]",//"kVK_ANSI_RightBracket", //0x1E
"O",//"kVK_ANSI_O", //0x1F
"U",//"kVK_ANSI_U", //0x20
"[",//"kVK_ANSI_LeftBracket", //0x21
"I",//"kVK_ANSI_I", //0x22
"P",//"kVK_ANSI_P", //0x23
"\xE2\x86\xA9",//"kVK_Return", //0x24;
"L",//"kVK_ANSI_L", //0x25
"J",//"kVK_ANSI_J", //0x26
"'",//"kVK_ANSI_Quote", //0x27
"K",//"kVK_ANSI_K", //0x28
";",//"kVK_ANSI_Semicolon", //0x29
"\\",//"kVK_ANSI_Backslash", //0x2A
",",//"kVK_ANSI_Comma", //0x2B
"/",//"kVK_ANSI_Slash", //0x2C
"N",//"kVK_ANSI_N", //0x2D
"M",//"kVK_ANSI_M", //0x2E
".",//"kVK_ANSI_Period", //0x2F
"\xE2\x87\xA5",//"kVK_Tab", //0x30
"\xE2\x90\xA3",//"kVK_Space", //0x31
"`",//"kVK_ANSI_Grave", //0x32
"\xE2\x8C\xAB",//"kVK_Delete", //0x33
"",//"kVK_Unknown_0x34",
"\xE2\x8E\x8B",//"kVK_Escape", //0x35
"",//"kVK_Unknown_0x36",
"\xE2\x8C\x98",//"kVK_Command", //0x37
"\xE2\x87\xA7",//"kVK_Shift", //0x38
"\xE2\x87\xAA",//"kVK_CapsLock", //0x39
"\xE2\x8C\xA5",//"kVK_Option", //0x3A
"\xE2\x8C\x83",//"kVK_Control", //0x3B
"\xE2\x87\xA7",//"kVK_RightShift", //0x3C
"\xE2\x8C\xA5",//"kVK_RightOption", //0x3D
"\xE2\x8C\x83",//"kVK_RightControl", //0x3E
"fn",//"kVK_Function", //0x3F  Oh, it's the key on my old Pismo PowerBook -- the orange-ish F key
"F17",//"kVK_F17", //0x40
".\xE2\x83\xA3",//"kVK_ANSI_KeypadDecimal", //0x41
"",//"kVK_Unknown_0x42",
"*\xE2\x83\xA3",//"kVK_ANSI_KeypadMultiply", //0x43
"",//"kVK_Unknown_0x44",
"+\xE2\x83\xA3",//"kVK_ANSI_KeypadPlus", //0x45
"",//"kVK_Unknown_0x46",
"\xE2\x8C\xA7\xE2\x83\xA3",//"kVK_ANSI_KeypadClear", //0x47
"\xF0\x9F\x94\x8A",//"kVK_VolumeUp", //0x48 U+1F50A
"\xF0\x9F\x94\x89",//"kVK_VolumeDown", //0x49 U+1F509
"\xF0\x9F\x94\x88",//"kVK_Mute", //0x4A U+1F508 (could use U+1F507 too)
"/\xE2\x83\xA3",//"kVK_ANSI_KeypadDivide", //0x4B
"\xE2\x86\xA9\xE2\x83\xA3",//"kVK_ANSI_KeypadEnter", //0x4C
"",//"kVK_Unknown_0x4D",
"-\xE2\x83\xA3",//"kVK_ANSI_KeypadMinus", //0x4E
"F18",//"kVK_F18", //0x4F
"F19",//"kVK_F19", //0x50
"=\xE2\x83\xA3",//"kVK_ANSI_KeypadEquals", //0x51
"0\xE2\x83\xA3",//"kVK_ANSI_Keypad0", //0x52
"1\xE2\x83\xA3",//"kVK_ANSI_Keypad1", //0x53
"2\xE2\x83\xA3",//"kVK_ANSI_Keypad2", //0x54
"3\xE2\x83\xA3",//"kVK_ANSI_Keypad3", //0x55
"4\xE2\x83\xA3",//"kVK_ANSI_Keypad4", //0x56
"5\xE2\x83\xA3",//"kVK_ANSI_Keypad5", //0x57
"6\xE2\x83\xA3",//"kVK_ANSI_Keypad6", //0x58
"7\xE2\x83\xA3",//"kVK_ANSI_Keypad7", //0x59
"F20",//"kVK_F20", //0x5A
"8\xE2\x83\xA3",//"kVK_ANSI_Keypad8", //0x5B
"9\xE2\x83\xA3",//"kVK_ANSI_Keypad9", //0x5C
"\xC2\xA5",//"kVK_JIS_Yen", //0x5D
"_",//"kVK_JIS_Underscore", //0x5E
",\xE2\x83\xA3",//"kVK_JIS_KeypadComma", //0x5F
"F5",//"kVK_F5", //0x60
"F6",//"kVK_F6", //0x61
"F7",//"kVK_F7", //0x62
"F3",//"kVK_F3", //0x63
"F8",//"kVK_F8", //0x64
"F9",//"kVK_F9", //0x65
"\xE8\x8B\xB1\xE6\x95\xB0",//"kVK_JIS_Eisu", //0x66
"F11",//"kVK_F11", //0x67
"\xE3\x81\x8B\xE3\x81\xAA",//"kVK_JIS_Kana", //0x68
"F13",//"kVK_F13", //0x69
"F16",//"kVK_F16", //0x6A
"F14",//"kVK_F14", //0x6B
"",//"kVK_Unknown_0x6C",
"F10",//"kVK_F10", //0x6D
"",//"kVK_Unknown_0x6E",
"F12",//"kVK_F12", //0x6F
"",//"kVK_Unknown_0x70",
"F15",//"kVK_F15", //0x71
"?\xE2\x83\xA3",//"kVK_Help", //0x72
"\xE2\x86\x96",//"kVK_Home", //0x73
"\xE2\x87\x9E",//"kVK_PageUp", //0x74
"\xE2\x8C\xA6",//"kVK_ForwardDelete", //0x75
"F4",//"kVK_F4", //0x76
"\xE2\x86\x98",//"kVK_End", //0x77
"F2",//"kVK_F2", //0x78
"\xE2\x87\x9F",//"kVK_PageDown", //0x79
"F1",//"kVK_F1", //0x7A
"\xE2\x86\x90",//"kVK_LeftArrow", //0x7B
"\xE2\x86\x92",//"kVK_RightArrow", //0x7C
"\xE2\x86\x93",//"kVK_DownArrow", //0x7D
"\xE2\x86\x91",//"kVK_UpArrow", //0x7E
};
  return (0x7E >= idx)? syms[idx]:"";
}
