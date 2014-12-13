//
//  WindowManager.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

@import Cocoa;
#import "WindowManager.h"


NSString *const kMainStoryboard                     = @"Main";
NSString *const kMainViewController                 = @"MainViewController";

@interface WindowManager()
{
    NSMutableArray *_windows;
}
@end

@implementation WindowManager

//------------------------------------------------------------------------------
+ (instancetype) sharedInstance
{
    static WindowManager *__manager__ = nil;
    static dispatch_once_t __once_token__ = 0;
    dispatch_once( &__once_token__, ^{
        __manager__ = [WindowManager new];
    });
    return __manager__;
}

//------------------------------------------------------------------------------
- (instancetype) init
{
    if ( ( self = [super init] ) ) {
        self->_windows = [NSMutableArray new];
        [self->_windows addObject:[NSApplication sharedApplication].mainWindow.windowController];
    }
    return self;
}

//------------------------------------------------------------------------------
- (LogAnalyzerWindowController*) controllerWithWindow:(LogAnalyzerWindow*)window
{
    for ( __weak LogAnalyzerWindowController *controller in self->_windows ) {
        if ( controller.window.windowNumber == window.windowNumber ) {
            return controller;
        }
    }
    return nil;
}

//------------------------------------------------------------------------------
- (LogAnalyzerWindowController*) controllerWithWindowNumber:(NSInteger)windowNumber
{
    for ( __weak LogAnalyzerWindowController *controller in self->_windows ) {
        if ( controller.window.windowNumber == windowNumber ) {
            return controller;
        }
    }
    return nil;
}


//------------------------------------------------------------------------------
- (LogAnalyzerWindowController*) createNewWindowWithLogItems:(NSArray*)logItems title:(NSString*)title
{
    LogAnalyzerWindowController *windowController = [[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateInitialController];
    [windowController.window setTitle:title];
    [windowController.mainWiewController pasteLogItems:logItems];
    [self->_windows addObject:windowController];
    
    return windowController;
}

//------------------------------------------------------------------------------
- (void) removeWindowController:(LogAnalyzerWindowController*)controller
{
    [self->_windows removeObject:controller];
    if ( ![self->_windows count] ) {
        [[NSApplication sharedApplication] terminate:nil];
    }
}

@end
