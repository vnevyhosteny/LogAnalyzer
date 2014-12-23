//
//  LogAnalyzerWindowController.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainViewController.h"

//==============================================================================
@interface LogAnalyzerWindowController : NSWindowController
@property (nonatomic, readonly) MainViewController *mainViewController;
- (void) setActive;
@end
