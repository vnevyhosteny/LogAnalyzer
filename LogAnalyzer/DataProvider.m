//
//  DataProvider.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DataProvider.h"

@implementation DataProvider

@synthesize originalData = _originalData;
@synthesize filteredData = _filteredData;

//------------------------------------------------------------------------------
- (instancetype) init
{
    if ( ( self = [super init] ) ) {
        self->_filter     = [LogItem new];
        self->_filterType = FILTER_SEARCH;
    }
    return self;
}

#pragma mark -
#pragma mark Getters And Setters
//------------------------------------------------------------------------------
- (NSArray*) filteredDataWithOriginalData
{
    @synchronized( self ) {
        if ( ![self->_filteredData count] ) {
            
            self->_matchedRowsCount       = 0;
            self->_currentMatchedRow      = NSNotFound;
            self->_firstMatchedRowIndex   = NSNotFound;
            self->_currentMatchedRowIndex = NSNotFound;
            self->_lastMatchedRowIndex    = NSNotFound;
            
            self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:YES];
            NSUInteger index    = 0;
            
            for ( __weak LogItem *logItem in self->_filteredData ) {
                if ( logItem.matchFilter ) {
                    
                    self->_matchedRowsCount++;
                    self->_lastMatchedRowIndex = index;
                    
                    if ( self->_firstMatchedRowIndex == NSNotFound ) {
                        self->_firstMatchedRowIndex   = index;
                        self->_currentMatchedRowIndex = index;
                        self->_currentMatchedRow      = 0;
                    }
                }
                
                index++;
            }
        }
        
        return self->_filteredData;
    }
}


//------------------------------------------------------------------------------
- (NSArray*) filteredData
{
    @synchronized( self ) {
        if ( ![self->_filteredData count] ) {
            
            self->_matchedRowsCount       = 0;
            self->_currentMatchedRow      = NSNotFound;
            self->_firstMatchedRowIndex   = NSNotFound;
            self->_currentMatchedRowIndex = NSNotFound;
            self->_lastMatchedRowIndex    = NSNotFound;
            
            if ( [self.filter.text length] ) {
                
                if ( self.filterType == FILTER_SEARCH ) {
                    NSUInteger index    = 0;
                    for ( __weak LogItem *logItem in self->_originalData ) {
                        logItem.matchFilter = ( [logItem.text rangeOfString:self.filter.text options:NSCaseInsensitiveSearch].location != NSNotFound );
                        if ( logItem.matchFilter ) {
                            
                            self->_matchedRowsCount++;
                            self->_lastMatchedRowIndex = index;
                            
                            if ( self->_firstMatchedRowIndex == NSNotFound ) {
                                self->_firstMatchedRowIndex   = index;
                                self->_currentMatchedRowIndex = index;
                                self->_currentMatchedRow      = 0;
                            }
                        }
                        
                        index++;
                    }
                    self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:YES];
                }
                else {
                    NSMutableString *predicateFormat = [[NSMutableString alloc] init];
                    NSMutableArray  *arguments       = [[NSMutableArray alloc] init];
                    
                    [predicateFormat appendString:@"((text LIKE [cd] %@))"];
                    [arguments addObject:[NSString stringWithFormat:@"*%@*", self.filter.text]];
                    
                    NSPredicate *predicate = ( [arguments count] ? [NSPredicate predicateWithFormat:predicateFormat argumentArray:arguments] : nil );
                    self->_filteredData    = ( predicate
                                               ?
                                               [[NSMutableArray alloc] initWithArray:[self->_originalData filteredArrayUsingPredicate:predicate] copyItems:YES]
                                               :
                                               [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:YES]
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
                self->_filteredData = [[NSMutableArray alloc] initWithArray:self->_originalData copyItems:YES];
            }
        }
        
        return self->_filteredData;
    }
}

//------------------------------------------------------------------------------
- (NSIndexSet*) matchedRowsIndexSet
{
    NSMutableIndexSet *aux = [NSMutableIndexSet new];
    
    NSUInteger index = 0;
    for ( __weak LogItem *logItem in self.filteredData ) {
        if ( logItem.matchFilter ) {
            [aux addIndex:index];
        }
        index++;
    }
    
    return [[NSIndexSet alloc] initWithIndexSet:aux];
}

//------------------------------------------------------------------------------
- (NSIndexSet*) unmatchedRowsIndexSet
{
    NSMutableIndexSet *aux = [NSMutableIndexSet new];
    
    NSUInteger index = 0;
    for ( __weak LogItem *logItem in self.filteredData ) {
        if ( !logItem.matchFilter ) {
            [aux addIndex:index];
        }
        index++;
    }
    
    return [[NSIndexSet alloc] initWithIndexSet:aux];
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
            NSLog( @"Error while loading file: %@", [error localizedDescription] );
            if ( completion ) {
                completion( error );
            }
            return;
        }
        
        NSArray        *lines   = [content componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        NSMutableArray *aux     = [NSMutableArray new];
        NSUInteger      rowId   = ( [self->_originalData count] ? ((LogItem*)[self->_originalData lastObject]).originalRowId : 0 );
        LogItem        *logItem = nil;
        
        for ( __weak NSString *line in lines ) {
            if ( [line length] ) {
                if ( [self startsWithDate:line] ) {
                    if ( logItem ) {
                        [aux addObject:logItem];
                    }
                    logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                }
                else {
                    if ( logItem ) {
                        logItem.text = [NSString stringWithFormat:@"%@\n%@", logItem.text, line];
                    }
                    else {
                        logItem = [[LogItem alloc] initWithRowId:rowId++ text:line];
                    }
                }
            }
        }
        if ( logItem ) {
            [aux addObject:logItem];
        }
        
        if ( [self->_originalData count] ) {
            self->_originalData = [[NSArray arrayWithArray:self->_originalData] arrayByAddingObjectsFromArray:aux];
        }
        else {
            self->_originalData = [NSArray arrayWithArray:aux];
        }
        
        [self invalidateDataWithCompletion:^{
            if ( completion ) {
                completion( error );
            }
        }];
    });
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
            NSMutableArray *aux = [NSMutableArray new];
            for ( __weak LogItem *logItem in self->_originalData ) {
                if ( !logItem.matchFilter ) {
                    [aux addObject:logItem];
                }
            }
            self->_originalData = [[NSArray alloc] initWithArray:aux];
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
            for ( __weak LogItem *logItem in self->_originalData ) {
                logItem.matchFilter = !logItem.matchFilter;
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
- (NSUInteger) nextMatchedRowIndex
{
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
    if ( self->_currentMatchedRowIndex == 0 ) {
        self->_currentMatchedRowIndex = NSNotFound;
        return self->_currentMatchedRowIndex;
    }
    else if ( self->_currentMatchedRowIndex == NSNotFound ) {
        return self->_currentMatchedRowIndex;
    }
    
    NSUInteger index = self->_currentMatchedRowIndex - 1;
    LogItem   *logItem;
    
    while ( ( index > 0 ) && ( index >= self->_firstMatchedRowIndex ) ) {
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
- (BOOL) startsWithDate:(NSString*)line
{
    static int const        DateStrLength = 9; // Such as "2014-09-25" or "01.06.2015", for example ...
    static NSCharacterSet  *nonDateSet    = nil;
    static dispatch_once_t  onceToken     = 0;
    
    dispatch_once( &onceToken, ^{
        nonDateSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789-."] invertedSet];
    });
    
    return ( ( [line length] > DateStrLength ) && ( [[line substringToIndex:DateStrLength] rangeOfCharacterFromSet:nonDateSet].location == NSNotFound ) );
}

//------------------------------------------------------------------------------
- (void) pasteLogItems:(NSArray*)logItems
{
    NSMutableArray *aux  = [NSMutableArray new];
    NSDictionary   *dict = nil;
    
    @synchronized( self ) {
        
        if ( [self->_originalData count] ) {
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
            
            self->_originalData = [self->_originalData arrayByAddingObjectsFromArray:aux];
        }
        else {
            self->_originalData = [[NSArray alloc] initWithArray:logItems copyItems:NO];
        }
        
        self->_originalData = [self->_originalData sortedArrayUsingComparator:^NSComparisonResult( id item1, id item2 ) {
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
        }];
        
        self->_filteredData = nil;
    }
}
@end
