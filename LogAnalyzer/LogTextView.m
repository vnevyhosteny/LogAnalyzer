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
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard declareTypes:[NSArray arrayWithObject: NSStringPboardType] owner: nil];
                    [pasteboard setString:[self.string substringWithRange:range] forType:NSStringPboardType];
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
