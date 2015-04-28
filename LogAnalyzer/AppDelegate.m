//
//  AppDelegate.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 06.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "AppDelegate.h"
#import "MainViewController.h"
#import "WindowManager.h"
#import "LogAnalyzerWindowController.h"
#import "HelpWindowController.h"
#import "HistoryTableView.h"

@interface AppDelegate ()
@property (nonatomic, strong )HelpWindowController *helpWindowController;
@end

@implementation AppDelegate

#define ActiveViewController() [self mainWindowController]


//------------------------------------------------------------------------------
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    CGRect displayFrame = [[NSScreen deepestScreen] frame];
//    CGRect windowFrame  = [NSApplication sharedApplication].mainWindow.frame;
}


//------------------------------------------------------------------------------
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

//------------------------------------------------------------------------------
- (BOOL) application:(NSApplication *)sender openFile:(NSString *)path
{
    if ( [path length] && ( [[path pathExtension] rangeOfString:@"log" options:NSCaseInsensitiveSearch].location != NSNotFound ) ) {
        [self.mainViewDelegate appendLogFromFile:path];
    }
    return YES;
}

//------------------------------------------------------------------------------
- (IBAction) openLogFile:(NSMenuItem *)sender
{
    [ActiveViewController() openLogFile];
}

//------------------------------------------------------------------------------
- (IBAction) newLogWindow:(NSMenuItem *)sender
{
    LogAnalyzerWindowController *windowController = [[WindowManager sharedInstance] createNewWindowWithLogItems:nil title:@"Log Analyzer"];
    
    [windowController.window makeKeyAndOrderFront:self];
    [windowController.mainViewController reloadLog];
}

//------------------------------------------------------------------------------
- (IBAction) saveLogFile:(NSMenuItem *)sender
{
    [ActiveViewController() saveLogFile];
}

//------------------------------------------------------------------------------
- (IBAction) saveLogFileAs:(NSMenuItem *)sender
{
    [ActiveViewController() saveLogFileAs];
}

//------------------------------------------------------------------------------
- (IBAction) markFirstRow:(NSMenuItem *)sender
{
    [ActiveViewController() markFirstRow];
}

//------------------------------------------------------------------------------
- (IBAction) markLastRow:(NSMenuItem *)sender
{
    [ActiveViewController() markLastRow];
}

//------------------------------------------------------------------------------
- (IBAction) moveToNextMatchedRow:(NSMenuItem *)sender
{
    [ActiveViewController() moveToNextMatchedRow];
}

//------------------------------------------------------------------------------
- (IBAction) moveToPreviousMatchedRow:(NSMenuItem *)sender
{
    [ActiveViewController() moveToPreviousMatchedRow];
}

//------------------------------------------------------------------------------
- (IBAction) showInfoAction:(NSMenuItem *)sender
{
    [ActiveViewController() toggleShowInfoOnOff];
}

//------------------------------------------------------------------------------
- (IBAction) copyAction:(NSMenuItem *)sender
{
    id responder = [NSApplication sharedApplication].mainWindow.firstResponder;
    if ( [responder isKindOfClass:[NSTextView class]] ) {
        [(NSTextView*)responder copy:nil];
    }
    else {
        WindowManager *windowManager                                             = [WindowManager sharedInstance];
        windowManager.activeWindowController.mainViewController.currentResponder = responder;
        windowManager.sourceWindowController                                     = windowManager.activeWindowController;
    }
}

//------------------------------------------------------------------------------
- (IBAction) pasteAction:(NSMenuItem *)sender
{
    id responder = [NSApplication sharedApplication].mainWindow.firstResponder;
    if ( [responder isKindOfClass:[NSTextView class]] ) {
        [(NSTextView*)responder paste:nil];
    }
    else {
        WindowManager      *windowManager    = [WindowManager sharedInstance];
        MainViewController *sourceController = [[windowManager sourceWindowController] mainViewController];
        MainViewController *activeController = [[windowManager activeWindowController] mainViewController];
        
        if ( sourceController && activeController ) {
            NSArray *data = ( [sourceController.currentResponder isKindOfClass:[HistoryTableView class]]
                              ?
                              sourceController.dataProvider.historyData
                              :
                              sourceController.dataProvider.matchedData
                            );
            [activeController pasteLogItems:data withCompletion:^{
                [activeController reloadLog];
                if ( [sourceController.dataProvider.filter.text length] ) {
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [activeController.view.window setTitle:sourceController.dataProvider.filter.text];
                    });
                }
            }];
        }
    }
}

//------------------------------------------------------------------------------
- (IBAction) findAction:(NSMenuItem *)sender
{
    [ActiveViewController() find];
}

//------------------------------------------------------------------------------
- (IBAction) toggleBrowseForClientAction:(NSMenuItem *)sender
{
    BOOL isBrowsingForClient = [[ActiveViewController() dataProvider] isRemoteSessionActive];
    sender.state             = ( isBrowsingForClient ? NSOffState : NSOnState );
    [ActiveViewController() toggleBrowseOnOffAction:nil];
}

//------------------------------------------------------------------------------
- (IBAction) showHelpAction:(NSMenuItem *)sender
{
    if ( !self.helpWindowController ) {
        self.helpWindowController    = [[WindowManager sharedInstance] createHelpWindow];
        __weak AppDelegate *weakSelf = self;
        
        self.helpWindowController.closeCompletion = ^{
            AppDelegate *appDelegate = weakSelf;
            [[appDelegate helpWindowController] close];
            [appDelegate setHelpWindowController:nil];
        };
        
        [self.helpWindowController.window makeKeyAndOrderFront:self];
    }
}


//------------------------------------------------------------------------------
- (void) applicationDidChangeScreenParameters:(NSNotification *)notification
{
    [self.mainViewDelegate reloadLog];
}

//------------------------------------------------------------------------------
- (MainViewController*) mainWindowController
{
    MainViewController *result = [[[WindowManager sharedInstance] activeWindowController] mainViewController];
    if ( !result ) {
        result = [(LogAnalyzerWindowController*)[NSApplication sharedApplication].mainWindow.windowController mainViewController];
    }
    return result;
}

//------------------------------------------------------------------------------
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application
{
    return YES;
}

//------------------------------------------------------------------------------
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if ( self.helpWindowController ) {
        self.helpWindowController.closeCompletion();
    }
    return NSTerminateNow;
}

@end
