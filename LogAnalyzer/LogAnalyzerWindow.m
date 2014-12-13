//
//  LogAnalyzerWindow.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogAnalyzerWindow.h"
#import "WindowManager.h"

@implementation LogAnalyzerWindow

//------------------------------------------------------------------------------
- (void) close
{
    [[WindowManager sharedInstance] removeWindowController:self.windowController];
    [super close];
}
@end
