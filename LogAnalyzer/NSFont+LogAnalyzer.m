//
//  NSFont+LogAnalyzer.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 19.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "NSFont+LogAnalyzer.h"

@implementation NSFont(LogAnalyzer)

static CGFloat   const LogFontSize                  = 11.0f;
static NSString *const LogFontFamily                = @"Menlo";


//------------------------------------------------------------------------------
+ (NSFont*) logTableRegularFont
{
    static NSFont          *__font__       = nil;
    static dispatch_once_t  __once_token__ = 0;
    dispatch_once(&__once_token__, ^{
        __font__ = [[NSFontManager sharedFontManager] fontWithFamily:LogFontFamily
                                                              traits:NSUnboldFontMask
                                                              weight:0
                                                                size:LogFontSize];
    });
    return __font__;
}

//------------------------------------------------------------------------------
+ (NSFont*) logTableBoldFont
{
    static NSFont          *__font__       = nil;
    static dispatch_once_t  __once_token__ = 0;
    dispatch_once(&__once_token__, ^{
        __font__ = [[NSFontManager sharedFontManager] fontWithFamily:LogFontFamily
                                                              traits:NSBoldFontMask
                                                              weight:0
                                                                size:LogFontSize];
    });
    return __font__;
}

@end
