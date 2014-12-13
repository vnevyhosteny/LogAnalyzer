//
//  DataProvider.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LogItem.h"

typedef enum { FILTER_SEARCH = 0,
               FILTER_FILTER = 1
} FilterType;

//==============================================================================
@interface DataProvider : NSObject

@property (nonatomic, readonly) LogItem       *filter;
@property (nonatomic, readwrite) FilterType    filterType;
@property (nonatomic, readonly) NSArray       *originalData;
@property (nonatomic, readonly) NSArray       *filteredData;

@property (nonatomic, readonly) NSUInteger     matchedRowsCount;
@property (nonatomic, readonly) NSIndexSet    *matchedRowsIndexSet;
@property (nonatomic, readonly) NSIndexSet    *unmatchedRowsIndexSet;
@property (nonatomic, readonly) NSUInteger     firstMatchedRow;

- (void) appendLogFromFile:(NSString*)fileName completion:(void (^)(NSError*))completion;
- (void) invalidateDataWithCompletion:(void (^)(void))completion;
- (void) removeAllMatchedItemsWithCompletion:(void (^)(void))completion;
- (void) removeAllUnmatchedItemsWithCompletion:(void (^)(void))completion;

- (void) writeMatchedLogItems:(BOOL)matched toPasteboard:(NSPasteboard *)pboard;
- (void) pasteLogItems:(NSArray*)logItems;

@end
