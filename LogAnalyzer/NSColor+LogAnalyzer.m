//
//  NSColor+LogAnalyzer.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 19.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "NSColor+LogAnalyzer.h"

@implementation NSColor(LogAnalyzer)

static CGFloat const FullColor = 255.0f;
static CGFloat const FullAlpha = 1.0f;

//------------------------------------------------------------------------------
+ (NSColor*) logTablePlainTextColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        __color__ = [NSColor colorWithCalibratedRed:33.0f/FullColor green:33.0f/FullColor blue:33.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}

//------------------------------------------------------------------------------
+ (NSColor*) logTableLineNumberColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        __color__ = [NSColor colorWithCalibratedRed:180.0f/FullColor green:180.0f/FullColor blue:200.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}

//------------------------------------------------------------------------------
+ (NSColor*) logTableMarkedColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        __color__ = [NSColor colorWithCalibratedRed:0.0f/FullColor green:140.0f/FullColor blue:20.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}

//------------------------------------------------------------------------------
+ (NSColor*) logTableMatchedColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        __color__ = [NSColor colorWithCalibratedRed:10.0f/FullColor green:100.0f/FullColor blue:255.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}

//------------------------------------------------------------------------------
+ (NSColor*) logTableSelectedMatchedColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        //__color__ = [NSColor colorWithCalibratedRed:60.0f/FullColor green:150.0f/FullColor blue:255.0f/FullColor alpha:FullAlpha];
        __color__ = [NSColor colorWithCalibratedRed:180.0f/FullColor green:180.0f/FullColor blue:255.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}


//------------------------------------------------------------------------------
+ (NSColor*) historyTablePlainTextColor
{
    static NSColor         *__color__      = nil;
    static dispatch_once_t  __once_token__ = 0;
    
    dispatch_once( &__once_token__, ^{
        //__color__ = [NSColor colorWithCalibratedRed:233.0f/FullColor green:233.0f/FullColor blue:233.0f/FullColor alpha:FullAlpha];
        __color__ = [NSColor colorWithCalibratedRed:33.0f/FullColor green:33.0f/FullColor blue:33.0f/FullColor alpha:FullAlpha];
    });
    return __color__;
}


@end
