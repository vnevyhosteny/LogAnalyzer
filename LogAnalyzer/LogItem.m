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
NSString *const kMarkedForDelete      = @"markedForDelete";
NSString *const kMatchRatio           = @"matchRatio";

@implementation LogItem

//------------------------------------------------------------------------------
+ (NSString*) trim:(NSString*)text
{
    NSUInteger len   = [text length];
    NSRange    range = ( [text length] ? [text rangeOfString:@"\n" options:NSBackwardsSearch] : NSMakeRange( NSNotFound, 0 ) );
    
    if ( range.location != NSNotFound ) {
        len = range.location;
        while ( len && ( [text characterAtIndex:len] == '\n' ) ) {
            len--;
        }
        len++;
    }
    
    return ( len ? [text substringToIndex:len] : text );
}


//------------------------------------------------------------------------------
- (instancetype) initWithRowId:(NSUInteger)row text:(NSString*)text
{
    if ( ( self = [super init] ) ) {
        self->_originalRowId = row;
        self.text            = [LogItem trim:text];
        self.markedForDelete = NO;
        self->_matchRatio    = NSNotFound;
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
    newItem.markedForDelete = self.markedForDelete;
    newItem->_matchRatio    = self.matchRatio;
    
    return newItem;
}

#pragma mark -
#pragma mark NSCoding Protocol Methods
//------------------------------------------------------------------------------
- (id) initWithCoder:(NSCoder *)decoder
{
    if ( ( self = [super init] ) ) {
        self->_originalRowId = ((NSNumber*)[decoder decodeObjectForKey:kOriginalRowId]).integerValue;
        self.matchFilter     = ((NSNumber*)[decoder decodeObjectForKey:kMatchFilter]).boolValue;
        self.text            = [decoder decodeObjectForKey:kText];
        self.markedForDelete = ((NSNumber*)[decoder decodeObjectForKey:kMarkedForDelete]).boolValue;
        self->_matchRatio    = ((NSNumber*)[decoder decodeObjectForKey:kMatchRatio]).integerValue;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.originalRowId] forKey:kOriginalRowId];
    [coder encodeObject:self.text forKey:kText];
    [coder encodeObject:[NSNumber numberWithBool:self.matchFilter] forKey:kMatchFilter];
    [coder encodeObject:[NSNumber numberWithBool:self.markedForDelete] forKey:kMarkedForDelete];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.matchRatio] forKey:kMatchRatio];
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
