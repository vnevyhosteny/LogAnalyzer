//
//  LogSearchField.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 16.02.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogSearchField.h"
@import Carbon;

NSString *const SearchFieldBecomeFirstResponderNotification = @"_search_field_focused_";

@implementation LogSearchField

//------------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
{
    switch ( event.keyCode ) {
        case kVK_ANSI_C:
            if ( event.modifierFlags & NSCommandKeyMask ) {
                NSString *foo = [self stringValue];
                if ( [foo length] ) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    [pasteboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:self];
                    [pasteboard setString:foo forType:NSPasteboardTypeString];
                }
                else {
                    [super keyDown:event];
                }
            }
            else {
                [super keyDown:event];
            }
            break;
            
        case kVK_ANSI_V:
            if ( event.modifierFlags & NSCommandKeyMask ) {
                NSString *foo = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
                if ( [foo length] ) {
                    [self setStringValue:foo];
                }
                else {
                    [super keyDown:event];
                }
            }
            else {
                [super keyDown:event];
            }
            break;
            
        default:
            [super keyDown:event];
    }

}

//------------------------------------------------------------------------------
- (BOOL) becomeFirstResponder
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SearchFieldBecomeFirstResponderNotification object:self];
    return [super becomeFirstResponder];
}


@end
