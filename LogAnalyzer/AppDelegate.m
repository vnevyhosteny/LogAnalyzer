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
    [self.mainViewDelegate openLogFile];
}

//------------------------------------------------------------------------------
- (IBAction) newLogWindow:(NSMenuItem *)sender
{
    LogAnalyzerWindowController *windowController = [[WindowManager sharedInstance] createNewWindowWithLogItems:nil title:@"Log Analyzer"];
    
    [windowController.window makeKeyAndOrderFront:self];
    [windowController.mainWiewController reloadLog];
}

//------------------------------------------------------------------------------
- (IBAction) saveLogFile:(NSMenuItem *)sender
{
    [self.mainViewDelegate saveLogFile];
}

//------------------------------------------------------------------------------
- (IBAction) saveLogFileAs:(NSMenuItem *)sender
{
    [self.mainViewDelegate saveLogFileAs];
}

//------------------------------------------------------------------------------
- (IBAction) markFirstRow:(NSMenuItem *)sender
{
    [self.mainViewDelegate markFirstRow];
}

//------------------------------------------------------------------------------
- (IBAction) markLastRow:(NSMenuItem *)sender
{
    [self.mainViewDelegate markLastRow];
}

//------------------------------------------------------------------------------
- (void) applicationDidChangeScreenParameters:(NSNotification *)notification
{
    [self.mainViewDelegate reloadLog];
}


@end
