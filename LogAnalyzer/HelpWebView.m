//
//  HelpWebView.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 31.03.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import "HelpWebView.h"
#import "HelpWindowController.h"
@import Carbon;

@implementation HelpWebView

//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

//------------------------------------------------------------------------------
- (void) keyDown:(NSEvent *)event
{
    switch ( event.keyCode ) {
        case kVK_Escape: {
            HelpWindowController *windowController = (HelpWindowController*)self.window.windowController;
            if ( windowController.closeCompletion ) {
                windowController.closeCompletion();
            }
        }
        break;
            
        default:
            [super keyDown:event];
    }
}


@end
