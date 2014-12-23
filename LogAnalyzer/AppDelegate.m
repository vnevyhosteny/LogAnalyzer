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

@interface AppDelegate ()

@end

@implementation AppDelegate

#define ActiveViewController() [[[WindowManager sharedInstance] activeWindowController] mainViewController]

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
- (IBAction) copyAction:(NSMenuItem *)sender
{
    [WindowManager sharedInstance].sourceWindowController = [WindowManager sharedInstance].activeWindowController;
}

//------------------------------------------------------------------------------
- (IBAction) pasteAction:(NSMenuItem *)sender
{
    LogAnalyzerWindowController *sourceWindowController = [WindowManager sharedInstance].sourceWindowController;
    LogAnalyzerWindowController *activeWindowController = [WindowManager sharedInstance].activeWindowController;
    
    if ( sourceWindowController && activeWindowController ) {
        [activeWindowController.mainViewController pasteLogItems:sourceWindowController.mainViewController.dataProvider.matchedData withCompletion:^{
            [activeWindowController.mainViewController reloadLog];
            dispatch_async( dispatch_get_main_queue(), ^{
                [activeWindowController.window setTitle:sourceWindowController.mainViewController.dataProvider.filter.text];
            });
        }];
    }
}

//------------------------------------------------------------------------------
- (IBAction) findAction:(NSMenuItem *)sender
{
    [ActiveViewController() find];
}


//------------------------------------------------------------------------------
- (void) applicationDidChangeScreenParameters:(NSNotification *)notification
{
    [self.mainViewDelegate reloadLog];
}


@end
