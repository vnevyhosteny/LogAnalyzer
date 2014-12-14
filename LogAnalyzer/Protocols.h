//
//  Protocols.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#ifndef LogAnalyzer_Protocols_h
#define LogAnalyzer_Protocols_h

@class LogItemViewController;

@protocol MainViewControllerDelegate <NSObject>
- (void) appendLogFromFile:(NSString*)fileName;
- (void) textDidSelected:(LogItemViewController*)controller;
- (void) reloadLog;
- (void) createNewWindowWithLogItems:(NSArray*)logItems atPoint:(NSPoint)point;
- (BOOL) isDragAndDropEnabled;
- (void) startActivityIndicator;
- (void) startActivityIndicatorWithMessage:(NSString*)message;
- (void) stopActivityIndicator;

@end

#endif
