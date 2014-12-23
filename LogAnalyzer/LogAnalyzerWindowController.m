//
//  LogAnalyzerWindowController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogAnalyzerWindowController.h"
#import "WindowManager.h"

@interface LogAnalyzerWindowController ()

@end

@implementation LogAnalyzerWindowController

//------------------------------------------------------------------------------
- (void) windowDidLoad
{
    [super windowDidLoad];
}

//------------------------------------------------------------------------------
- (MainViewController*) mainViewController
{
    return (MainViewController*)self.contentViewController;
}

//------------------------------------------------------------------------------
- (void) setActive
{
    [WindowManager sharedInstance].activeWindowController = self;
}

@end
