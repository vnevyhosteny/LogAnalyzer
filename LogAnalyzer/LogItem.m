//
//  LogItem.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LogItem.h"

NSString *const LogItemPasteboardType = @"cz.nefa.logitem";

NSString *const kOriginalRowId        = @"originalRowId";
NSString *const kText                 = @"text";
NSString *const kMatchFilter          = @"matchFilter";


@implementation LogItem

//------------------------------------------------------------------------------
- (instancetype) initWithRowId:(NSUInteger)row text:(NSString*)text
{
    if ( ( self = [super init] ) ) {
        self->_originalRowId = row;
        self.text            = text;
    }
    return self;
}

//------------------------------------------------------------------------------
- (instancetype) copyWithZone:(NSZone *)zone
{
    LogItem *newItem = [[[self class] allocWithZone:zone] init];
    
    newItem->_originalRowId = self.originalRowId;
    newItem.text            = self.text;
    newItem.matchFilter     = self.matchFilter;
    
    return newItem;
}

#pragma mark -
#pragma mark NSCoding Protocol Methods
//------------------------------------------------------------------------------
- (id) initWithCoder:(NSCoder *)decoder
{
    if ( ( self = [super init] ) ) {
        self->_originalRowId = ((NSNumber*)[decoder decodeObjectForKey:kOriginalRowId]).integerValue;
        self.text            = [decoder decodeObjectForKey:kText];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.originalRowId] forKey:kOriginalRowId];
    [coder encodeObject:self.text forKey:kText];
}

#pragma mark -
#pragma mark NSPasteboardWriting Methods
//------------------------------------------------------------------------------
- (NSArray *) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[LogItemPasteboardType];
}

//------------------------------------------------------------------------------
- (NSPasteboardWritingOptions) writingOptionsForType:(NSString *)type
                                          pasteboard:(NSPasteboard *)pasteboard
{
    return NSPasteboardWritingPromised;
}

//------------------------------------------------------------------------------
- (id) pasteboardPropertyListForType:(NSString *)type
{
    return ( [type isEqualToString:LogItemPasteboardType] ? [NSKeyedArchiver archivedDataWithRootObject:self] : nil );
}

//------------------------------------------------------------------------------
- (BOOL) isEqual:(id)object
{
    if ( [object isKindOfClass:[self class]] ) {
        return ( self.originalRowId == ((LogItem*)object).originalRowId );
    }
    else {
        return [super isEqual:object];
    }
}

@end
