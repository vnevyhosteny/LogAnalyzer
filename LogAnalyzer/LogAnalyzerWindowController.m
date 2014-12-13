//
//  LogAnalyzerWindowController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogAnalyzerWindowController.h"


@interface LogAnalyzerWindowController ()

@end

@implementation LogAnalyzerWindowController

//------------------------------------------------------------------------------
- (void) windowDidLoad
{
    [super windowDidLoad];
}

//------------------------------------------------------------------------------
- (MainViewController*) mainWiewController
{
    return (MainViewController*)self.contentViewController;
}

@end
