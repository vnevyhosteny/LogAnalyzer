//
//  HistoryTableView.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 04.04.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

@interface HistoryTableView : NSTableView <NSDraggingDestination,
                                           NSDraggingSource
                                          >
@property (nonatomic, weak) id<MainViewControllerDelegate> mainViewDelegate;
@end
