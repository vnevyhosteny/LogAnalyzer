//
//  AppDelegate.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 06.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Protocols.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, weak) id<MainViewControllerDelegate>  mainViewDelegate;
@end

