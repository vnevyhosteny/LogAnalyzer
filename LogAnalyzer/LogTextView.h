//
//  LogTextView.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 27.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LogTextView : NSTextView
@property (nonatomic, copy) void (^closeCompletion)();
@end
