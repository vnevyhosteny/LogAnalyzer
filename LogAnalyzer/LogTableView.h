//
//  LogTableView.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

//==============================================================================
@interface LogTableView : NSTableView <NSDraggingDestination,
                                       NSDraggingSource
                                      >

@property (nonatomic, weak) id<MainViewControllerDelegate> mainViewDelegate;

- (instancetype) initWithCoder:(NSCoder *)coder;

@end
