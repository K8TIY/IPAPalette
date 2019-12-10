/*
Copyright © 2005-2011 Brian S. Hall

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
#import "UserGlyphsController.h"
#import "Onizuka.h"
#import "IPAServer.h"
#import "Placeholder.h"

@interface UserGlyphsController (Private)
-(NSUInteger)_moveRows:(NSArray*)array to:(NSUInteger)destination copying:(BOOL)copy;
@end

static NSString* const IPASymbolListRows = @"IPASymbolListRows";

@implementation UserGlyphsController
-(id)init
{
  self = [super init];
  _editglyphs = [[NSMutableArray alloc] init];
  _editdescriptions = [[NSMutableArray alloc] init];
  return self;
}

-(void)dealloc
{
  if (_editglyphs) [_editglyphs release];
  if (_editdescriptions) [_editdescriptions release];
  [super dealloc];
}

-(void)awakeFromNib
{
  [_table registerForDraggedTypes:[NSArray arrayWithObjects:IPASymbolListRows, nil]];
  [[Onizuka sharedOnizuka] localizeWindow:_editSheet];
}

-(IBAction)editSymbolsAction:(id)sender
{
  #pragma unused (sender)
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  NSArray* a = [defs objectForKey:ipaUserGlyphsKey];
  NSDictionary* d = [defs objectForKey:ipaUserGlyphDescriptionsKey];
  [_editglyphs removeAllObjects];
  [_editdescriptions removeAllObjects];
  for (NSString* glyph in a)
  {
    [_editglyphs addObject:glyph];
    NSString* uplus = [IPAServer copyUPlusForString:glyph];
    NSString* desc = [d objectForKey:uplus];
    if (!desc) desc = @"";
    [_editdescriptions addObject:desc];
    [uplus release];
  }
  [_table reloadData];
  [NSApp beginSheet:_editSheet modalForWindow:_window modalDelegate:self
         didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:)
         contextInfo:@"EDIT"];
}

-(IBAction)exportSymbolsAction:(id)sender
{
  #pragma unused (sender)
  NSString* loc = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__USER_GLYPHS__"];
  NSString* name = [NSString stringWithFormat:@"%@.plist", loc];
  [loc release];
  NSSavePanel* sp = [[NSSavePanel savePanel] retain];
  [sp setNameFieldStringValue:name];
  [sp beginSheetModalForWindow:_window completionHandler:^(NSInteger result)
  {
    if (result == NSFileHandlingPanelOKButton)
    {
      NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
      NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
      [dict setObject:[defs objectForKey:ipaUserGlyphsKey]
            forKey:ipaUserGlyphsKey];
      [dict setObject:[defs objectForKey:ipaUserGlyphDescriptionsKey]
            forKey:ipaUserGlyphDescriptionsKey];
      [dict writeToURL:[sp URL] atomically:YES];
      [dict release];
      [sp release];
    }
  }];
}

-(IBAction)importSymbolsAction:(id)sender
{
  #pragma unused (sender)
  NSArray* exts = [NSArray arrayWithObjects:@"plist", NULL];
  NSOpenPanel* op = [[NSOpenPanel openPanel] retain];
  [op setCanChooseFiles:YES];
  [op setCanChooseDirectories:NO];
  [op setAllowsMultipleSelection:YES];
  [op setAllowedFileTypes:exts];
  [op beginWithCompletionHandler:^(NSInteger result)
  {
    if (result == NSFileHandlingPanelOKButton)
    {
      NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
      NSDictionary* dict = [[NSDictionary alloc] initWithContentsOfURL:[op URL]];
      NSArray* g = [dict objectForKey:ipaUserGlyphsKey];
      NSDictionary* d = [dict objectForKey:ipaUserGlyphDescriptionsKey];
      if (g && [g isKindOfClass:[NSArray class]] && 
          d && [d isKindOfClass:[NSDictionary class]])
      {
        [defs setObject:g forKey:ipaUserGlyphsKey];
        [defs setObject:d forKey:ipaUserGlyphDescriptionsKey];
        if (delegate)
        {
          #pragma clang diagnostic push
          #pragma clang diagnostic ignored "-Wundeclared-selector"
          SEL sel = @selector(userGlyphsChanged:);
          if ([delegate respondsToSelector:sel])
            [delegate performSelector:sel withObject:self];
          #pragma clang diagnostic pop
        }
      }
      [dict release];
    }
    [op release];
  }];
}

-(IBAction)acceptSheet:(id)sender
{
  [[sender window] makeFirstResponder:[sender window]];
  [NSApp endSheet:[sender window] returnCode:NSModalResponseOK];
}

-(IBAction)cancelSheet:(id)sender
{
  [NSApp endSheet:[sender window] returnCode:NSModalResponseCancel];
}

-(IBAction)addAction:(id)sender
{
  #pragma unused (sender)
  [_table deselectAll:self];
  [_editglyphs addObject:@""];
  [_editdescriptions addObject:@""];
  [_table reloadData];
  NSIndexSet* is = [[NSIndexSet alloc] initWithIndex:[_editglyphs count]-1];
  [_table selectRowIndexes:is byExtendingSelection:NO];
  [_table scrollRowToVisible:[_editglyphs count]-1];
  [is release];
  [_table editColumn:0 row:[_editglyphs count]-1 withEvent:nil select:YES];
}

-(void)_sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)ctx
{
  [sheet orderOut:self];
  if (code != NSModalResponseOK) return;
  NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
  if ([(NSString*)ctx isEqualToString:@"EDIT"])
  {
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    NSUInteger n, i;
    n = [_editglyphs count];
    for (i = 0; i < n; i++)
    {
      NSString* glyph = [_editglyphs objectAtIndex:i];
      if (![glyph length]) continue;
      NSString* uplus = [IPAServer copyUPlusForString:glyph];
      [d setObject:[_editdescriptions objectAtIndex:i] forKey:uplus];
      [uplus release];
    }
    [defs setObject:_editglyphs forKey:ipaUserGlyphsKey];
    [defs setObject:d forKey:ipaUserGlyphDescriptionsKey];
    [d release];
    if (delegate)
    {
      #pragma clang diagnostic push
      #pragma clang diagnostic ignored "-Wundeclared-selector"
      SEL sel = @selector(userGlyphsChanged:);
      if ([delegate respondsToSelector:sel])
        [delegate performSelector:sel withObject:self];
      #pragma clang diagnostic pop
    }
  }
}

-(IBAction)delete:(id)sender
{
  #pragma unused (sender)
  NSUInteger i;
  NSInteger selection = [_table selectedRow];
  if (selection != -1)
  {
    for (i = [_table numberOfRows]; i > 0; i--)
    {
      if ([_table isRowSelected:i-1])
      {
        [_editglyphs removeObjectAtIndex:i-1];
        [_editdescriptions removeObjectAtIndex:i-1];
        selection--;
      }
    }
    if ([_editglyphs count])
    {
      selection++;
      if (selection < 0) selection = [_editglyphs count] - 1;
      if ((NSUInteger)selection >= [_editglyphs count]) selection = [_editglyphs count] - 1;
      NSIndexSet* rows = [NSIndexSet indexSetWithIndex:selection];
      [_table selectRowIndexes:rows byExtendingSelection:NO];
    }
    [_table reloadData];
  }
}

#pragma mark Table
-(NSInteger)numberOfRowsInTableView:(NSTableView*)tv
{
  #pragma unused (tv)
  return [_editglyphs count];
}

-(void)tableView:(NSTableView*)tv setObjectValue:(id)obj forTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  #pragma unused (tv)
  id ident = [col identifier];
  if ([ident isEqual:@"0"]) [_editglyphs replaceObjectAtIndex:row withObject:obj];
  else [_editdescriptions replaceObjectAtIndex:row withObject:obj];
}

-(id)tableView:(NSTableView*)tv objectValueForTableColumn:(NSTableColumn*)col row:(NSInteger)row
{
  #pragma unused (tv)
  id ident = [col identifier];
  NSString* str;
  if ([ident isEqual:@"0"])
  {
    str = [_editglyphs objectAtIndex:row];
    if ([str length] > 0)
    {
      unichar chr = [str characterAtIndex:0];
      if (NeedsPlaceholder(chr))
        str = [NSString stringWithFormat:@"%C%@", PlaceholderDottedCircle, str];
    }
  }
  else str = [_editdescriptions objectAtIndex:row];
  return str;
}

-(BOOL)tableView:(NSTableView*)table writeRowsWithIndexes:(NSIndexSet*)rows toPasteboard:(NSPasteboard*)pb
{
	if (table == _table && [table numberOfSelectedRows])
	{
    NSMutableArray* ary = [[NSMutableArray alloc] init];
    [rows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop){
      #pragma unused (stop)
      [ary addObject:[NSNumber numberWithUnsignedInteger:idx]];
    }];
		// Intra-table drag - data is the array of rows.
		[pb declareTypes:[NSArray arrayWithObject:IPASymbolListRows] owner:nil];
		[pb setPropertyList:ary forType:IPASymbolListRows];
    [ary release];
		return YES;
	}
	return NO;
}

-(NSDragOperation)tableView:(NSTableView*)table validateDrop:(id <NSDraggingInfo>)info
                  proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
  #pragma unused (info)
	// Make drops at the end of the table go to the end.
	if (row == -1)
	{
		row = [table numberOfRows];
		op = NSTableViewDropAbove;
		[table setDropRow:row dropOperation:op];
	}
	// We don't ever want to drop onto a row, only between rows.
	if (op == NSTableViewDropOn)
		[table setDropRow:(row+1) dropOperation:NSTableViewDropAbove];
  NSUInteger modifiers = [[NSApp currentEvent] modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
  if (modifiers == NSEventModifierFlagOption) return NSDragOperationCopy;
  return NSDragOperationMove;
}

-(BOOL)tableView:(NSTableView*)table acceptDrop:(id <NSDraggingInfo>)info
       row:(NSInteger)dropRow dropOperation:(NSTableViewDropOperation)op;
{
  #pragma unused (op)
  //NSLog(@"row %d op %d", dropRow, op);
	BOOL accepted = NO;
  if (table == _table)
	{
	  NSPasteboard* pb = [info draggingPasteboard];
    NSArray* array = [pb propertyListForType:IPASymbolListRows];
    if (array)
    {
      NSDragOperation	srcMask = [info draggingSourceOperationMask];
      BOOL isCopy = (srcMask & NSDragOperationMove) ? NO:YES;
      dropRow = [self _moveRows:array to:dropRow copying:isCopy];
      [table deselectAll:self];
      NSMutableIndexSet* rows = [[NSMutableIndexSet alloc] init];
      for (id idx in array)
      {
        #pragma unused (idx)
        [rows addIndex:dropRow++];
      }
      [_table reloadData];
      [table selectRowIndexes:rows byExtendingSelection:YES];
      [rows release];
      accepted = YES;
    }
	}
	return accepted;
}

-(NSUInteger)_moveRows:(NSArray*)array to:(NSUInteger)destination copying:(BOOL)copy
{
  NSMutableArray* moved = [[NSMutableArray alloc] initWithCapacity:[array count]];
  NSMutableArray* movedDesc = [[NSMutableArray alloc] initWithCapacity:[array count]];
  NSInteger result = destination;
	for (id val in [array reverseObjectEnumerator])
  {
		NSUInteger i = [val unsignedIntValue];
    if (i < destination) result--;
		NSString* m = [_editglyphs objectAtIndex:i];
    NSString* md = [_editdescriptions objectAtIndex:i];
		if (copy)
    {
      m = [m copy];
      md = [md copy];
    }
    else
    {
      [m retain];
      [md retain];
    }
		[moved addObject:m];
    [movedDesc addObject:md];
		[m release];
    [md release];
		if (!copy)
		{
			[_editglyphs removeObjectAtIndex:i];
      [_editdescriptions removeObjectAtIndex:i];
			if (i < destination) destination--;
		}
	}
  NSUInteger dst = destination;
	for (NSString* m in [moved reverseObjectEnumerator])
  {
    [_editglyphs insertObject:m atIndex:dst++];
  }
  dst = destination;
  for (NSString* md in [movedDesc reverseObjectEnumerator])
  {
    [_editdescriptions insertObject:md atIndex:dst++];
  }
  [moved release];
  [movedDesc release];
  return result;
}
@end

@implementation UserGlyphsTable
-(void)keyDown:(NSEvent*)event
{
  NSString* characters = [event charactersIgnoringModifiers];
  BOOL handled = NO;
  if ([characters length] == 1)
  {
    unichar c = [characters characterAtIndex:0];
    if (c == NSDeleteFunctionKey || c == 0x7F)
    {
      handled = YES;
      id del = [self delegate];
      if (del && [del respondsToSelector:@selector(delete:)])
        [del performSelector:@selector(delete:) withObject:self];
    }
  }
  if (!handled) [super keyDown:event];
}

-(BOOL)performKeyEquivalent:(NSEvent*)evt
{
  BOOL handled = NO;
  if ([evt modifierFlags] & NSEventModifierFlagCommand)
  {
    handled = YES;
    NSString* chars = [evt charactersIgnoringModifiers];
    NSText* fe = [[self window] fieldEditor:YES forObject:self];
    if ([chars isEqual:@"a"]) [fe selectAll:self];
    else if ([chars isEqual:@"c"]) [fe copy:self];
    else if ([chars isEqual:@"v"]) [fe paste:self];
    else if ([chars isEqual:@"x"]) [fe cut:self];
    else handled = [super performKeyEquivalent:evt];
  }
  return handled;
}

-(NSDragOperation)draggingSession:(NSDraggingSession*)session
                  sourceOperationMaskForDraggingContext:(NSDraggingContext)ctx
{
  #pragma unused (session)
  switch (ctx)
  {
    case NSDraggingContextOutsideApplication:
    return NSDragOperationNone;
    break;

    case NSDraggingContextWithinApplication:
    default:
    return NSDragOperationMove;
    break;
  }
}
@end
