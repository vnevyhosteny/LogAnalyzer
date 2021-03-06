//
//  WindowManager.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 12.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LogAnalyzerWindowController.h"
#import "LogAnalyzerWindow.h"
#import "HelpWindowController.h"

extern NSString *const kMainStoryboard;
extern NSString *const kMainViewController;
extern NSString *const kHelpWindowController;

//==============================================================================
@interface WindowManager : NSObject
@property (nonatomic, readwrite) LogAnalyzerWindowController *activeWindowController;
@property (nonatomic, readwrite) LogAnalyzerWindowController *sourceWindowController;

+ (instancetype) sharedInstance;

- (LogAnalyzerWindowController*) createNewWindowWithLogItems:(NSArray*)logItems title:(NSString*)title;
- (void) removeWindowController:(LogAnalyzerWindowController*)controller;
- (LogAnalyzerWindowController*) controllerWithWindow:(LogAnalyzerWindow*)window;
- (LogAnalyzerWindowController*) controllerWithWindowNumber:(NSInteger)windowNumber;
- (HelpWindowController*) createHelpWindow;
- (void) checkForLastLogWindowOpened;
- (void) addLogAnalyzerWindowController:(LogAnalyzerWindowController*)controller;
@end
