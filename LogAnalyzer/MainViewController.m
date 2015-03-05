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

#import "LogItem.h"
#import "LogItemViewController.h"
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

//==============================================================================
@interface MainViewController()
{
    BOOL              _isSearchingInProgress;
    NSString         *_currentFilterText;
    BOOL              _logTableLoading;
    NSTimer          *_delayedSearchTimer;
    LogTablePopup    *_popup;
    dispatch_queue_t  _serial_queue;
}

@property (weak) IBOutlet LogTableView           *logTableView;
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

@property (nonatomic, readonly) NSArray          *data;
@property (nonatomic, readwrite) BOOL             isRowHeightUpdatePending;

- (IBAction) toggleFilterMode:(NSButton *)sender;
- (IBAction) removeMatchedAction:(NSButton *)sender;
- (IBAction) toggleMatchedAction:(NSButton *)sender;


@end

@implementation MainViewController

@synthesize dataProvider              = _dataProvider;
@synthesize isRowHeightUpdatePending = _isRowHeightUpdatePending;

static BOOL isPrimaryController = YES;

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    self->_serial_queue = dispatch_queue_create( "LogAnalyzer.SerialQueue", DISPATCH_QUEUE_SERIAL );
    dispatch_set_target_queue( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), self->_serial_queue );
    
    [self.infoLabel setStringValue:@""];
    if ( [self.searchField acceptsFirstResponder] ) {
        [self.searchField resignFirstResponder];
    }
    
    // Set the top bar background color ...
    
    CALayer    *viewLayer = [CALayer layer];
    CGColorRef  color = CGColorCreateGenericRGB( 255.0f, 255.0f, 255.0f, 1.0f );
    [viewLayer setBackgroundColor:color];
    CFRelease( color );
    [self.topBarBaseView setWantsLayer:YES];
    [self.topBarBaseView setLayer:viewLayer];

    // Setup the logTableView ...
    
    [self.logTableView becomeFirstResponder];
    [self.logTableView setTarget:self];
    [self.logTableView setDoubleAction:@selector(doubleClick:)];
    self.logTableView.mainViewDelegate                                          = self;
    
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
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(handleNotifications:) name:ReloadLogNeededNotification object:nil];
    [center addObserver:self selector:@selector(handleNotifications:) name:NSViewBoundsDidChangeNotification object:[self.logTableScrollView contentView]];
    [center addObserver:self selector:@selector(handleNotifications:) name:SearchFieldBecomeFirstResponderNotification object:nil];
}


//------------------------------------------------------------------------------
- (void) dealloc
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:ReloadLogNeededNotification object:nil];
    [center removeObserver:self name:NSViewBoundsDidChangeNotification object:[self.logTableScrollView contentView]];
    [center removeObserver:self name:SearchFieldBecomeFirstResponderNotification object:nil];
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
}

//------------------------------------------------------------------------------
- (void) windowDidBecomeMain:(NSNotification *)notification
{
    [self setSaveEnabled:( [self.dataProvider.originalLogFileName length] > 0 )];
    
    LogAnalyzerWindowController *windowController = (LogAnalyzerWindowController*)self.view.window.windowController;
//    [windowController setActive];
    
    [self updateStatus];
    
    LogAnalyzerWindowController *sourceController = [WindowManager sharedInstance].sourceWindowController;
    if ( [self.view.window.firstResponder isKindOfClass:[NSTextView class]] ) {
        [self setPasteEnabled:YES];
        [self setCopyEnabled:YES];
    }
    else {
        [self  setPasteEnabled:( sourceController && ( sourceController != windowController ) )];
    }
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
- (BOOL) isDragAndDropEnabled
{
    return YES;//( self.dataProvider.filterType == FILTER_SEARCH );
}

//------------------------------------------------------------------------------
- (void) find
{
    [self.view.window makeFirstResponder:self.searchField];
}

#pragma mark -
#pragma mark Actions
//------------------------------------------------------------------------------
- (IBAction) toggleFilterMode:(NSButton *)sender
{
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
    
    [self startActivityIndicatorWithMessage:@"Switching mode ..."];
    [self.dataProvider invalidateDataWithCompletion:^{
        [self reloadLog];
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
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self.data count];
}


//------------------------------------------------------------------------------
- (id)          tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
                      row:(NSInteger)rowIndex
{
    if ( [[aTableColumn.headerCell stringValue] isEqualToString:kRowId] ) {
        return [NSString stringWithFormat:@"%lu", (unsigned long)((LogItem*)[self.data objectAtIndex:rowIndex]).originalRowId + 1];
    }
    if ( [[aTableColumn.headerCell stringValue] isEqualToString:kLogItem] ) {
        return ((LogItem*)[self.data objectAtIndex:rowIndex]).text;
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
    LogTableCell     *cell       = nil;
    LogItem          *logItem    = (LogItem*)[self.data objectAtIndex:row];
    BOOL              isMarked   = ( ( self.dataProvider.rowFrom == logItem.originalRowId ) && ( self.dataProvider.rowTo == NSNotFound ) );
    
    if ( [[tableColumn.headerCell stringValue] isEqualToString:kRowId] ) {
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
    
    else if ( [[tableColumn.headerCell stringValue] isEqualToString:kLogItem] ) {
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
                [cell setTextColor:( logItem.matchFilter ? ( ( ( row == self.dataProvider.currentMatchedRowIndex ) && ( self.view.window.firstResponder == self.logTableView ) ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : [NSColor whiteColor])];
            }
            else {
                //[cell setTextColor:( logItem.matchFilter ? ( ( row == self.dataProvider.currentMatchedRowIndex ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : [NSColor logTablePlainTextColor])];
                [cell setTextColor:( logItem.matchFilter ? [NSColor logTableMatchedColor] : [NSColor logTablePlainTextColor])];
            }
        }
    }
    
//    if ( logItem.matchFilter && ( row == self.dataProvider.currentMatchedRowIndex ) ) {
//        [cell setFont:[NSFont logTableBoldFont]];
//    }
//    else {
//        [cell setFont:[NSFont logTableRegularFont]];
//    }
    
    [cell setFont:[NSFont logTableRegularFont]];
    
    [cell setEditable:NO];
    [cell setEnabled:NO];
    [cell setLineBreakMode:NSLineBreakByWordWrapping];
    
    return cell;
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
    
    LogItem         *logItem = [self.data objectAtIndex:row];
    [cell setStringValue:logItem.text];
    
    // See how tall it naturally would want to be if given a restricted with, but unbound height
    NSRect  constrainedBounds = NSMakeRect( 0.f, 0.0f, [column width], CGFLOAT_MAX );
    NSSize  naturalSize       = [cell cellSizeForBounds:constrainedBounds];

    return ( ( naturalSize.height > defaultHeight ) ? naturalSize.height : defaultHeight );

}

//------------------------------------------------------------------------------
- (void) tableView:(NSTableView *)aTableView
   willDisplayCell:(id)aCell
    forTableColumn:(NSTableColumn *)aTableColumn
               row:(NSInteger)rowIndex
{
    if ( self->_logTableLoading ) {
        [self stopActivityIndicator];
        self->_logTableLoading = NO;
    }
}


//------------------------------------------------------------------------------
- (BOOL)    tableView:(NSTableView *)aTableView
 writeRowsWithIndexes:(NSIndexSet *)rowIndexes
         toPasteboard:(NSPasteboard *)pboard
{
    if ( [rowIndexes count] ) {
        LogItem    *draggedLogItem = [self.data objectAtIndex:rowIndexes.firstIndex];
        [self.dataProvider writeMatchedLogItems:draggedLogItem.matchFilter toPasteboard:pboard];
        return YES;
    }
    else {
        return NO;
    }
}

//------------------------------------------------------------------------------
- (void) showLogItemPopupAtRow:(NSInteger)row
{
    [self startActivityIndicator];
    [self setCopyEnabled:NO];
    
    LogItemViewController *controller = (LogItemViewController*)[[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateControllerWithIdentifier:kLogItemViewController];
    controller.logItem                = (LogItem*)[self.dataProvider.filteredData objectAtIndex:row];
    controller.mainViewDelegate       = self;
    [self presentViewControllerAsModalWindow:controller];
    
    [self stopActivityIndicator];
}

//------------------------------------------------------------------------------
- (void) deleteRow:(NSUInteger)row
{
    [self startActivityIndicatorWithMessage:@"Deleting row ..."];
    [self.dataProvider deleteRow:row];
    [self reloadLog];
    [self stopActivityIndicator];
}


#pragma mark -
#pragma mark NSTableViewDelegate Methods
//------------------------------------------------------------------------------
- (void) doubleClick:(id)object
{
    NSInteger row = [self.logTableView clickedRow];
    [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self showLogItemPopupAtRow:row];
}

//------------------------------------------------------------------------------
- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger row = self.logTableView.selectedRow;
    [self setMarkFirstAndLastEnabled:( ( row >= 0 ) && [self.data count] )];
    if ( row >= 0 ) {
        [self.dataProvider setCurrentMatchedRowIndex:row];
    }
    [self updateStatus];
}

//------------------------------------------------------------------------------
- (void) adjustRowHeightForVisibleRows
{
    static CGFloat const DeltaY = 100.0f;
    dispatch_async( dispatch_get_main_queue(), ^{
        
        CGRect visibleRect       = self.logTableScrollView.contentView.bounds;
        visibleRect.origin.y    -= DeltaY;
        visibleRect.size.height += DeltaY;
        NSRange visibleRows      = [self.logTableView rowsInRect:visibleRect];
        
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0];
        [self.logTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:visibleRows]];
        [NSAnimationContext endGrouping];
        
        self.isRowHeightUpdatePending = NO;
    });
}

//------------------------------------------------------------------------------
- (void) scrollViewContentBoundsDidChange:(NSNotification*)notification
{
    if ( self.isRowHeightUpdatePending ) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(adjustRowHeightForVisibleRows) object:nil];
    }
    [self performSelector:@selector(adjustRowHeightForVisibleRows) withObject:nil afterDelay:0.2f];
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
        }
    }];
}

//------------------------------------------------------------------------------
- (void) appendLogFromText:(NSString*)logText
{
    dispatch_async( dispatch_get_main_queue(), ^{
        //[self.view.window setTitle:[fileName lastPathComponent]];
    });
    
    [self startActivityIndicatorWithMessage:@"Pasting text ..."];
    [self.dataProvider appendLogFromText:logText completion:^(NSError *error) {
        if ( !error ) {
            [self reloadLog];
            [self setSaveEnabled:YES];
        }
    }];
}



//------------------------------------------------------------------------------
- (void) textDidSelected:(LogItemViewController*)controller
{
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
    }];
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

#pragma mark -
#pragma mark Searching Methods
//------------------------------------------------------------------------------
- (void) fireSearchProcess
{
    if ( [self->_currentFilterText isEqualToString:self.searchField.stringValue] ) {
        return;
    }
    
    if ( self->_isSearchingInProgress ) {
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
        return;
    }
    
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
        });
    }];
}

//------------------------------------------------------------------------------
- (void) firePartialSearch
{
    if ( [self->_delayedSearchTimer isValid] ) {
        [self->_delayedSearchTimer invalidate];
        self->_delayedSearchTimer = nil;
    }
    
    if ( self.dataProvider.isSearching ) {
        self.dataProvider.isSearching = NO;
    }
    
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
        [self fireSearchProcess];
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

#pragma mark -
#pragma mark Update View Methods
//------------------------------------------------------------------------------
- (void) updateStatus
{
    dispatch_async( dispatch_get_main_queue(), ^{
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
        
        [self setCopyEnabled:( dataTransferEnabled || [self.view.window.firstResponder isKindOfClass:[NSTextView class]] )];
    });
}


@end
