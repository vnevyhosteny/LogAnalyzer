//
//  NSColor+LogAnalyzer.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 19.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Cocoa;

@interface NSColor(LogAnalyzer)
+ (NSColor*) logTablePlainTextColor;
+ (NSColor*) logTableLineNumberColor;
+ (NSColor*) logTableMarkedColor;
+ (NSColor*) logTableMatchedColor;
+ (NSColor*) logTableSelectedMatchedColor;
@end
