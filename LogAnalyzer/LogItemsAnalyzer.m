//
//  LogItemsAnalyzer.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.06.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogItemsAnalyzer.h"
#import "LogItem.h"

//==============================================================================
@interface LogItemsAnalyzer()
{
    NSCharacterSet   *_nonDateSet;
    __weak NSArray   *_logItems;
    dispatch_queue_t  _queue;
}
@end

//==============================================================================
@implementation LogItemsAnalyzer

//------------------------------------------------------------------------------
- (instancetype) init
{
    if ( ( self = [super init] ) ) {
        self->_nonDateSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789-.: "] invertedSet];
        self->_queue      = dispatch_queue_create( "LogAnalyzer.analyzerQueue", DISPATCH_QUEUE_CONCURRENT );
        dispatch_set_target_queue( self->_queue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0));
    }
    return self;
}

//------------------------------------------------------------------------------
- (instancetype) initWithLogItems:(NSArray*)logItems
{
    if ( [self init] ) {
        self->_logItems = logItems;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) analyzeLogItemsWithCompletion:(void(^)(NSArray*))completion
{
    if ( !completion ) {
        return;
    }
    
    size_t count = [self->_logItems count];
    if ( !count ) {
        completion( nil );
        return;
    }
    
    dispatch_apply( count, self->_queue, ^(size_t index) {
        LogItem *logItem   = [self->_logItems objectAtIndex:index];
        logItem.matchRatio = [self countMatchRatioForLogItem:logItem];
    });
    
    NSMutableArray *sortedLogItems = [[NSMutableArray alloc] initWithArray:self->_logItems copyItems:YES];
    
    @autoreleasepool {
        [sortedLogItems sortUsingComparator:^NSComparisonResult(LogItem *li1, LogItem *li2) {
            
            if ( li1.matchRatio < li2.matchRatio ) {
                return NSOrderedAscending;
            }
            else if ( li1.matchRatio > li2.matchRatio ) {
                return NSOrderedDescending;
            }
            else {
                return [li1.text compare:li2.text];
            }
        }];
    }
    
    completion( [[NSArray alloc] initWithArray:sortedLogItems copyItems:NO] );

}

//------------------------------------------------------------------------------
- (NSUInteger) countMatchRatioForLogItem:(LogItem*)logItem
{
    NSUInteger  result = 0;
    
    @autoreleasepool {
        
        NSUInteger  location          = [logItem.text rangeOfCharacterFromSet:self->_nonDateSet].location;
        NSString   *textToMatch       = ( location == NSNotFound ? logItem.text : [logItem.text substringFromIndex:location] );
        
        NSString   *matchedText;
        
        const char *p1;
        const char *p2;
        
        for ( __weak LogItem *item in self->_logItems ) {
            if ( item != logItem ) {
                location          = [item.text rangeOfCharacterFromSet:self->_nonDateSet].location;
                matchedText       = ( location == NSNotFound ? item.text : [item.text substringFromIndex:location] );
                
                p1                = [textToMatch UTF8String];
                p2                = [matchedText UTF8String];
                
                while ( ( *p1 == *p2 ) && *(++p1) && *(++p2) ) {
                    result++;
                }
            }
        }
    }
    
    return result;
}

@end


