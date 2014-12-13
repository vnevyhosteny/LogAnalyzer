//
//  LogItem.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//


#import <Foundation/Foundation.h>


extern NSString *const LogItemPasteboardType;

extern NSString *const kOriginalRowId;
extern NSString *const kText;
extern NSString *const kMatchFilter;

//==============================================================================
@interface LogItem : NSObject <NSPasteboardWriting, NSCoding>
@property (nonatomic, readonly)  NSUInteger originalRowId;
@property (nonatomic, copy)      NSString  *text;
@property (nonatomic, readwrite) BOOL       matchFilter;

- (instancetype) initWithRowId:(NSUInteger)row text:(NSString*)text;
@end
