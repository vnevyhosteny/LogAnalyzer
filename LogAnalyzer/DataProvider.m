//
//  DataProvider.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DataProvider.h"
#import "LogItemsAnalyzer.h"

NSString *const ServiceName                        = @"rlogger";
NSString *const ReloadLogNeededNotification        = @"_reload_log_needed_notification_";
NSString *const RemoteLogItemsReceivedNotification = @"_remote_log_items_received_notification_";

//==============================================================================
@interface DataProvider()
{
    dispatch_queue_t  _sync_queue;
    dispatch_queue_t  _remote_queue;

    NSTimer          *_remoteTimer;
    NSMutableArray   *_remoteLogItems;
}
- (void) mergeRemoteLogItems;
@end

//==============================================================================
@implementation DataProvider

@synthesize originalData          = _originalData;
@synthesize filteredData          = _filteredData;
@synthesize historyData           = _historyData;
@synthesize matchedRowsIndexSet   = _matchedRowsIndexSet;
@synthesize unmatchedRowsIndexSet = _unmatchedRowsIndexSet;
@synthesize matchedRowsIndexDict  = _matchedRowsIndexDict;
@synthesize isDataAnalysisRunning = _isDataAnalysisRunning;

//------------------------------------------------------------------------------
- (instancetype) init
{
    if ( ( self = [super init] ) ) {
        self->_filter                = [LogItem new];
        self->_filterType            = FILTER_SEARCH;
        self->_sync_queue            = dispatch_queue_create( "dataprovider.sync_queue", DISPATCH_QUEUE_SERIAL );
        self->_remote_queue          = dispatch_queue_create( "dataprovider.remote_queue", DISPATCH_QUEUE_SERIAL );
        self->_remoteLogItems        = [NSMutableArray new];
        self->_historyData           = [NSMutableArray new];
        self->_rowFrom               = NSNotFound;
        self->_rowTo                 = NSNotFound;
        self->_originalLogFileName   = nil;
        self->_matchedRowsIndexSet   = nil;
        self->_unmatchedRowsIndexSet = nil;
        self->_matchedRowsIndexDict  = nil;
        self->_sessionContainer      = nil;
        self->_isDataAnalysisRunning = NO;
        
        [self resetMatchCountersAndIndexes];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) dealloc
{
    [self->_sessionContainer stopBrowse];
    self->_filteredData = nil;
    self->_originalData = nil;
    self->_historyData  = nil;
}

#pragma mark -
#pragma mark Getters And Setters
//------------------------------------------------------------------------------
- (BOOL) isIsSearching
{
    __block BOOL result;
    dispatch_sync( self->_sync_queue, ^{
        result = self->_isSearching;
    });
    return result;
}

//------------------------------------------------------------------------------
- (void) setIsSearching:(BOOL)newValue
{
    dispatch_sync( self->_sync_queue, ^{
        self->_isSearching = newValue;
    });
}


//------------------------------------------------------------------------------
- (void) resetMatchCountersAndIndexes
{
    self->_matchedRowsCount       = 0;
    self->_currentMatchedRow      = NSNotFound;
    self->_firstMatchedRowIndex   = NSNotFound;
    self->_currentMatchedRowIndex = NSNotFound;
    self->_lastMatchedRowIndex    = NSNotFound;
    self->_matchedRowsIndexSet    = nil;
    self->_unmatchedRowsIndexSet  = nil;
    self->_matchedRowsIndexDict   = nil;
}

//------------------------------------------------------------------------------
- (void) updateMatchCountersAndIndexesWithLogItem:(LogItem*)logItem withIndex:(NSUInteger)index
{
    if ( logItem.matchFilter ) {
        
        self->_matchedRowsCount++;
        self->_lastMatchedRowIndex = index;
        
        if ( self->_firstMatchedRowIndex == NSNotFound ) {
            self->_firstMatchedRowIndex   = index;
            self->_currentMatchedRowIndex = index;
            self->_currentMatchedRow      = 0;
        }
    }
}

//------------------------------------------------------------------------------
- (void) updateMatchCountersAndIndexesWithOriginalData
{
    [self resetMatchCountersAndIndexes];
    
    if ( [self->_originalData count] ) {
        NSUInteger index = 0;
        for ( __weak LogItem *logItem in self->_originalData ) {
            [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:index++];
        }
    }
}

//------------------------------------------------------------------------------
- (void) matchFilteredDataWithCompletion:(void(^)( BOOL completed ))completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        // Wait for previous search interruption
        NSRunLoop            *runLoop      = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSRunLoopCommonModes];
        
        static CGFloat const  WaitInterval = 0.1f;
        
        while ( self.isSearching ) {
            if ( runLoop ) {
                [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:WaitInterval]];
            }
            else {
                [NSThread sleepForTimeInterval:WaitInterval];
            }
        }
        
        dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            self.isSearching = YES;
            BOOL result      = YES;
            
            @synchronized( self ) {
                NSPredicate *predicate = ( [self.filter.text length] ? [NSPredicate predicateWithFormat:@"((text LIKE [cd] %@))" argumentArray:@[[NSString stringWithFormat:@"*%@*", self.filter.text]]] : nil );
                NSArray     *aux       = ( predicate ? [[NSArray alloc] initWithArray:[self->_originalData filteredArrayUsingPredicate:predicate] copyItems:NO] : nil );
                
                if ( self.isSearching ) {
                    
                    [self resetMatchCountersAndIndexes];
                    
                    BOOL       isAuxEmpty         = !((BOOL)[aux count]);
                    NSUInteger count              = [self->_originalData count];
                    
                    __weak     LogItem *logItem;
                    for ( NSUInteger i = 0; i < count; i++ ) {
                        
                        if ( !self.isSearching ) {
                            result = NO;
                            break;
                        }
                        
                        logItem             = [self->_originalData objectAtIndex:i];
                        logItem.matchFilter = ( isAuxEmpty ? NO : ( [aux indexOfObject:logItem] != NSNotFound ) );
                        [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:i];
                    }
                }
                else {
                    result = NO;
                }
                
                self->_filteredData = nil;
                [self filteredDataWithOriginalData];
            }
            
            self.isSearching = NO;
            
            if ( completion ) {
                completion( result );
            }
        });
    });
}


//------------------------------------------------------------------------------
- (NSArray*) filteredData
{
    @synchronized( self ) {
        if ( ![self->_filteredData count] && [self->_originalData count] ) {
            
            [self resetMatchCountersAndIndexes];
            
            if ( [self.filter.text length] ) {
                
                if ( self.filterType == FILTER_SEARCH ) {
                    
                    NSUInteger count = [self->_originalData count];
                    __weak     LogItem *logItem;
                    
                    for ( NSUInteger i = 0; i < count; i++ ) {
                        logItem             = [self->_originalData objectAtIndex:i];
                        logItem.matchFilter = ( [self.filter.text length] && ( [logItem.text rangeOfString:self.filter.text options:NSCaseInsensitiveSearch].location != NSNotFound ) );
                        [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:i];
                    }
                    
                    self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:NO];
                }
                else {
                    NSPredicate *predicate = ( [self.filter.text length] ? [NSPredicate predicateWithFormat:@"((text LIKE [cd] %@))" argumentArray:@[[NSString stringWithFormat:@"*%@*", self.filter.text]]] : nil );
                    self->_filteredData    = ( predicate
                                               ?
                                               [[NSMutableArray alloc] initWithArray:[self->_originalData filteredArrayUsingPredicate:predicate] copyItems:NO]
                                               :
                                               [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:NO]
                                             );
                    
                    for ( __weak LogItem *logItem in self->_filteredData ) {
                        logItem.matchFilter = NO;
                    }
                    
                    self->_matchedRowsCount = [self->_filteredData count];
                    if ( self->_matchedRowsCount ) {
                        self->_firstMatchedRowIndex   = 0;
                        self->_currentMatchedRowIndex = 0;
                        self->_currentMatchedRow      = 0;
                        self->_lastMatchedRowIndex    = self->_matchedRowsCount;
                    }
                }
            }
            else {
                self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:NO];
                for ( __weak LogItem *logItem in self->_filteredData ) {
                    logItem.matchFilter = NO;
                }
            }
        }
        
        return self->_filteredData;
    }
}

//------------------------------------------------------------------------------
- (NSArray*) filteredDataWithOriginalData
{
    @synchronized( self ) {
        if ( ![self->_filteredData count] ) {
            
            [self resetMatchCountersAndIndexes];
            
            self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:NO];
            NSUInteger count    = [self->_filteredData count];
            
            __weak LogItem *logItem;
            for ( NSUInteger i = 0; i < count; i++ ) {
                logItem = [self->_filteredData objectAtIndex:i];
                [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:i];
            }
        }
        
        return self->_filteredData;
    }
}


//------------------------------------------------------------------------------
- (NSArray*) matchedData
{
    NSPredicate    *predicate = [NSPredicate predicateWithFormat:@"((matchFilter == %d))" argumentArray:@[@YES]];
    NSMutableArray *result;
    
    @synchronized( self ) {
        result = [[NSMutableArray alloc] initWithArray:[self->_originalData filteredArrayUsingPredicate:predicate] copyItems:YES];
    }
    
    for ( __weak LogItem *logItem in result ) {
        logItem.matchFilter = NO;
    }
    
    return result;
}

//------------------------------------------------------------------------------
- (NSDictionary*) matchedRowsIndexDict
{
    if ( !self->_matchedRowsIndexDict ) {
        @synchronized( self ) {
            NSMutableDictionary *aux   = [[NSMutableDictionary alloc] initWithCapacity:[self.filteredData count]];
            NSUInteger           index = 0;
            NSUInteger           order = 0;
            
            for ( __weak LogItem *logItem in self.filteredData ) {
                if ( logItem.matchFilter ) {
                    [aux setValue:[NSNumber numberWithUnsignedInteger:order++] forKey:[NSString stringWithFormat:@"%lu", index]];
                }
                index++;
            }
            
            self->_matchedRowsIndexDict = [[NSDictionary alloc] initWithDictionary:aux];
        }
    }
    return self->_matchedRowsIndexDict;
}

//------------------------------------------------------------------------------
- (NSIndexSet*) matchedRowsIndexSet
{
    if ( !self->_matchedRowsIndexSet ) {
        
        NSMutableIndexSet *aux   = [NSMutableIndexSet new];
        NSUInteger         index = 0;
        @synchronized( self ) {
            for ( __weak LogItem *logItem in self.filteredData ) {
                if ( logItem.matchFilter ) {
                    [aux addIndex:index];
                }
                index++;
            }
        }
        self->_matchedRowsIndexSet = [[NSIndexSet alloc] initWithIndexSet:aux];
    }
    return self->_matchedRowsIndexSet;
}

//------------------------------------------------------------------------------
- (NSIndexSet*) unmatchedRowsIndexSet
{
    if ( !self->_unmatchedRowsIndexSet ) {
        
        NSMutableIndexSet *aux   = [NSMutableIndexSet new];
        NSUInteger         index = 0;
        
        @synchronized( self ) {
            for ( __weak LogItem *logItem in self.filteredData ) {
                if ( !logItem.matchFilter ) {
                    [aux addIndex:index];
                }
                index++;
            }
        }
        
        self->_unmatchedRowsIndexSet = [[NSIndexSet alloc] initWithIndexSet:aux];
    }
    return self->_unmatchedRowsIndexSet;
}

//------------------------------------------------------------------------------
- (void) writeMatchedLogItems:(BOOL)matched toPasteboard:(NSPasteboard *)pboard
{
    NSMutableArray *aux = [NSMutableArray new];
    for ( __weak LogItem *logItem in self.filteredData ) {
        if ( matched && logItem.matchFilter ) {
            [aux addObject:logItem];
        }
        else if ( !matched && !logItem.matchFilter ) {
            [aux addObject:logItem];
        }
    }
    
    if ( [aux count] ) {
        [pboard writeObjects:aux];
    }
}


//------------------------------------------------------------------------------
- (void) setRowTo:(NSUInteger)newValue
{
    if ( ( self.rowFrom != NSNotFound ) && ( newValue < self.rowFrom ) ) {
        self->_rowFrom = NSNotFound;
        self->_rowTo   = NSNotFound;
    }
    else {
        self->_rowTo   = newValue;
    }
}

//------------------------------------------------------------------------------
- (void) deleteRow:(NSUInteger)row
{
    @synchronized( self ) {
        if ( row < [self->_filteredData count] ) {
            LogItem *logItem = [self->_filteredData objectAtIndex:row];
            NSUInteger index = [self->_originalData indexOfObject:logItem];
            if ( index != NSNotFound ) {
                
                NSUInteger i = 0;
                for ( __weak LogItem *historyLogItem in self.historyData ) {
                    if ( historyLogItem.originalRowId == logItem.originalRowId ) {
                        [self.historyData removeObjectAtIndex:i];
                        break;
                    }
                    else {
                        i++;
                    }
                }
                
                NSMutableArray *aux = [NSMutableArray arrayWithArray:self->_originalData];
                [aux removeObjectAtIndex:index];
                self->_originalData = [[NSMutableArray alloc] initWithArray:aux];
                self->_filteredData = nil;
            }
        }
    }
}

//------------------------------------------------------------------------------
- (void) matchAllRowsWithCompletion:(void (^)())completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized( self ) {
            
            self->_filteredData = nil;
            
            dispatch_apply( [self->_originalData count], dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                __weak LogItem *logItem = [self->_originalData objectAtIndex:i];
                logItem.matchFilter = YES;
            });
            
            [self filteredDataWithOriginalData];
            
            if ( completion ) {
                completion();
            }
        }
    });
}

//------------------------------------------------------------------------------
- (BOOL) isRemoteSessionActive
{
    return ( self->_sessionContainer != nil );
}

//------------------------------------------------------------------------------
- (void) setIsRemoteSessionActive:(BOOL)newValue
{
    self->_sessionContainer = ( newValue ? [[SessionContainer alloc] initWithDisplayName:[[NSHost currentHost] name] serviceType:ServiceName delegate:self] : nil );
}

//------------------------------------------------------------------------------
- (void) addLogItemToHistory:(LogItem*)logItem
{
    if ( [self->_historyData indexOfObject:logItem] == NSNotFound ) {
        [self->_historyData addObject:logItem];
    }
}

//------------------------------------------------------------------------------
- (void) searchForRowIndexInFilteredDataWithItem:(LogItem*)logItem withCompletion:(void(^)( NSUInteger rowIndex))completion
{
    if ( !logItem || ![self.filteredData count] ) {
        if ( completion ) {
            completion( NSNotFound );
        }
        return;
    }
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSUInteger startIndex = logItem.originalRowId;
        NSInteger  step       = 0;
        NSUInteger count      = [self.filteredData count];
        
        if ( [self.filteredData count] <= startIndex ) {
            startIndex = count - 1;
            step       = -1;
        }
        else {
            LogItem *startLogItem = [self.filteredData objectAtIndex:startIndex];
            if ( startLogItem.originalRowId == logItem.originalRowId ) {
                if ( completion ) {
                    completion( startIndex );
                }
                return;
            }
            else {
                step = ( ( startLogItem.originalRowId < logItem.originalRowId ) ? 1 : -1 );
            }
        }
        
        LogItem    *currentLogItem;
        NSUInteger  result = NSNotFound;
        
        for ( NSUInteger i = startIndex; ( i > 0 && i < count ); i += step ) {
            currentLogItem = [self.filteredData objectAtIndex:i];
            if ( currentLogItem.originalRowId == logItem.originalRowId ) {
                result = i;
                break;
            }
        }
        
        if ( completion ) {
            completion( result );
        }
    });
}

//------------------------------------------------------------------------------
- (void) deleteHistoryRowsWithIndexes:(NSIndexSet*)indexSet completion:(void(^)())completion
{
    NSUInteger       currentIndex = [indexSet firstIndex];
    
    while ( currentIndex != NSNotFound) {
        if ( currentIndex < [self.historyData count] ) {
            ((LogItem*)[self.historyData objectAtIndex:currentIndex]).markedForDelete = YES;
        }
        currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
    }
    
    NSUInteger       i     = 0;
    LogItem         *logItem;
    
    while ( i < [self.historyData count] ) {
        logItem = [self.historyData objectAtIndex:i];
        if ( logItem.markedForDelete ) {
            [self.historyData removeObjectAtIndex:i];
        }
        else {
            i++;
        }
    }
    
    if ( completion ) {
        completion();
    }
}

#pragma mark -
#pragma mark Data
//------------------------------------------------------------------------------
- (void) appendLogFromFile:(NSString*)fileName completion:(void (^)(NSError*))completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSError          *error    = nil;
        NSStringEncoding encoding;
        NSString         *content  = [NSString stringWithContentsOfFile:fileName usedEncoding:&encoding error:&error];
        
        if ( error ) {
            self->_originalLogFileName = nil;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError:error] runModal];
            });
            
            if ( completion ) {
                completion( error );
            }
            return;
        }
        
        self->_originalLogFileName = fileName;
        
        NSArray        *lines      = [content componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        NSMutableArray *aux        = [NSMutableArray new];
        NSUInteger      rowId      = ( [self->_originalData count] ? ((LogItem*)[self->_originalData lastObject]).originalRowId : 0 );
        LogItem        *logItem    = nil;
        BOOL            foundDate  = NO;
        
        for ( __weak NSString *line in lines ) {
            line = [LogItem trim:line];
            if ( [line length] ) {
                if ( [self startsWithDate:line] ) {
                    foundDate = YES;
                    if ( logItem ) {
                        [aux addObject:logItem];
                    }
                    logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                }
                else {
                    if ( foundDate ) {
                        if ( logItem ) {
                            logItem.text = [NSString stringWithFormat:@"%@\n%@", logItem.text, line];
                        }
                        else {
                            logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                        }
                    }
                    else {
                        [aux addObject:[[LogItem alloc] initWithRowId:rowId++ text:line]];
                    }
                }
            }
        }
        
        if ( logItem && foundDate ) {
            [aux addObject:logItem];
        }
        
        if ( [self->_originalData count] ) {
            [self->_originalData addObjectsFromArray:aux];
        }
        else {
            self->_originalData = [NSMutableArray arrayWithArray:aux];
        }
        
        [self invalidateDataWithCompletion:^{
            if ( completion ) {
                completion( error );
            }
        }];
    });
}

//------------------------------------------------------------------------------
- (void) appendLogFromText:(NSString*)logText completion:(void (^)(NSError*))completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSError          *error    = nil;
        
        if ( error ) {
            self->_originalLogFileName = nil;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError:error] runModal];
            });
            
            if ( completion ) {
                completion( error );
            }
            return;
        }
        
        NSArray        *lines      = [logText componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        NSMutableArray *aux        = [NSMutableArray new];
        NSUInteger      rowId      = ( [self->_originalData count] ? ((LogItem*)[self->_originalData lastObject]).originalRowId : 0 );
        LogItem        *logItem    = nil;
        BOOL            foundDate  = NO;
        
        for ( __weak NSString *line in lines ) {
            if ( [line length] ) {
                if ( [self startsWithDate:line] ) {
                    foundDate = YES;
                    if ( logItem ) {
                        [aux addObject:logItem];
                    }
                    logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                }
                else {
                    if ( foundDate ) {
                        if ( logItem ) {
                            logItem.text = [NSString stringWithFormat:@"%@\n%@", logItem.text, line];
                        }
                        else {
                            logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                        }
                    }
                    else {
                        [aux addObject:[[LogItem alloc] initWithRowId:rowId++ text:line]];
                    }
                }
            }
        }
        
        if ( logItem && foundDate ) {
            [aux addObject:logItem];
        }
        
        if ( [self->_originalData count] ) {
            [self->_originalData addObjectsFromArray:aux];
        }
        else {
            self->_originalData = [NSMutableArray arrayWithArray:aux];
        }
        
        [self invalidateDataWithCompletion:^{
            if ( completion ) {
                completion( error );
            }
        }];
    });
}


//------------------------------------------------------------------------------
- (BOOL) saveOriginalData
{
    BOOL     result = NO;
    NSError *error  = nil;

    if ( [self.originalLogFileName length] ) {
        return result;
    }
    
    @synchronized( self ) {
        NSMutableString *aux = [NSMutableString new];
        for ( __weak LogItem *logItem in self->_originalData ) {
            [aux appendFormat:@"%@\n", logItem.text];
        }
        
        result = [aux writeToFile:self.originalLogFileName atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    return ( result && !error );
}

//------------------------------------------------------------------------------
- (BOOL) saveFilteredDataToURL:(NSURL*)url
{
    BOOL     result = NO;
    NSError *error  = nil;
    
    if ( url ) {
        @synchronized( self ) {
            NSMutableString *aux = [NSMutableString new];
            for ( __weak LogItem *logItem in self->_filteredData ) {
                [aux appendFormat:@"%@\n", logItem.text];
            }
            
            result = [aux writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
    }
    return ( result && !error );
}

//------------------------------------------------------------------------------
- (void) invalidateDataWithCompletion:(void (^)(void))completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        self->_filteredData = nil;
        [self filteredData];
        if ( completion ) {
            completion();
        }
    });
}

//------------------------------------------------------------------------------
- (void) removeAllMatchedItemsWithCompletion:(void (^)(void))completion
{
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        @synchronized( self ) {
            self->_rowFrom                  = NSNotFound;
            self->_rowTo                    = NSNotFound;
            NSMutableArray       *aux       = [NSMutableArray new];
//            dispatch_semaphore_t  semaphore = dispatch_semaphore_create(1);
//            
//            dispatch_apply( [self->_originalData count], dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^(size_t i) {
//                dispatch_semaphore_wait( semaphore, DISPATCH_TIME_FOREVER );
//                __weak LogItem *logItem = [self->_originalData objectAtIndex:i];
//                if ( !logItem.matchFilter ) {
//                    [aux addObject:logItem];
//                }
//                dispatch_semaphore_signal( semaphore );
//            });
            
            for ( __weak LogItem *logItem in self->_originalData ) {
                if ( !logItem.matchFilter ) {
                    [aux addObject:logItem];
                }
            }
            
            self->_originalData = [[NSMutableArray alloc] initWithArray:aux];
            self->_filteredData = nil;
            [self filteredDataWithOriginalData];
        }
        
        if ( completion ) {
            completion();
        }
    });
}


//------------------------------------------------------------------------------
- (void) toggleMatchedWithCompletion:(void (^)(void))completion
{
    if ( self.filterType == FILTER_FILTER ) {
        if ( completion ) {
            completion();
        }
        return;
    }
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        
        @synchronized( self ) {
            [self resetMatchCountersAndIndexes];
            NSUInteger index = 0;
            
            for ( __weak LogItem *logItem in self->_originalData ) {
                logItem.matchFilter = !logItem.matchFilter;
                [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:index++];
            }
            
            self->_filteredData           = nil;
            [self filteredDataWithOriginalData];
        }
        
        if ( completion ) {
            completion();
        }
    });
}

//------------------------------------------------------------------------------
- (void) markRowsFromToWithCompletion:(void (^)(void))completion
{
    if ( ( self.rowFrom == NSNotFound ) || ( self.rowTo == NSNotFound ) ) {
        if ( completion ) {
            completion();
        }
        return;
    }
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        @synchronized( self ) {
            
            [self resetMatchCountersAndIndexes];
            NSUInteger index = 0;
            
            for ( __weak LogItem *logItem in self->_originalData ) {
                logItem.matchFilter = ( ( logItem.originalRowId >= self.rowFrom ) && ( logItem.originalRowId <= self.rowTo ) );
                [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:index++];
            }
            
            self->_filteredData = nil;
            [self filteredDataWithOriginalData];
            
        }
        if ( completion ) {
            completion();
        }
    });
}

//------------------------------------------------------------------------------
- (void) removeFromToMarksWithCompletion:(void (^)(void))completion
{
    dispatch_queue_t queue = dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async( queue, ^{
        
        @synchronized( self ) {
            self.rowFrom = NSNotFound;
            self.rowTo   = NSNotFound;
            
            [self resetMatchCountersAndIndexes];
            
            dispatch_apply( [self->_filteredData count], queue, ^(size_t i) {
                __weak LogItem *logItem = [self->_filteredData objectAtIndex:i];
                logItem.matchFilter = NO;
            });
        }
        if ( completion ) {
            completion();
        }
    });
}

//------------------------------------------------------------------------------
- (NSUInteger) nextMatchedRowIndex
{
    if ( self->_currentMatchedRowIndex >= self->_lastMatchedRowIndex ) {
        self->_currentMatchedRowIndex = self->_firstMatchedRowIndex;
        self->_currentMatchedRow      = 0;
        return self->_currentMatchedRowIndex;
    }
    
    if ( self->_currentMatchedRowIndex == NSNotFound ) {
        return self->_currentMatchedRowIndex;
    }
    
    NSUInteger index = self->_currentMatchedRowIndex + 1;
    LogItem   *logItem;
    
    while ( ( index < [self->_filteredData count] ) && ( index <= self->_lastMatchedRowIndex ) ) {
        logItem = [self->_filteredData objectAtIndex:index];
        if ( logItem.matchFilter ) {
            self->_currentMatchedRowIndex = index;
            self->_currentMatchedRow++;
            return index;
        }
        index++;
    }
    
    self->_currentMatchedRowIndex = self->_lastMatchedRowIndex;
    return self->_currentMatchedRowIndex;
}

//------------------------------------------------------------------------------
- (NSUInteger) previousMatchedRowIndex
{
    if ( self->_currentMatchedRowIndex <= self->_firstMatchedRowIndex ) {
        self->_currentMatchedRowIndex = self->_lastMatchedRowIndex;
        self->_currentMatchedRow      = self.matchedRowsCount - 1;
        return self->_currentMatchedRowIndex;
    }
    else if ( self->_currentMatchedRowIndex == NSNotFound ) {
        return self->_currentMatchedRowIndex;
    }
    
    NSUInteger index = self->_currentMatchedRowIndex - 1;
    LogItem   *logItem;
    
    while ( index >= self->_firstMatchedRowIndex ) {
        logItem = [self->_filteredData objectAtIndex:index];
        if ( logItem.matchFilter ) {
            self->_currentMatchedRowIndex = index;
            self->_currentMatchedRow--;
            return index;
        }
        index--;
    }
    
    self->_currentMatchedRowIndex = self->_firstMatchedRowIndex;
    return self->_currentMatchedRowIndex;
}

//------------------------------------------------------------------------------
- (void) setCurrentMatchedRowIndex:(NSUInteger)newValue
{
    if ( ( self->_firstMatchedRowIndex != NSNotFound )
         &&
         ( self->_lastMatchedRowIndex != NSNotFound )
         &&
         ( newValue >= self->_firstMatchedRowIndex )
         &&
         ( newValue <= self->_lastMatchedRowIndex )
        ) {
        self->_currentMatchedRowIndex = newValue;
    }
}

//------------------------------------------------------------------------------
- (BOOL) startsWithDate:(NSString*)line
{
    static int const        MinDateStrLength = 8; // Such as "08.15.34" "2014-09-25" or "01.06.2015", for example ...
    static NSCharacterSet  *nonDateSet       = nil;
    static dispatch_once_t  onceToken        = 0;
    
    dispatch_once( &onceToken, ^{
        nonDateSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789-.:"] invertedSet];
    });
    
    return ( ( [line length] > MinDateStrLength ) && ( [[line substringToIndex:MinDateStrLength] rangeOfCharacterFromSet:nonDateSet].location == NSNotFound ) );
}

//------------------------------------------------------------------------------
- (void) pasteLogItems:(NSArray*)logItems withCompletion:(void(^)(void))completion
{
    [self pasteLogItems:logItems sorted:YES withCompletion:completion];
}

//------------------------------------------------------------------------------
- (void) pasteLogItems:(NSArray*)logItems sorted:(BOOL)sorted withCompletion:(void(^)(void))completion
{
    if ( ![logItems count] ) {
        if ( completion ) {
            completion();
        }
        return;
    }
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableArray *aux  = [NSMutableArray arrayWithCapacity:[self->_originalData count]];
        NSDictionary   *dict = nil;
        
        @synchronized( self ) {
            
            if ( [self->_originalData count] ) {
                
//                dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
//                dispatch_apply( [self->_originalData count], dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
//                    __weak LogItem *logItem = [self->_originalData objectAtIndex:i];
//                    dispatch_semaphore_wait( semaphore, DISPATCH_TIME_FOREVER );
//                    [aux addObject:[NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId]];
//                    dispatch_semaphore_signal( semaphore );
//                });
                
                for ( __weak LogItem *logItem in self->_originalData ) {
                    [aux addObject:[NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId]];
                }
                
                dict = [NSDictionary dictionaryWithObjects:self->_originalData forKeys:aux];
                [aux removeAllObjects];
                
                for ( __weak LogItem *logItem in logItems ) {
                    if ( ![dict valueForKey:[NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId]] ) {
                        [aux addObject:logItem];
                    }
                }
                
                [self->_originalData addObjectsFromArray:aux];
            }
            else {
                self->_originalData = [[NSMutableArray alloc] initWithArray:logItems copyItems:NO];
            }
            
            if ( sorted ) {
                self->_originalData = [[NSMutableArray alloc] initWithArray:[self->_originalData sortedArrayUsingComparator:^NSComparisonResult( id item1, id item2 ) {
                    return ( ( ((LogItem*)item1).originalRowId == ((LogItem*)item2).originalRowId )
                            ?
                            NSOrderedSame
                            :
                            ( ( ((LogItem*)item1).originalRowId > ((LogItem*)item2).originalRowId )
                             ?
                             NSOrderedDescending
                             :
                             NSOrderedAscending
                             )
                            );
                }]];
            }
            
            self->_filteredData = nil;
            [self filteredDataWithOriginalData];
            
            if ( completion ) {
                completion();
            }
        }
    });
    
}

#pragma mark -
#pragma mark Data Analysis
//------------------------------------------------------------------------------
- (void) analyzeLogItemsWithCompletion:(void(^)(NSArray*))completion
{
    self->_isDataAnalysisRunning = YES;
    void(^analysisCompletion)(NSArray*) = ^(NSArray *logItems) {
        self->_isDataAnalysisRunning = NO;
        if ( completion ) {
            completion( logItems );
        }
    };
    LogItemsAnalyzer *analyzer = [[LogItemsAnalyzer alloc] initWithLogItems:self->_originalData];
    [analyzer analyzeLogItemsWithCompletion:analysisCompletion];
}

#pragma mark -
#pragma mark SessionContainerDelegate Methods
//------------------------------------------------------------------------------
- (void) sessionContainerDidChangeState:(MCSessionState)state
{
    [self.dataProviderDelegate sessionContainerDidChangeState:state];
    if ( state == MCSessionStateNotConnected ) {
        if ( self.isRemoteSessionActive ) {
            // Connection drop out. Re-establish the connection.
            self.isRemoteSessionActive = NO;
            self.isRemoteSessionActive = YES;
        }
    }
}

//------------------------------------------------------------------------------
- (void) sessionContainerDidReceiveData:(NSData*)data fromPeer:(NSString*)peerName
{
    dispatch_async( self->_remote_queue, ^{
        dispatch_sync( dispatch_get_main_queue(), ^{
            if ( [self->_remoteTimer isValid] ) {
                [self->_remoteTimer invalidate];
                self->_remoteTimer = nil;
            }
        });
        
        self->_remotePeerName = peerName;
        [self->_remoteLogItems addObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        
        dispatch_sync( dispatch_get_main_queue(), ^{
            self->_remoteTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(mergeRemoteLogItems) userInfo:nil repeats:NO];
        });
    });
}

//------------------------------------------------------------------------------
- (void) mergeRemoteLogItems
{
    dispatch_async( self->_remote_queue, ^{
        
        dispatch_sync( dispatch_get_main_queue(), ^{
            if ( [self->_remoteTimer isValid] ) {
                [self->_remoteTimer invalidate];
                self->_remoteTimer = nil;
            }
        });
        
        @synchronized( self ) {
            
            if ( !self->_originalData ) {
                self->_originalData = [NSMutableArray new];
                [self resetMatchCountersAndIndexes];
            }
            
            if ( !self->_filteredData ) {
                self->_filteredData = [NSMutableArray new];
                [self resetMatchCountersAndIndexes];
            }
            
            self->_matchedRowsIndexDict = nil;
            
            LogItem        *logItem = ( [self->_originalData count] ? [self->_originalData lastObject] : nil );
            NSUInteger      rowId   = ( logItem ? logItem.originalRowId + 1 : 0 );
            
            for ( __weak NSString *logMessage in self->_remoteLogItems ) {
                logItem             = [[LogItem alloc] initWithRowId:rowId text:logMessage];
                logItem.matchFilter = ( [self.filter.text length] ? ( [logItem.text rangeOfString:self.filter.text].location != NSNotFound ) : NO );
                
                [self->_originalData addObject:logItem];
                [self->_filteredData addObject:logItem];
                
                [self updateMatchCountersAndIndexesWithLogItem:logItem withIndex:rowId++];
            }
        }
        
        [self->_remoteLogItems removeAllObjects];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:ReloadLogNeededNotification object:nil];
        [center postNotificationName:RemoteLogItemsReceivedNotification object:nil];
    });
}

@end
