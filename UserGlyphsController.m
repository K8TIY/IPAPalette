/*
Copyright © 2005-2010 Brian S. Hall

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
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

@implementation UserGlyphsController
-(id)init
{
  self = [super init];
  _glyphs = [[NSMutableArray alloc] init];
  _descriptions = [[NSMutableDictionary alloc] init];
  _editglyphs = [[NSMutableArray alloc] init];
  _editdescriptions = [[NSMutableArray alloc] init];
  return self;
}

-(void)awakeFromNib
{
  [[Onizuka sharedOnizuka] localizeWindow:_editSheet];
}

-(NSArray*)glyphs {return _glyphs;}
-(NSDictionary*)descriptions {return _descriptions;}

-(void)edit
{
  [_editglyphs removeAllObjects];
  [_editdescriptions removeAllObjects];
  NSEnumerator* enu = [_glyphs objectEnumerator];
  NSString* glyph;
  while ((glyph = [enu nextObject]))
  {
    [_editglyphs addObject:glyph];
    NSString* uplus = [IPAServer copyUPlusForString:glyph];
    NSString* desc = [_descriptions objectForKey:uplus];
    if (!desc) desc = @"";
    [_editdescriptions addObject:desc];
    [uplus release];
  }
  [_table reloadData];
  [NSApp beginSheet:_editSheet modalForWindow:_window modalDelegate:self
         didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

-(IBAction)acceptSheet:(id)sender
{
  [NSApp endSheet:[sender window] returnCode:NSAlertDefaultReturn];
}

-(IBAction)cancelSheet:(id)sender
{
  [NSApp endSheet:[sender window] returnCode:NSAlertAlternateReturn];
}

-(IBAction)addAction:(id)sender
{
  [_table deselectAll:self];
  [_editglyphs addObject:@""];
  [_editdescriptions addObject:@""];
  [_table reloadData];
  [_table selectRow:[_editglyphs count]-1 byExtendingSelection:NO];
  [_table editColumn:0 row:[_editglyphs count]-1 withEvent:nil select:YES];
}

-(void)_sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)ctx
{
  #pragma unused (ctx)
  [sheet orderOut:self];
  if (code != NSAlertDefaultReturn) return;
  [_glyphs setArray:_editglyphs];
  [_descriptions removeAllObjects];
  NSUInteger n, i;
  n = [_glyphs count];
  for (i = 0; i < n; i++)
  {
    NSString* glyph = [_glyphs objectAtIndex:i];
    if (![glyph length]) continue;
    NSString* uplus = [IPAServer copyUPlusForString:glyph];
    [_descriptions setObject:[_editdescriptions objectAtIndex:i] forKey:uplus];
    [uplus release];
  }
  if (delegate)
  {
    SEL sel = @selector(userGlyphsChanged:);
    if ([delegate respondsToSelector:sel])
      [delegate performSelector:sel withObject:self];
  }
}

-(void)setGlyphs:(NSArray*)glyphs andDescriptions:(NSDictionary*)descriptions
{
  if (glyphs) [_glyphs setArray:glyphs];
  else [_glyphs removeAllObjects];
  if (descriptions) [_descriptions setDictionary:descriptions];
  else [_descriptions removeAllObjects];
  //[_table reloadData];
}

-(IBAction)delete:(id)sender
{
  #pragma unused (sender)
  NSUInteger i;
  for (i = [_table numberOfRows]; i > 0; i--)
  {
    if ([_table isRowSelected:i-1])
    {
      [_editglyphs removeObjectAtIndex:i-1];
      [_editdescriptions removeObjectAtIndex:i-1];
    }
  }
  [_table reloadData];
}

#pragma mark TABLE
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
      [[self delegate] delete:self];
    }
    /*else if (c == '\t')
    {
      handled = YES;
      if ([event modifierFlags] & NSShiftKeyMask) [[self window] selectPreviousKeyView:self];
      else [[self window] selectKeyViewFollowingView:self];
    }*/
  }
  if (!handled) [super keyDown:event];
}

-(BOOL)performKeyEquivalent:(NSEvent*)evt
{
  BOOL handled = NO;
  if ([evt modifierFlags] & NSCommandKeyMask)
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

-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  #pragma unused (isLocal)
  return NSDragOperationNone;
}
@end
