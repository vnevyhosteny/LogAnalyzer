//
//  LogItemsAnalyzer.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.06.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Foundation/Foundation.h>

//==============================================================================
@interface LogItemsAnalyzer : NSObject
- (instancetype) initWithLogItems:(NSArray*)logItems;
- (void) analyzeLogItemsWithCompletion:(void(^)(NSArray*))completion;
@end
