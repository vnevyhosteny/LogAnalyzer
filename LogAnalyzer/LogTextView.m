//
//  LogTextView.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 27.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogTextView.h"

@import Carbon;

@implementation LogTextView

//------------------------------------------------------------------------------
- (void) keyDown:(NSEvent *)event
{
    switch ( event.keyCode ) {
        case kVK_Return:
            if ( self.closeCompletion ) {
                self.closeCompletion();
            }
            break;
            
        case kVK_ANSI_A:
            if ( event.modifierFlags & NSCommandKeyMask ) {
                [self selectAll:nil];
            }
            else {
                [super keyDown:event];
            }
            break;

            
        case kVK_ANSI_C:
            if ( event.modifierFlags & NSCommandKeyMask ) {
                NSRange range = self.selectedRange;
                if ( range.length > 0 ) {
                    NSString     *foo        = [self.string substringWithRange:range];
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    [pasteboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
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
            
        case kVK_Escape:
            self.selectedRange = NSMakeRange( 0, 0 );
            if ( self.closeCompletion ) {
                self.closeCompletion();
            }
            break;
            
        default:
            [super keyDown:event];
    }
    
    
}

@end
