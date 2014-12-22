//
//  LogTablePopup.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 18.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LogItem.h"
#import "Protocols.h"

@interface LogTablePopup : NSViewController
@property (nonatomic, weak) LogItem                        *logItem;
@property (nonatomic, weak) id<MainViewControllerDelegate>  mainViewDelegate;
@end
