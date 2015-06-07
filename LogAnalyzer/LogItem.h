//
//  LogItem.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

extern NSString *const LogItemPasteboardType;

extern NSString *const kOriginalRowId;
extern NSString *const kText;
extern NSString *const kMatchFilter;
extern NSString *const kMatchRatio;

//==============================================================================
@interface LogItem : NSObject <NSPasteboardWriting, NSCoding>
@property (nonatomic, readonly)  NSUInteger originalRowId;
@property (nonatomic, copy)      NSString  *text;
@property (nonatomic, readwrite) BOOL       matchFilter;
@property (nonatomic, readwrite) BOOL       markedForDelete;
@property (nonatomic, readwrite) NSUInteger matchRatio;

+ (NSString*) trim:(NSString*)text;

- (instancetype) initWithRowId:(NSUInteger)row text:(NSString*)text;
@end
