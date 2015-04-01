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
NSString *const kHelpWindowController                = @"HelpWindowController";

//==============================================================================
@interface WindowManager()
{
    NSMutableArray *_windows;
}
@end

@implementation WindowManager

//------------------------------------------------------------------------------
+ (instancetype) sharedInstance
{
    static WindowManager   *__manager__    = nil;
    static dispatch_once_t  __once_token__ = 0;
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
        //[self->_windows addObject:[NSApplication sharedApplication].mainWindow.windowController];
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
    if ( [title length] ) {
        [windowController.window setTitle:title];
    }
    [windowController.mainViewController pasteLogItems:logItems withCompletion:nil];
    [self->_windows addObject:windowController];
    
    return windowController;
}

//------------------------------------------------------------------------------
- (HelpWindowController*) createHelpWindow
{
    return [[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateControllerWithIdentifier:kHelpWindowController];
}

//------------------------------------------------------------------------------
- (void) removeWindowController:(LogAnalyzerWindowController*)controller
{
    [self->_windows removeObject:controller];
}

//------------------------------------------------------------------------------
- (void) checkForLastLogWindowOpened
{
    if ( ![self->_windows count] ) {
        [[NSApplication sharedApplication] terminate:nil];
    }
}

#pragma mark -
#pragma mark Getters And Setters
//------------------------------------------------------------------------------
//- (void) setActiveWindowController:(LogAnalyzerWindowController *)newValue
//{
//    if ( [self->_windows count] ) {
//        for ( __weak LogAnalyzerWindowController *windowController in self->_windows ) {
//            windowController.mainViewController.dataProvider.isRemoteSessionActive = NO;
//        }
//    }
//    
//    self->_activeWindowController = newValue;
//    if ( [self->_windows indexOfObject:newValue] == NSNotFound ) {
//        [self->_windows addObject:newValue];
//    }
//
//    if ( !newValue.mainViewController.dataProvider.isRemoteSessionActive ) {
//        newValue.mainViewController.dataProvider.isRemoteSessionActive = YES;
//    }
//}
@end
