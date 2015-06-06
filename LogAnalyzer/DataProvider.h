//
//  DataProvider.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LogItem.h"
#import "SessionContainer.h"
#import "Protocols.h"

typedef enum { FILTER_SEARCH = 0,
               FILTER_FILTER = 1
} FilterType;

extern NSString *const ReloadLogNeededNotification;
extern NSString *const RemoteLogItemsReceivedNotification ;

//==============================================================================
@interface DataProvider : NSObject <SessionContainerDelegate>

@property (nonatomic, readonly) LogItem                  *filter;
@property (nonatomic, readwrite) FilterType               filterType;
@property (nonatomic, readonly) NSMutableArray           *originalData;
@property (nonatomic, readonly) NSMutableArray           *filteredData;
@property (nonatomic, readonly) NSMutableArray           *historyData;
@property (nonatomic, readonly) NSArray                  *matchedData;

@property (nonatomic, readonly) NSUInteger                matchedRowsCount;
@property (nonatomic, readonly) NSUInteger                currentMatchedRow;
@property (nonatomic, readonly) NSIndexSet               *matchedRowsIndexSet;
@property (nonatomic, readonly) NSDictionary             *matchedRowsIndexDict;
@property (nonatomic, readonly) NSIndexSet               *unmatchedRowsIndexSet;
@property (nonatomic, readonly) NSUInteger                firstMatchedRowIndex;
@property (nonatomic, readwrite) NSUInteger               currentMatchedRowIndex;
@property (nonatomic, readonly) NSUInteger                lastMatchedRowIndex;
@property (nonatomic, readwrite) BOOL                     isSearching;
@property (nonatomic, readwrite) NSUInteger               rowFrom;
@property (nonatomic, readwrite) NSUInteger               rowTo;
@property (nonatomic, readonly) NSString                 *originalLogFileName;
@property (nonatomic, readwrite) BOOL                     isRemoteSessionActive;
@property (nonatomic, readonly) NSString                 *remotePeerName;
@property (nonatomic, readonly) SessionContainer         *sessionContainer;
@property (nonatomic, readwrite) id<DataProviderDelegate> dataProviderDelegate;

- (void) appendLogFromFile:(NSString*)fileName completion:(void (^)(NSError*))completion;
- (void) appendLogFromText:(NSString*)logText completion:(void (^)(NSError*))completion;
- (void) invalidateDataWithCompletion:(void (^)(void))completion;
- (void) removeAllMatchedItemsWithCompletion:(void (^)(void))completion;
- (void) toggleMatchedWithCompletion:(void (^)(void))completion;
- (void) matchFilteredDataWithCompletion:(void(^)( BOOL completed ))completion;

- (void) writeMatchedLogItems:(BOOL)matched toPasteboard:(NSPasteboard *)pboard;
- (void) pasteLogItems:(NSArray*)logItems withCompletion:(void(^)(void))completion;
- (void) pasteLogItems:(NSArray*)logItems sorted:(BOOL)sorted withCompletion:(void(^)(void))completion;
- (void) deleteRow:(NSUInteger)row;

- (NSUInteger) nextMatchedRowIndex;
- (NSUInteger) previousMatchedRowIndex;

- (void) markRowsFromToWithCompletion:(void (^)(void))completion;
- (void) removeFromToMarksWithCompletion:(void (^)(void))completion;
- (BOOL) saveOriginalData;
- (BOOL) saveFilteredDataToURL:(NSURL*)url;
- (void) matchAllRowsWithCompletion:(void (^)())completion;

- (void) addLogItemToHistory:(LogItem*)logItem;
- (void) searchForRowIndexInFilteredDataWithItem:(LogItem*)logItem withCompletion:(void(^)( NSUInteger rowIndex))completion;
- (void) deleteHistoryRowsWithIndexes:(NSIndexSet*)indexSet completion:(void(^)())completion;

- (void) analyzeLogItemsWithCompletion:(void(^)(NSArray*))completion;
@end
