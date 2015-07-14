//
//  MainViewController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 06.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <math.h>


#import "MainViewController.h"
#import "LogTableView.h"
#import "HistoryTableView.h"
#import "LogItem.h"
#import "LogItemViewController.h"
#import "HistoryTableCell.h"
#import "AppDelegate.h"
#import "WindowManager.h"
#import "LogAnalyzerWindowController.h"
#import "LogTableCell.h"
#import "LogTablePopup.h"
#import "NSFont+LogAnalyzer.h"
#import "NSColor+LogAnalyzer.h"
#import "ToggleButton.h"
#import "LogSearchField.h"

@import QuartzCore;

NSString *const kRowId                              = @"RowId";
NSString *const kLogItem                            = @"LogItem";
NSString *const kLogTablePopup                      = @"LogTablePopup";
NSString *const kLogClipView                        = @"LogClipView";
NSString *const kHistoryClipView                    = @"HistoryClipView";

NSString *const kLogItemViewController              = @"LogItemViewController";
NSString *const kMenuItemEdit                       = @"Edit";
NSString *const kMenuItemFile                       = @"File";
NSString *const kMarkFirstRow                       = @"Mark first row";
NSString *const kMarkLastRow                        = @"Mark last row";
NSString *const kNextMatchedRow                     = @"Next matched row";
NSString *const kPreviousMatchedRow                 = @"Previous matched row";
NSString *const kMenuItemSave                       = @"Save";
NSString *const kMenuItemCopy                       = @"Copy";
NSString *const kMenuItemPaste                      = @"Paste";
NSString *const kAnalyze                            = @"Log analysis";

//==============================================================================
@interface MainViewController()
{
    BOOL              _isSearchingInProgress;
    NSString         *_currentFilterText;
    BOOL              _logTableLoading;
    NSTimer          *_delayedSearchTimer;
//    LogTablePopup    *_popup;
//    LogLinePopup     *_linePopup;
    dispatch_queue_t  _serial_queue;
}

@property (weak) IBOutlet LogTableView           *logTableView;
@property (weak) IBOutlet HistoryTableView       *historyTableView;
@property (weak) IBOutlet NSClipView             *logTableClipView;
@property (weak) IBOutlet NSClipView             *historyTableClipView;


@property (weak) IBOutlet NSVisualEffectView     *infoTopView;


@property (weak) IBOutlet NSSearchField          *searchField;
@property (weak) IBOutlet NSProgressIndicator    *activityIndicator;
@property (weak) IBOutlet NSScrollView           *logTableScrollView;
@property (weak) IBOutlet NSTextField            *infoLabel;
@property (weak) IBOutlet NSButton               *toggleFilterModeButton;
@property (weak) IBOutlet NSView                 *topBarBaseView;
@property (weak) IBOutlet NSButton               *toggleMatchedButton;
@property (weak) IBOutlet NSTextField            *matchedCountLabel;
@property (weak) IBOutlet NSButton               *removeMatchedButton;
@property (weak) IBOutlet NSButton               *togglePeerBrowserButton;
@property (weak) IBOutlet NSLayoutConstraint     *inspectorViewWidthLayoutConstraint;
@property (weak) IBOutlet NSView                 *inspectorView;
@property (weak) IBOutlet NSButton               *toggleInfoButton;
@property (weak) IBOutlet NSScrollView           *historyTableScrollView;
@property (weak) IBOutlet NSTextField            *favoritesInfoLabel;

@property (nonatomic, readonly) NSArray          *data;
@property (nonatomic, readwrite) BOOL             isRowHeightUpdatePending;

- (IBAction) toggleFilterMode:(NSButton *)sender;
- (IBAction) removeMatchedAction:(NSButton *)sender;
- (IBAction) toggleMatchedAction:(NSButton *)sender;
- (IBAction)toggleInfoAction:(NSButton *)sender;


@end

@implementation MainViewController

@synthesize dataProvider              = _dataProvider;
@synthesize isRowHeightUpdatePending  = _isRowHeightUpdatePending;

static BOOL isPrimaryController       = YES;

static CGFloat const FullColor        = 255.0f;

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    self->_serial_queue = dispatch_queue_create( "LogAnalyzer.SerialQueue", DISPATCH_QUEUE_SERIAL );
    dispatch_set_target_queue( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), self->_serial_queue );
    
    [self.infoLabel setStringValue:@""];
    if ( [self.searchField acceptsFirstResponder] ) {
        [self.searchField resignFirstResponder];
    }
    
    self.inspectorViewWidthLayoutConstraint.constant = 0.0f;
    [self.view setNeedsUpdateConstraints:YES];
    
    // Set the top bar background color ...
    
    CALayer    *viewLayer = [CALayer layer];
    CGColorRef  color = CGColorCreateGenericRGB( 255.0f/FullColor, 255.0f/FullColor, 255.0f/FullColor, 1.0f );
    [viewLayer setBackgroundColor:color];
    CFRelease( color );
    [self.topBarBaseView setWantsLayer:YES];
    [self.topBarBaseView setLayer:viewLayer];
    
    CALayer *infoLayer = [CALayer layer];
    color = CGColorCreateGenericRGB( 0.0f, 128.0f/FullColor, 255.0f/FullColor, 1.0f );
    [infoLayer setBackgroundColor:color];
    CFRelease( color );
    [self.infoTopView setWantsLayer:YES];
    [self.infoTopView setLayer:infoLayer];

    // Setup the logTableView ...
    
    [self.view.window makeFirstResponder:self.logTableView];
    [self.logTableView setTarget:self];
    [self.logTableView setDoubleAction:@selector(doubleClick:)];
    self.logTableView.mainViewDelegate                                          = self;
    
    self.historyTableView.mainViewDelegate                                      = self;
    
    ((AppDelegate*)[NSApplication sharedApplication].delegate).mainViewDelegate = self;
    self->_isSearchingInProgress                                                = NO;
    self->_currentFilterText                                                    = nil;
    
    self.removeMatchedButton.enabled                                            = NO;
    self->_logTableLoading                                                      = NO;
    
    self.togglePeerBrowserButton.enabled                                        = YES;
    self.togglePeerBrowserButton.state                                          = NSOffState;
    
    [self.removeMatchedButton setToolTip:@"Remove all matched items."];
    [self.toggleMatchedButton setToolTip:@"Toggle matched <-> unmatched items."];
    [self.toggleFilterModeButton setToolTip:@"Toggle view all items <-> matched only."];
    [self.togglePeerBrowserButton setToolTip:@"Toggle browse for clients ON <-> OFF."];
    
    static dispatch_once_t onceToken = 0;
    dispatch_once( &onceToken, ^{
        NSMenu *fileMenu    = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:kMenuItemFile] submenu];
        [fileMenu setAutoenablesItems:NO];
        fileMenu    = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:kMenuItemEdit] submenu];
        [fileMenu setAutoenablesItems:NO];
    });
    
    [self setSaveEnabled:NO];
    [self setMarkFirstAndLastEnabled:NO];
    [self setMoveNextPrevEnabled:NO];
    [self setCopyEnabled:NO];
    [self setPasteEnabled:NO];
    
    self.view.window.delegate                                                   = self;
    
    // Search menu ...
    
    NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    [searchMenu setAutoenablesItems:YES];
    
    NSMenuItem *recentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"Recent Searches" action:nil keyEquivalent:@""];
    [recentsTitleItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu insertItem:recentsTitleItem atIndex:0];
    
    NSMenuItem *norecentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"No recent searches" action:nil keyEquivalent:@""];
    [norecentsTitleItem setTag:NSSearchFieldNoRecentsMenuItemTag];
    [searchMenu insertItem:norecentsTitleItem atIndex:1];
    
    NSMenuItem *recentsItem = [[NSMenuItem alloc] initWithTitle:@"Recents" action:nil keyEquivalent:@""];
    [recentsItem setTag:NSSearchFieldRecentsMenuItemTag];
    [searchMenu insertItem:recentsItem atIndex:2];
    
    NSMenuItem *separatorItem = (NSMenuItem*)[NSMenuItem separatorItem];
    [separatorItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu insertItem:separatorItem atIndex:3];
    
    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"Clear" action:nil keyEquivalent:@""];
    [clearItem setTag:NSSearchFieldClearRecentsMenuItemTag];
    [searchMenu insertItem:clearItem atIndex:4];
    
    id searchCell = [self.searchField cell];
    [searchCell setMaximumRecents:20];
    [searchCell setSearchMenuTemplate:searchMenu];
    
    
    [[searchCell cancelButtonCell] setAction:@selector(searchCellClearedAction:)];
    [[searchCell cancelButtonCell] setTarget:self];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(handleNotifications:) name:ReloadLogNeededNotification object:nil];
    [center addObserver:self selector:@selector(handleNotifications:) name:NSViewBoundsDidChangeNotification object:[self.logTableScrollView contentView]];
    [center addObserver:self selector:@selector(handleNotifications:) name:NSViewBoundsDidChangeNotification object:[self.historyTableScrollView contentView]];
    [center addObserver:self selector:@selector(handleNotifications:) name:SearchFieldBecomeFirstResponderNotification object:nil];
    [center addObserver:self selector:@selector(handleNotifications:) name:RemoteLogItemsReceivedNotification object:nil];
    
}


//------------------------------------------------------------------------------
- (void) dealloc
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:ReloadLogNeededNotification object:nil];
    [center removeObserver:self name:NSViewBoundsDidChangeNotification object:[self.logTableScrollView contentView]];
    [center removeObserver:self name:SearchFieldBecomeFirstResponderNotification object:nil];
    [center removeObserver:self name:RemoteLogItemsReceivedNotification object:nil];
}

//------------------------------------------------------------------------------
- (void) viewDidLoad
{
    [super viewDidLoad];
}

//------------------------------------------------------------------------------
- (void) viewDidAppear
{
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.logTableView];
    [self updateStatus];
}

//------------------------------------------------------------------------------
- (void) setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

//------------------------------------------------------------------------------
- (void) viewDidLayout
{
    [super viewDidLayout];
    [self reloadVisibleRowsOnly];
}

//------------------------------------------------------------------------------
- (void) pasteLogItems:(NSArray*)logItems withCompletion:(void(^)(void))completion
{
    void(^pasteCompletion)() = ^{
        [self stopActivityIndicator];
        if ( completion ) {
            completion();
        }
    };
    [self startActivityIndicatorWithMessage:@"Paste in process ..."];
    [self.dataProvider pasteLogItems:logItems withCompletion:pasteCompletion];
}

#pragma mark -
#pragma mark Notifications
//------------------------------------------------------------------------------
- (void) handleNotifications:(NSNotification*)notification
{
    if ( [notification.name isEqualToString:ReloadLogNeededNotification] ) {
        [self reloadLogAndScrollToTheEnd:YES];
        if ( [self.dataProvider.remotePeerName length] ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                [self.view.window setTitle:self.dataProvider.remotePeerName];
            });
        }
    }
    
    else if ( [notification.name isEqualToString:NSViewBoundsDidChangeNotification] ) {
        [self scrollViewContentBoundsDidChange:notification];
    }
    
    else if ( [notification.name isEqualToString:SearchFieldBecomeFirstResponderNotification] ) {
        dispatch_async( dispatch_get_main_queue(), ^{
            [self setCopyEnabled:YES];
            [self setPasteEnabled:YES];
        });
    }
    
    else if ( [notification.name isEqualToString:RemoteLogItemsReceivedNotification] ) {
        if ( self.dataProvider.filterType != FILTER_SEARCH ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                [self toggleFilterMode:self.toggleFilterModeButton];
            });
        }
    }
}

//------------------------------------------------------------------------------
- (void) windowDidBecomeMain:(NSNotification *)notification
{
    [self setSaveEnabled:( [self.dataProvider.originalLogFileName length] > 0 )];
    
//    LogAnalyzerWindowController *windowController = (LogAnalyzerWindowController*)self.view.window.windowController;
//    [windowController setActive];
    
    [self updateStatus];
    
//    LogAnalyzerWindowController *sourceController = [WindowManager sharedInstance].sourceWindowController;
    if ( [self.view.window.firstResponder isKindOfClass:[NSTextView class]] ) {
        [self setPasteEnabled:YES];
        [self setCopyEnabled:YES];
    }
    else {
//        [self  setPasteEnabled:( sourceController && ( sourceController != windowController ) )];
        [self setPasteEnabled:YES];
    }
}

//------------------------------------------------------------------------------
- (void) windowWillClose:(NSNotification *)notification
{
    [[WindowManager sharedInstance] checkForLastLogWindowOpened];
}

#pragma mark -
#pragma mark Activity Indicator
//------------------------------------------------------------------------------
- (void) startActivityIndicator
{
    [self startActivityIndicatorWithMessage:@"Wait ..."];
}

//------------------------------------------------------------------------------
- (void) startActivityIndicatorWithMessage:(NSString*)message
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.activityIndicator startAnimation:nil];
        [self.infoLabel setStringValue:message];
        [self.activityIndicator setNeedsDisplay:YES];
        [self.infoLabel setNeedsDisplay:YES];
    });
}

//------------------------------------------------------------------------------
- (void) stopActivityIndicator
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimation:nil];
        [self.infoLabel setStringValue:@""];
        [self.activityIndicator setNeedsDisplay:YES];
        [self.infoLabel setNeedsDisplay:YES];
    });
}


#pragma mark -
#pragma mark Getters And Setters
//------------------------------------------------------------------------------
- (NSArray*) data
{
    return self.dataProvider.filteredData;
}

//------------------------------------------------------------------------------
- (DataProvider*) dataProvider
{
    if ( !self->_dataProvider ) {
        
        self->_dataProvider                      = [DataProvider new];
        self->_dataProvider.dataProviderDelegate = self;
        
        if ( isPrimaryController ) {
            isPrimaryController = NO;
        }
    }
    return self->_dataProvider;
}

//------------------------------------------------------------------------------
- (BOOL) isIsRowHeightUpdatePending
{
    __block BOOL result;
    dispatch_sync( self->_serial_queue, ^{
        result = self->_isRowHeightUpdatePending;
    });
    return result;
}

//------------------------------------------------------------------------------
- (void) setIsRowHeightUpdatePending:(BOOL)newValue
{
    dispatch_sync( self->_serial_queue, ^{
        self->_isRowHeightUpdatePending = newValue;
    });
}

#pragma mark -
#pragma mark Enable/Disable Menu Items
//------------------------------------------------------------------------------
- (void) setMenuItemByTitle:(NSString*)menuTitle inSubmenuByTitle:(NSString*)submenuTitle enabled:(BOOL)enabled
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSMenu     *subMenu   = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:submenuTitle] submenu];
        NSMenuItem *menuItem  = [subMenu itemWithTitle:menuTitle];
        [menuItem setEnabled:enabled];
    });
}

//------------------------------------------------------------------------------
- (void) setMarkFirstAndLastEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kMarkFirstRow inSubmenuByTitle:kMenuItemEdit enabled:enabled];
    [self setMenuItemByTitle:kMarkLastRow inSubmenuByTitle:kMenuItemEdit enabled:enabled];
}

//------------------------------------------------------------------------------
- (void) setMoveNextPrevEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kNextMatchedRow inSubmenuByTitle:kMenuItemEdit enabled:enabled];
    [self setMenuItemByTitle:kPreviousMatchedRow inSubmenuByTitle:kMenuItemEdit enabled:enabled];
}

//------------------------------------------------------------------------------
- (void) setSaveEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kMenuItemSave inSubmenuByTitle:kMenuItemFile enabled:enabled];
}

//------------------------------------------------------------------------------
- (void) setCopyEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kMenuItemCopy inSubmenuByTitle:kMenuItemEdit enabled:enabled];
}

//------------------------------------------------------------------------------
- (void) setPasteEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kMenuItemPaste inSubmenuByTitle:kMenuItemEdit enabled:enabled];
}

//------------------------------------------------------------------------------
- (void) setAnalyzeEnabled:(BOOL)enabled
{
    [self setMenuItemByTitle:kAnalyze inSubmenuByTitle:kMenuItemEdit enabled:enabled];
}


//------------------------------------------------------------------------------
- (BOOL) isDragAndDropEnabled
{
    return YES;//( self.dataProvider.filterType == FILTER_SEARCH );
}

//------------------------------------------------------------------------------
- (void) find
{
    [self.view.window makeFirstResponder:self.searchField];
}

//------------------------------------------------------------------------------
- (void) analyze
{
    if ( self.dataProvider.isDataAnalysisRunning ) {
        return;
    }
    
    [self startActivityIndicatorWithMessage:@"Analyzing data ..."];
    [self setAnalyzeEnabled:NO];
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.dataProvider analyzeLogItemsWithCompletion:^(NSArray *sortedLogItems) {
            dispatch_async( dispatch_get_main_queue(), ^{
                LogAnalyzerWindowController *windowController = [[WindowManager sharedInstance] createNewWindowWithLogItems:nil title:@"Sorted Log"];
                [windowController.window makeKeyAndOrderFront:self];
                dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [windowController.mainViewController.dataProvider pasteLogItems:sortedLogItems sorted:NO withCompletion:^{
                        dispatch_async( dispatch_get_main_queue(), ^{
                            [windowController.mainViewController reloadLog];
                            [self stopActivityIndicator];
                            [self setAnalyzeEnabled:YES];
                        });
                    }];
                });
            });
        }];
    });
}

#pragma mark -
#pragma mark Actions
//------------------------------------------------------------------------------
- (IBAction) toggleFilterMode:(NSButton *)sender
{
    if ( self.dataProvider.isFilteringData ) {
        return;
    }
    
    switch ( sender.state ) {
        case NSOnState:
            self.dataProvider.filterType = FILTER_SEARCH;
            [sender setImage:[NSImage imageNamed:@"ButtonFilterOn"]];
            break;
            
        case NSOffState:
            self.dataProvider.filterType = FILTER_FILTER;
            [sender setImage:[NSImage imageNamed:@"ButtonFilterOff"]];
            break;
            
        default:;
    }
    
    // Preserve selected row ...
    NSInteger  index         = self.logTableView.selectedRow;
    NSUInteger selectedRowId = ( ( index >= 0 ) ? ((LogItem*)[self.data objectAtIndex:index]).originalRowId : NSNotFound );
    
    [self startActivityIndicatorWithMessage:@"Switching mode ..."];
    [self.dataProvider invalidateDataWithCompletion:^{
        [self reloadLog];
        
        if ( selectedRowId != NSNotFound ) {
            NSUInteger rowIndex = 0;
            for ( __weak LogItem *logItem in self.data ) {
                if ( logItem.originalRowId == selectedRowId ) {
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [self.logTableView scrollRowToVisible:rowIndex];
                        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
                    });
                    break;
                }
                rowIndex++;
            }
        }
        [self stopActivityIndicator];
    }];
}

//------------------------------------------------------------------------------
- (IBAction) removeMatchedAction:(NSButton *)sender
{
    [self removeMatchedRows];
}

//------------------------------------------------------------------------------
- (IBAction) toggleMatchedAction:(ToggleButton *)sender
{
    [self startActivityIndicatorWithMessage:@"Toggle matched ..."];
    [sender toggleImage];
    [self.dataProvider toggleMatchedWithCompletion:^{
        [self reloadLog];
        [self stopActivityIndicator];
    }];
}

//------------------------------------------------------------------------------
- (IBAction) toggleInfoAction:(NSButton *)sender
{
    static CGFloat const InfoWidth = 250.0f;
    
    CGFloat newValue;
    switch ( sender.state ) {
        case NSOnState:
            newValue = 0.0f;
            [self.historyTableView.enclosingScrollView setBorderType:NSNoBorder];
            [sender setImage:[NSImage imageNamed:@"ButtonInfoOff"]];
            break;
            
        case NSOffState:
            newValue = InfoWidth;
            [sender setImage:[NSImage imageNamed:@"ButtonInfoOn"]];
            break;
            
        default:
            newValue = 0.0f;
    }
    
    if ( newValue > 0.0f ) {
        CGFloat width = self.logTableView.bounds.size.width / 4.0f;
        if ( newValue < width ) {
            newValue = width;
        }
    }
    
    [self.view setNeedsUpdateConstraints:YES];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2f;
        [self.inspectorViewWidthLayoutConstraint.animator setConstant:newValue];
    }
                        completionHandler:^{
                            if ( sender.state == NSOnState ) {
                                [self.view.window makeFirstResponder:self.logTableView];
                            }
                            else {
                                [self.historyTableView.enclosingScrollView setBorderType:NSLineBorder];
                                [self scrollViewContentBoundsDidChange:nil];
                                [self tableViewSelectionDidChange:nil];
                                [self.view.window makeFirstResponder:self.historyTableView];
                            }
                        }];
}

//------------------------------------------------------------------------------
- (IBAction) toggleBrowseOnOffAction:(NSButton *)sender
{
    BOOL newValue                           = !self.dataProvider.isRemoteSessionActive;
    self.dataProvider.isRemoteSessionActive = newValue;
    if ( newValue ) {
        [self startActivityIndicatorWithMessage:@"Searching for clients ..."];
        [self.togglePeerBrowserButton setImage:[NSImage imageNamed:@"ButtonRadioSearching"]];
    }
    //[self.togglePeerBrowserButton setEnabled:NO];
}

#pragma mark -
#pragma mark NSTableViewDataSource Methods
//------------------------------------------------------------------------------
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    if ( tableView == self.logTableView ) {
        return [self.data count];
    }
    else {
        return [self.dataProvider.historyData count];
    }
}


//------------------------------------------------------------------------------
- (id)          tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
                      row:(NSInteger)rowIndex
{
    if ( [[tableColumn.headerCell stringValue] isEqualToString:kRowId] ) {
        if ( tableView == self.logTableView ) {
            return [NSString stringWithFormat:@"%lu", (unsigned long)((LogItem*)[self.data objectAtIndex:rowIndex]).originalRowId + 1];
        }
        else {
            return [NSString stringWithFormat:@"%lu", (unsigned long)((LogItem*)[self.dataProvider.historyData objectAtIndex:rowIndex]).originalRowId + 1];
        }
    }
    if ( [[tableColumn.headerCell stringValue] isEqualToString:kLogItem] ) {
        if ( tableView == self.logTableView ) {
            return ((LogItem*)[self.data objectAtIndex:rowIndex]).text;
        }
        else {
            return ((LogItem*)[self.dataProvider.historyData objectAtIndex:rowIndex]).text;
        }
    }
    else {
        return nil;
    }
}

//------------------------------------------------------------------------------
- (NSCell *) tableView:(NSTableView *)tableView
dataCellForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row
{
    
    if ( tableView == self.logTableView ) {
    
        LogTableCell     *cell           = nil;
        LogItem          *logItem        = (LogItem*)[self.data objectAtIndex:row];
        BOOL              isMarked       = ( ( self.dataProvider.rowFrom == logItem.originalRowId ) && ( self.dataProvider.rowTo == NSNotFound ) );
        BOOL              isTableFocused = ( self.view.window.firstResponder == self.logTableView );
        
        if ( [tableColumn.identifier isEqualToString:kRowId] ) {
            NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId + 1];
            cell           = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];
            if ( cell ) {
                [cell setStringValue:text];
            }
            else {
                cell = [[LogTableCell alloc] initTextCell:text];
            }
            [cell setSelectable:NO];
            [cell setCellAttribute:NSCellDisabled to:1];
            [cell setTextColor:( isMarked ? [NSColor logTableMarkedColor] : [NSColor logTableLineNumberColor])];
            
            [cell setAlignment:NSRightTextAlignment];
            
            if ( isMarked ) {
                [cell setImage:[NSImage imageNamed:@"ButtonMarkFrom"]];
            }
        }
        
        else if ( [tableColumn.identifier isEqualToString:kLogItem] ) {
            cell           = [tableView viewAtColumn:1 row:row makeIfNecessary:NO];
            if ( cell ) {
                [cell setStringValue:logItem.text];
            }
            else {
                cell = [[LogTableCell alloc] initTextCell:logItem.text];
            }
            [cell setSelectable:YES];
            [cell setCellAttribute:NSCellEditable to:0];
            if ( isMarked ) {
                [cell setTextColor:[NSColor logTableMarkedColor]];
            }
            else {
                if ( [tableView selectedRow] == row ) {
                    //[cell setTextColor:( logItem.matchFilter ? ( ( row == self.dataProvider.currentMatchedRowIndex ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : [NSColor whiteColor])];
                    [cell setTextColor:( logItem.matchFilter ? ( ( ( row == self.dataProvider.currentMatchedRowIndex ) && isTableFocused ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : ( isTableFocused ? [NSColor whiteColor] : [NSColor logTablePlainTextColor]))];
                }
                else {
                    //[cell setTextColor:( logItem.matchFilter ? ( ( row == self.dataProvider.currentMatchedRowIndex ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : [NSColor logTablePlainTextColor])];
                    [cell setTextColor:( logItem.matchFilter ? [NSColor logTableMatchedColor] : [NSColor logTablePlainTextColor])];
                }
            }
        }
        
        [cell setFont:[NSFont logTableRegularFont]];
        
        [cell setEditable:NO];
        [cell setEnabled:NO];
        [cell setLineBreakMode:NSLineBreakByWordWrapping];
        
        return cell;
    }
    else {
        HistoryTableCell *cell           = nil;
        LogItem          *logItem        = (LogItem*)[self.dataProvider.historyData objectAtIndex:row];
        BOOL              isTableFocused = ( self.view.window.firstResponder == self.historyTableView );
        
        if ( [tableColumn.identifier isEqualToString:kRowId] ) {
            NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId + 1];
            cell           = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];
            if ( cell ) {
                [cell setStringValue:text];
            }
            else {
                cell = [[HistoryTableCell alloc] initTextCell:text];
            }
            [cell setSelectable:NO];
            [cell setCellAttribute:NSCellDisabled to:1];
            [cell setTextColor:[NSColor logTableLineNumberColor]];
            
            [cell setAlignment:NSRightTextAlignment];
        }
        
        else if ( [tableColumn.identifier isEqualToString:kLogItem] ) {
            cell           = [tableView viewAtColumn:1 row:row makeIfNecessary:NO];
            if ( cell ) {
                [cell setStringValue:logItem.text];
            }
            else {
                cell = [[HistoryTableCell alloc] initTextCell:logItem.text];
            }
            [cell setSelectable:YES];
            [cell setCellAttribute:NSCellEditable to:0];
            
            if ( [tableView selectedRow] == row ) {
                //[cell setTextColor:( logItem.matchFilter ? ( ( ( row == self.dataProvider.currentMatchedRowIndex ) && isTableFocused ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : ( isTableFocused ? [NSColor whiteColor] : [NSColor logTablePlainTextColor]))];
                [cell setTextColor:( isTableFocused ? [NSColor whiteColor] : [NSColor historyTablePlainTextColor])];
            }
            else {
                [cell setTextColor:[NSColor historyTablePlainTextColor]];
            }
        }
        
        [cell setFont:[NSFont historyTableRegularFont]];
        
        return cell;
    }
}

//------------------------------------------------------------------------------
- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
    NSTableColumn   *column        = [tableView tableColumnWithIdentifier:kLogItem];
    CGFloat          defaultHeight = [tableView rowHeight];
    
    NSTextFieldCell *cell          = [column dataCellForRow:row];
    if ( !cell ) {
        return defaultHeight;
    }
    
    LogItem         *logItem = ( ( tableView == self.logTableView ) ? [self.data objectAtIndex:row] : [self.dataProvider.historyData objectAtIndex:row] );
    [cell setStringValue:logItem.text];
    
    // See how tall it naturally would want to be if given a restricted with, but unbound height
    NSRect  constrainedBounds = NSMakeRect( 0.f, 0.0f, [column width], CGFLOAT_MAX );
    NSSize  naturalSize       = [cell cellSizeForBounds:constrainedBounds];

    return ( ( naturalSize.height > defaultHeight ) ? naturalSize.height : defaultHeight );

}

//------------------------------------------------------------------------------
- (void) tableView:(NSTableView *)tableView
   willDisplayCell:(id)cell
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)rowIndex
{
    if ( tableView == self.logTableView ) {
        if ( self->_logTableLoading ) {
            [self stopActivityIndicator];
            self->_logTableLoading = NO;
        }
    }
}


//------------------------------------------------------------------------------
- (BOOL)    tableView:(NSTableView *)tableView
 writeRowsWithIndexes:(NSIndexSet *)rowIndexes
         toPasteboard:(NSPasteboard *)pboard
{
    if ( tableView == self.logTableView ) {
        if ( [rowIndexes count] ) {
            LogItem    *draggedLogItem = [self.data objectAtIndex:rowIndexes.firstIndex];
            [self.dataProvider writeMatchedLogItems:draggedLogItem.matchFilter toPasteboard:pboard];
            return YES;
        }
        else {
            return NO;
        }
    }
    else if ( ( tableView == self.historyTableView ) && [rowIndexes count] ) {
        NSMutableArray *aux          = [NSMutableArray new];
        NSUInteger      currentIndex = [rowIndexes firstIndex];
        
        while ( currentIndex != NSNotFound) {
            [aux addObject:[self.dataProvider.historyData objectAtIndex:currentIndex]];
            currentIndex = [rowIndexes indexGreaterThanIndex:currentIndex];
        }
        
        [pboard writeObjects:aux];
        
        return YES;
    }
    else {
        return NO;
    }
}

//------------------------------------------------------------------------------
- (void) showLogItemPopupAtRow:(NSInteger)row
{
    LogItem *logItem                  = (LogItem*)[self.dataProvider.filteredData objectAtIndex:row];
    if ( !logItem ) {
        return;
    }
    
    [self startActivityIndicator];
    [self setCopyEnabled:NO];
    
    LogItemViewController *controller = (LogItemViewController*)[[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateControllerWithIdentifier:kLogItemViewController];
    controller.logItem                = logItem;
    controller.mainViewDelegate       = self;
    [self presentViewControllerAsModalWindow:controller];
    
    [self stopActivityIndicator];
}

//------------------------------------------------------------------------------
- (void) insertItemToHistoryAtRow:(NSInteger)row
{
    LogItem *logItem = (LogItem*)[self.data objectAtIndex:row];
    if ( !logItem ) {
        return;
    }
    [self.dataProvider addLogItemToHistory:logItem];
    
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.historyTableView reloadData];
    });
}

//------------------------------------------------------------------------------
- (void) deleteRow:(NSUInteger)row
{
    [self startActivityIndicatorWithMessage:@"Deleting row ..."];
    [self.dataProvider deleteRow:row];
    
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.historyTableView reloadData];
    });
    
    [self reloadLog];
    [self stopActivityIndicator];
}


#pragma mark -
#pragma mark NSTableViewDelegate Methods
//------------------------------------------------------------------------------
- (void) doubleClick:(id)object
{
    if ( object == self.logTableView ) {
        NSInteger row = [self.logTableView clickedRow];
        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [self showLogItemPopupAtRow:row];
    }
}

//------------------------------------------------------------------------------
- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    if ( notification.object == self.logTableView ) {
        NSInteger row = self.logTableView.selectedRow;
        [self setMarkFirstAndLastEnabled:( ( row >= 0 ) && [self.data count] )];
        if ( row >= 0 ) {
            [self.dataProvider setCurrentMatchedRowIndex:row];
        }
        
    }
    else {
        NSIndexSet *indexSet = self.historyTableView.selectedRowIndexes;
        if ( [indexSet count] == 1 ) {
            LogItem    *historyItem = [self.dataProvider.historyData objectAtIndex:[indexSet firstIndex]];
            [self.dataProvider searchForRowIndexInFilteredDataWithItem:historyItem withCompletion:^( NSUInteger rowIndex ){
                if ( rowIndex != NSNotFound ) {
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [self.logTableView scrollRowToVisible:rowIndex];
                        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
                    });
                }
            }];
        }
    }
    
    [self setCopyEnabled:YES];
    [self updateStatus];
}

//------------------------------------------------------------------------------
- (void) adjustRowHeightForVisibleRowsForTable:(NSObject*)object
{
    static CGFloat const DeltaY = 100.0f;
    
    NSClipView   *clipView   = (NSClipView*)object;
    NSScrollView *scrollView = ( ( clipView == self.logTableClipView ) ? self.logTableScrollView : self.historyTableScrollView );
    
    if ( scrollView ) {
        dispatch_async( dispatch_get_main_queue(), ^{
            
            NSTableView *tableView       = ( ( scrollView == self.logTableScrollView ) ? self.logTableView : self.historyTableView );
            CGRect       visibleRect     = scrollView.contentView.bounds;
            visibleRect.origin.y        -= DeltaY;
            visibleRect.size.height     += DeltaY;
            NSRange      visibleRows     = [tableView rowsInRect:visibleRect];
            
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:0.0f];
            [tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:visibleRows]];
            [NSAnimationContext endGrouping];
            
            self.isRowHeightUpdatePending = NO;
        });
    }
}

//------------------------------------------------------------------------------
- (void) scrollViewContentBoundsDidChange:(NSNotification*)notification
{
    if ( self.isRowHeightUpdatePending ) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(adjustRowHeightForVisibleRowsForTable:) object:notification.object];
    }
    [self performSelector:@selector(adjustRowHeightForVisibleRowsForTable:) withObject:notification.object afterDelay:0.01f];
    self.isRowHeightUpdatePending = YES;
}

//------------------------------------------------------------------------------
- (void) prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
}

#pragma mark -
#pragma mark MainViewControllerDelegate Methods
//------------------------------------------------------------------------------
- (void) openLogFile
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSOpenPanel *panel            = [NSOpenPanel openPanel];
        
        panel.canChooseFiles          = YES;
        panel.canChooseDirectories    = NO;
        panel.allowsMultipleSelection = NO;
        
        [panel beginWithCompletionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                [self appendLogFromFile:[[[panel URLs] objectAtIndex:0] path]];
            }
        }];
    });
}

//------------------------------------------------------------------------------
- (void) deleteSelectedHistoryRows
{
    [self.dataProvider deleteHistoryRowsWithIndexes:[self.historyTableView selectedRowIndexes] completion:^{
        dispatch_async( dispatch_get_main_queue(), ^{
            [self.historyTableView deselectAll:nil];
            [self.historyTableView reloadData];
        });
    }];
}

//------------------------------------------------------------------------------
- (void) selectAllHistoryRows
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.historyTableView selectAll:nil];
    });
}


//------------------------------------------------------------------------------
- (void) saveLogFile
{
    [self.dataProvider saveOriginalData];
}

//------------------------------------------------------------------------------
- (void) selectAllRows
{
    [self.dataProvider matchAllRowsWithCompletion:^{
        [self reloadLog];
    }];
}

//------------------------------------------------------------------------------
- (void) saveLogFileAs
{
    NSSavePanel *panel            = [NSSavePanel savePanel];
    
    panel.canCreateDirectories    = YES;
    [panel setExtensionHidden:NO];
    [panel setAllowedFileTypes:@[@"log", @"txt"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self.dataProvider saveFilteredDataToURL:[panel URL]];
        }
    }];
}


//------------------------------------------------------------------------------
- (void) appendLogFromFile:(NSString*)fileName
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.view.window setTitle:[fileName lastPathComponent]];
    });
    
    [self startActivityIndicatorWithMessage:@"Reading file ..."];
    [self.dataProvider appendLogFromFile:fileName completion:^(NSError *error) {
        if ( !error ) {
            [self reloadLog];
            [self setSaveEnabled:YES];
            if ( [[self.searchField stringValue] length] ) {
                [self fireSearchProcess];
            }
        }
    }];
}

//------------------------------------------------------------------------------
- (void) appendLogFromText:(NSString*)logText
{
    [self startActivityIndicatorWithMessage:@"Pasting text ..."];
    [self.dataProvider appendLogFromText:logText completion:^(NSError *error) {
        if ( !error ) {
            [self reloadLog];
            [self setSaveEnabled:YES];
            if ( [[self.searchField stringValue] length] ) {
                [self fireSearchProcess];
            }
        }
    }];
}



//------------------------------------------------------------------------------
- (void) textDidSelected:(LogItemViewController*)controller
{
    [self setCopyEnabled:YES];
    if ( controller ) {
        NSRange range = controller.textView.selectedRange;
        if ( ( range.location != NSNotFound ) && ( range.length > 0 ) ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                [self.searchField setStringValue:[controller.textView.string substringWithRange:range]];
                [self.searchField becomeFirstResponder];
                [self fireSearchProcess];
            });
        }
        [self dismissViewController:controller];
    }
}

//------------------------------------------------------------------------------
- (void) reloadLogAndScrollToTheEnd:(BOOL)scrollToTheEnd
{
    dispatch_async( dispatch_get_main_queue(), ^{
        self->_logTableLoading = YES;
        
        NSUInteger count = [self.data count];
        if ( count ) {
            [self startActivityIndicatorWithMessage:@"Reloading ..."];
        }
        
        [self.logTableView reloadData];
        [self updateStatus];
        
        if ( ( scrollToTheEnd ) && count ) {
            [self.logTableView scrollToRowIndex:count - 1 ];
        }
    });
}


//------------------------------------------------------------------------------
- (void) reloadLog
{
    [self reloadLogAndScrollToTheEnd:NO];
}

//------------------------------------------------------------------------------
- (void) reloadVisibleRowsOnly
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSRange visibleRows = [self.logTableView rowsInRect:self.logTableScrollView.contentView.bounds];
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0];
        [self.logTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:visibleRows]];
        [NSAnimationContext endGrouping];
    });
}

//------------------------------------------------------------------------------
- (void) createNewWindowWithLogItems:(NSArray*)logItems atPoint:(NSPoint)point
{
    LogAnalyzerWindowController *windowController = [[WindowManager sharedInstance] createNewWindowWithLogItems:logItems title:[self.searchField stringValue]];
    
    NSRect frame = windowController.window.frame;
    point.y     -= frame.size.height;
    [windowController.window setFrameOrigin:point];
    
    [windowController.window makeKeyAndOrderFront:self];
    [windowController.mainViewController reloadLog];
}


//------------------------------------------------------------------------------
- (void) clickedRowAtIndex:(NSInteger)rowIndex atPoint:(NSPoint)point
{
    if ( ( point.x < 50.0f ) && ( rowIndex >= 0 ) ) {
        LogTablePopup *popup          = (LogTablePopup*)[[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateControllerWithIdentifier:kLogTablePopup];
        popup.logItem                 = [self.data objectAtIndex:rowIndex];
        popup.mainViewDelegate        = self;
        NSRect         anchorFrame    = [self.logTableView frameOfCellAtColumn:0 row:rowIndex];
        [self presentViewController:popup asPopoverRelativeToRect:anchorFrame ofView:self.logTableView preferredEdge:NSMaxXEdge behavior:NSPopoverBehaviorSemitransient];
    }
}

//------------------------------------------------------------------------------
- (void) popup:(LogTablePopup*)popup didSelectMarkFromWithLogItem:(LogItem*)logItem
{
    self.dataProvider.rowFrom = logItem.originalRowId;
    if ( popup ) {
        [self dismissViewController:popup];
    }
    
    if ( self.dataProvider.rowTo != NSNotFound ) {
        if ( self.dataProvider.rowTo >= self.dataProvider.rowFrom ) {
            [self startActivityIndicatorWithMessage:@"Setting marks ..."];
            [self.dataProvider markRowsFromToWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:YES];
                [self setMoveNextPrevEnabled:YES];
            }];
        }
        else {
            [self startActivityIndicatorWithMessage:@"Resetting marks ..."];
            [self.dataProvider removeFromToMarksWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:NO];
                [self setMoveNextPrevEnabled:NO];
            }];
        }
    }
    else {
        [self reloadVisibleRowsOnly];
        [self updateStatus];
    }
    
    NSUInteger row = [self.data indexOfObject:logItem];
    if ( row != NSNotFound ) {
        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

//------------------------------------------------------------------------------
- (void) popup:(LogTablePopup*)popup didSelectMarkToWithItem:(LogItem*)logItem
{
    self.dataProvider.rowTo = logItem.originalRowId;
    if ( popup ) {
        [self dismissViewController:popup];
    }
    
    if ( self.dataProvider.filterType == FILTER_FILTER ) {
        self.toggleFilterModeButton.state = NSOnState;
        [self toggleFilterMode:self.toggleFilterModeButton];
    }
    
    if ( self.dataProvider.rowFrom != NSNotFound ) {
        if ( self.dataProvider.rowTo >= self.dataProvider.rowFrom ) {
            [self startActivityIndicatorWithMessage:@"Setting marks ..."];
            [self.dataProvider markRowsFromToWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:YES];
                [self setMoveNextPrevEnabled:YES];
            }];
        }
        else {
            [self startActivityIndicatorWithMessage:@"Resetting marks ..."];
            [self.dataProvider removeFromToMarksWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:NO];
                [self setMoveNextPrevEnabled:NO];
            }];
        }
    }
    else {
        [self startActivityIndicatorWithMessage:@"Resetting marks ..."];
        [self.dataProvider removeFromToMarksWithCompletion:^{
            [self reloadVisibleRowsOnly];
            [self updateStatus];
            [self stopActivityIndicator];
            [self setMarkFirstAndLastEnabled:NO];
            [self setMoveNextPrevEnabled:NO];
        }];
    }
    
    NSUInteger row = [self.data indexOfObject:logItem];
    if ( row != NSNotFound ) {
        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        self.dataProvider.currentMatchedRowIndex = row;
    }
}

//------------------------------------------------------------------------------
- (void) markFirstRow
{
    [self.view.window makeFirstResponder:self.logTableView];
    
    if ( ( self.logTableView.selectedRow >= 0 ) && [self.data count] ) {
        [self popup:nil didSelectMarkFromWithLogItem:(LogItem*)[self.data objectAtIndex:self.logTableView.selectedRow]];
    }
    else if ( self.dataProvider.currentMatchedRowIndex != NSNotFound ) {
        [self popup:nil didSelectMarkFromWithLogItem:(LogItem*)[self.dataProvider.filteredData objectAtIndex:self.dataProvider.currentMatchedRowIndex]];
    }
    
    [self.searchField setStringValue:@""];
    self.dataProvider.filter.text = nil;
}

//------------------------------------------------------------------------------
- (void) markLastRow
{
    [self.view.window makeFirstResponder:self.logTableView];
    
    if ( ( self.logTableView.selectedRow >= 0 ) && [self.data count] ) {
        [self popup:nil didSelectMarkToWithItem:(LogItem*)[self.data objectAtIndex:self.logTableView.selectedRow]];
    }
    else if ( self.dataProvider.currentMatchedRowIndex != NSNotFound ) {
        [self popup:nil didSelectMarkToWithItem:(LogItem*)[self.dataProvider.filteredData objectAtIndex:self.dataProvider.currentMatchedRowIndex]];
    }
    
    [self.searchField setStringValue:@""];
    self.dataProvider.filter.text = nil;
}

//------------------------------------------------------------------------------
- (void) moveToPreviousMatchedRow
{
    NSUInteger index = [self.dataProvider previousMatchedRowIndex];
    if ( index != NSNotFound ) {
        [self.view.window makeFirstResponder:self.logTableView];
        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        [self.logTableView scrollRowToVisible:index];
        [self reloadVisibleRowsOnly];
        [self updateStatus];
    }
}

//------------------------------------------------------------------------------
- (void) moveToNextMatchedRow
{
    NSUInteger index = [self.dataProvider nextMatchedRowIndex];
    if ( index != NSNotFound ) {
        [self.view.window makeFirstResponder:self.logTableView];
        [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        [self.logTableView scrollRowToVisible:index];
        [self reloadVisibleRowsOnly];
        [self updateStatus];
    }
}

//------------------------------------------------------------------------------
- (void) removeMatchedRows
{
    [self startActivityIndicatorWithMessage:@"Reloading ..."];
    [self.dataProvider removeAllMatchedItemsWithCompletion:^{
        [self reloadLog];
        [self stopActivityIndicator];
        if ( self.dataProvider.filterType == FILTER_FILTER ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                self.toggleFilterModeButton.state = NSOnState;
                [self toggleFilterMode:self.toggleFilterModeButton];
            });
        }
    }];
}

//------------------------------------------------------------------------------
- (void) toggleShowInfoOnOff
{
    self.toggleInfoButton.state = ( ( self.toggleInfoButton.state == NSOnState ) ? NSOffState : NSOnState );
    [self toggleInfoAction:self.toggleInfoButton];
}

#pragma mark -
#pragma mark DataProviderDelegate Methods
//------------------------------------------------------------------------------
- (void) sessionContainerDidChangeState:(MCSessionState)state
{
    [self stopActivityIndicator];
    
    dispatch_async( dispatch_get_main_queue(), ^{
        switch ( state ) {
            case MCSessionStateConnected:
                [self.togglePeerBrowserButton setImage:[NSImage imageNamed:@"ButtonRadioOn"]];
                break;
                
            case MCSessionStateNotConnected:
                [self.togglePeerBrowserButton setImage:[NSImage imageNamed:@"ButtonRadioOff"]];
                break;
                
            default:;
        }
        [self.togglePeerBrowserButton setEnabled:YES];
    });
}

//------------------------------------------------------------------------------
- (void) turnOffFilterMode
{
    if ( self.dataProvider.filterType == FILTER_FILTER ) {
        self.dataProvider.filterType = FILTER_SEARCH;
        dispatch_async( dispatch_get_main_queue(), ^{
            self.toggleFilterModeButton.state = NSOnState;
            [self.toggleFilterModeButton setImage:[NSImage imageNamed:@"ButtonFilterOn"]];
        });
    }
}

#pragma mark -
#pragma mark Searching Methods
//------------------------------------------------------------------------------
- (void) fireSearchProcess
{
//    if ( [self->_currentFilterText isEqualToString:self.searchField.stringValue] ) {
//        return;
//    }
    
    if ( self->_isSearchingInProgress || self.dataProvider.isDataAnalysisRunning ) {
        return;
    }
    else {
        self->_isSearchingInProgress = YES;
    }
    
    self->_currentFilterText = self.searchField.stringValue;
    if ( [self->_currentFilterText length] ) {
        [self startActivityIndicatorWithMessage:@"Filtering ..."];
    }
    else {
        [self stopActivityIndicator];
        self->_isSearchingInProgress = NO;
//        return;
    }
    
    [self turnOffFilterMode];
    
    self.dataProvider.filter.text   = ( [self->_currentFilterText length] ? self->_currentFilterText : nil );
    
    [self.dataProvider invalidateDataWithCompletion:^{
        [self reloadLog];
        dispatch_async( dispatch_get_main_queue(), ^{
            
            BOOL found = ( self.dataProvider.firstMatchedRowIndex != NSNotFound );
            
            if ( found ) {
                [self.logTableView scrollRowToVisible:self.dataProvider.firstMatchedRowIndex];
                [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.dataProvider.firstMatchedRowIndex] byExtendingSelection:NO];
            }
            
            //[self.logTableView selectRowIndexes:self.dataProvider.matchedRowsIndexSet byExtendingSelection:NO];
            
            [self updateStatus];
            
            if ( ![self.dataProvider.originalData count] ) {
                [self stopActivityIndicator];
            }
            
            
            [self setMarkFirstAndLastEnabled:found];
            [self setMoveNextPrevEnabled:found];
            
            self->_isSearchingInProgress = NO;
            
            [self.view.window makeFirstResponder:self.logTableView];
        });
    }];
}

//------------------------------------------------------------------------------
- (void) firePartialSearch
{
    if ( self.dataProvider.isDataAnalysisRunning ) {
        return;
    }
    
    if ( [self->_delayedSearchTimer isValid] ) {
        [self->_delayedSearchTimer invalidate];
        self->_delayedSearchTimer = nil;
    }
    
    if ( self.dataProvider.isSearching ) {
        self.dataProvider.isSearching = NO;
    }
    
    [self turnOffFilterMode];
    
    self->_currentFilterText      = [self.searchField stringValue];
    self.dataProvider.filter.text = [self.searchField stringValue];
    [self startActivityIndicatorWithMessage:@"Searching ..."];
    
    [self.dataProvider matchFilteredDataWithCompletion:^( BOOL completed ){
        if ( completed ) {
            BOOL found = ( self.dataProvider.firstMatchedRowIndex != NSNotFound );
            dispatch_async( dispatch_get_main_queue(), ^{
                [self reloadLog];
                [self stopActivityIndicator];
                if ( found ) {
                    [self.logTableView scrollRowToVisible:self.dataProvider.firstMatchedRowIndex];
                    [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.dataProvider.firstMatchedRowIndex] byExtendingSelection:NO];
                }
            });
            
            [self setMarkFirstAndLastEnabled:found];
            [self setMoveNextPrevEnabled:found];
        }
        else {
            [self updateStatus];
            [self stopActivityIndicator];
            [self setMarkFirstAndLastEnabled:NO];
            [self setMoveNextPrevEnabled:NO];
        }
    }];
}

#pragma mark -
#pragma mark NSTextViewDelagate Methods
//------------------------------------------------------------------------------
- (void) controlTextDidEndEditing:(NSNotification *)notification
{
    if ( ( notification.object == self.searchField ) && !self.dataProvider.isSearching ) {
        if ( ![self->_currentFilterText isEqualToString:[self.searchField stringValue]] ) {
            [self fireSearchProcess];
        }
    }
}


//------------------------------------------------------------------------------
- (void) controlTextDidChange:(NSNotification *)notification
{
    if ( notification.object == self.searchField ) {
        if ( [self->_delayedSearchTimer isValid] ) {
            [self->_delayedSearchTimer invalidate];
        }
        self->_delayedSearchTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(firePartialSearch) userInfo:nil repeats:NO];
    }
}

//------------------------------------------------------------------------------
- (void) searchCellClearedAction:(LogSearchField*)sender
{
    [self startActivityIndicatorWithMessage:@"Resetting filter ..."];
    self->_currentFilterText = nil;
    [self.searchField setStringValue:@""];
    [self fireSearchProcess];
    if ( self.dataProvider.filterType == FILTER_FILTER ) {
        self.toggleFilterModeButton.state = NSOnState;
        [self toggleFilterMode:self.toggleFilterModeButton];
    }
}

#pragma mark -
#pragma mark Update View Methods
//------------------------------------------------------------------------------
- (void) updateStatus
{
    dispatch_async( dispatch_get_main_queue(), ^{
        
        // Update logTable ...
        
        NSUInteger selectedIndex = ( ( self.logTableView.selectedRow >= 0 ) ? self.logTableView.selectedRow : NSNotFound );
        NSUInteger index;
        
        if ( selectedIndex != NSNotFound ) {
            NSNumber *auxIndex = (NSNumber*)[self.dataProvider.matchedRowsIndexDict valueForKey:[NSString stringWithFormat:@"%lu", selectedIndex]];
            index              = ( auxIndex ? [auxIndex unsignedIntegerValue] : NSNotFound );
        }
        else {
            index = NSNotFound;
        }
        
        NSString *label = nil;
        if ( [self.data count] ) {
            if ( self.dataProvider.filterType == FILTER_SEARCH ) {
                if ( index == NSNotFound ) {
                    if ( selectedIndex == NSNotFound ) {
                        label = [NSString stringWithFormat:@"total %lu", (unsigned long)[self.dataProvider.filteredData count]];
                    }
                    else {
                        label = [NSString stringWithFormat:@"row %lu, total %lu", (unsigned long)selectedIndex + 1, (unsigned long)[self.dataProvider.filteredData count]];
                    }
                }
                else {
                    label = [NSString stringWithFormat:@"matched %lu/%lu, total %lu", (unsigned long)index + 1, (unsigned long)self.dataProvider.matchedRowsCount, (unsigned long)[self.dataProvider.filteredData count]];
                }
            }
            else {
                if ( selectedIndex == NSNotFound ) {
                    label = [NSString stringWithFormat:@"total %lu",  (unsigned long)[self.dataProvider.filteredData count]];
                }
                else {
                    label = [NSString stringWithFormat:@"row %lu, total %lu", (unsigned long)selectedIndex + 1, (unsigned long)[self.dataProvider.filteredData count]];
                }
            }
        }
        
        [self.matchedCountLabel setStringValue:( [label length] ? label : @"" )];
        
        BOOL matchedRowsFound               = ( self.dataProvider.matchedRowsCount > 0 );
        BOOL dataTransferEnabled            = ( matchedRowsFound && self.dataProvider.filterType == FILTER_SEARCH );
        
        self.removeMatchedButton.enabled    = dataTransferEnabled;
        self.toggleMatchedButton.enabled    = [self.dataProvider.filteredData count];
        self.toggleFilterModeButton.enabled = matchedRowsFound;
        
        [self setCopyEnabled:( dataTransferEnabled
                               ||
                               [self.view.window.firstResponder isKindOfClass:[NSTextView class]]
                               ||
                               [self.view.window.firstResponder isKindOfClass:[HistoryTableView class]]
                             )
         ];
        
        // Update historyTable
        selectedIndex            = ( ( self.historyTableView.selectedRow >= 0 ) ? self.historyTableView.selectedRow : NSNotFound );
        NSUInteger selectedCount = [self.historyTableView selectedRowIndexes].count;
        NSUInteger totalCount    = [self.dataProvider.historyData count];
        
        if ( selectedCount > 1 ) {
            label = [NSString stringWithFormat:@"Favorites selected %lu total %lu", selectedCount, totalCount];
        }
        else {
            if ( selectedIndex != NSNotFound ) {
                label = [NSString stringWithFormat:@"Favorites row %lu total %lu", selectedIndex + 1, totalCount];
            }
            else {
                label = [NSString stringWithFormat:@"Favorites total %lu rows.", totalCount];
            }
        }
        
        [self.favoritesInfoLabel setStringValue:label];
    });
}


@end
