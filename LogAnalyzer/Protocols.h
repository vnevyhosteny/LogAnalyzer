//
//  Protocols.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#ifndef LogAnalyzer_Protocols_h
#define LogAnalyzer_Protocols_h

@import MultipeerConnectivity;

#import "LogItem.h"

@class LogItemViewController;
@class LogTablePopup;

//==============================================================================
@protocol MainViewControllerDelegate <NSObject>
- (void) appendLogFromFile:(NSString*)fileName;
- (void) appendLogFromText:(NSString*)logText;
- (void) textDidSelected:(LogItemViewController*)controller;
- (void) reloadLog;
- (void) createNewWindowWithLogItems:(NSArray*)logItems atPoint:(NSPoint)point;
- (BOOL) isDragAndDropEnabled;
- (void) startActivityIndicator;
- (void) startActivityIndicatorWithMessage:(NSString*)message;
- (void) stopActivityIndicator;
- (void) deleteRow:(NSUInteger)row;
- (void) clickedRowAtIndex:(NSInteger)rowIndex atPoint:(NSPoint)point;
- (void) selectAllRows;
- (void) removeMatchedRows;

- (void) popup:(LogTablePopup*)popup didSelectMarkFromWithLogItem:(LogItem*)logItem;
- (void) popup:(LogTablePopup*)popup didSelectMarkToWithItem:(LogItem*)logItem;
- (void) showLogItemPopupAtRow:(NSInteger)row;
- (void) insertItemToHistoryAtRow:(NSInteger)row;
- (void) deleteSelectedHistoryRows;
- (void) selectAllHistoryRows;

@end

//==============================================================================
@protocol DataProviderDelegate
- (void) sessionContainerDidChangeState:(MCSessionState)state;
@end

#endif
