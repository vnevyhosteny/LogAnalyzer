//
//  HelpWindowController.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 31.03.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HelpWindowController : NSWindowController
@property (nonatomic, copy) void (^closeCompletion)();
@end
