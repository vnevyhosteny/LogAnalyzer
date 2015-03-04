//
//  LogTableView.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

extern NSString *const LogTableRowClickedNotification;
extern NSString *const kClickedRow;

//==============================================================================
@interface LogTableView : NSTableView <NSDraggingDestination,
                                       NSDraggingSource
                                      >

@property (nonatomic, weak) id<MainViewControllerDelegate> mainViewDelegate;
@property (nonatomic, readonly) NSInteger                  clickedRowAtMouseDown;
           

- (instancetype) initWithCoder:(NSCoder *)coder;
- (void) scrollToRowIndex:(NSUInteger)rowIndex;

@end
