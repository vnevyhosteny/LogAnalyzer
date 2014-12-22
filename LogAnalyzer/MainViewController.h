//
//  MainViewController.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 06.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

extern NSString *const kRowId;
extern NSString *const kLogItem;

@interface MainViewController : NSViewController <NSTableViewDataSource,
                                                  NSTableViewDelegate,
                                                  MainViewControllerDelegate,
                                                  NSTextViewDelegate,
                                                  NSWindowDelegate
                                                 >

- (void) appendLogFromFile:(NSString*)fileName;
- (void) pasteLogItems:(NSArray*)logItems withCompletion:(void(^)(void))completion;
- (void) reloadLog;

@end

