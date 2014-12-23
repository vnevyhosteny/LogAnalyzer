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

@import QuartzCore;

NSString *const kRowId                              = @"RowId";
NSString *const kLogItem                            = @"LogItem";
NSString *const kLogTablePopup                      = @"LogTablePopup";

NSString *const kLogItemViewController              = @"LogItemViewController";


//==============================================================================
@interface MainViewController()
{
    BOOL          _isSearchingInProgress;
    NSString      *_currentFilterText;
    BOOL           _logTableLoading;
    NSTimer       *_delayedSearchTimer;
    LogTablePopup *_popup;
}

@property (weak) IBOutlet LogTableView           *logTableView;
@property (weak) IBOutlet NSSearchField          *searchField;
@property (weak) IBOutlet NSProgressIndicator    *activityIndicator;
@property (weak) IBOutlet NSScrollView           *logTableScrollView;
@property (weak) IBOutlet NSTextField            *infoLabel;
@property (weak) IBOutlet NSButton               *toggleFilterModeButton;
@property (weak) IBOutlet NSView                 *topBarBaseView;
@property (weak) IBOutlet NSButton               *toggleMatchedButton;
@property (weak) IBOutlet NSButton               *arrowUpButton;
@property (weak) IBOutlet NSButton               *arrowDownButton;

@property (weak) IBOutlet NSTextField            *matchedCountLabel;
@property (weak) IBOutlet NSButton               *removeMatchedButton;

@property (nonatomic, readonly) NSArray          *data;

- (IBAction) toggleFilterMode:(NSButton *)sender;
- (IBAction) removeMatchedAction:(NSButton *)sender;
- (IBAction) toggleMatchedAction:(NSButton *)sender;

- (IBAction)arrowUpAction:(NSButton *)sender;
- (IBAction)arrowDownAction:(NSButton *)sender;

@end

@implementation MainViewController

@synthesize dataProvider = _dataProvider;

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
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
    
    [self.removeMatchedButton setToolTip:@"Remove all matched items."];
    [self.toggleMatchedButton setToolTip:@"Toggle matched <-> unmatched items."];
    [self.toggleFilterModeButton setToolTip:@"Toggle view all items <-> matched only."];
    
    static dispatch_once_t onceToken = 0;
    dispatch_once( &onceToken, ^{
        NSMenu *fileMenu    = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"File"] submenu];
        [fileMenu setAutoenablesItems:NO];
        fileMenu    = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Edit"] submenu];
        [fileMenu setAutoenablesItems:NO];
    });
    
    [self setSaveEnabled:NO];
    [self setMarkFirstAndLastEnabled:NO];
    [self setCopyEnabled:NO];
    [self setPasteEnabled:NO];
    
    self.view.window.delegate                                                   = self;
}


//------------------------------------------------------------------------------
- (void) dealloc
{
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
    [self.dataProvider pasteLogItems:logItems withCompletion:completion];
}

#pragma mark -
#pragma mark Notifications
//------------------------------------------------------------------------------
- (void) handleNotifications:(NSNotification*)notification
{
}

//------------------------------------------------------------------------------
- (void) windowDidBecomeMain:(NSNotification *)notification
{
    [self setSaveEnabled:( [self.dataProvider.originalLogFileName length] > 0 )];
    
    LogAnalyzerWindowController *windowController = (LogAnalyzerWindowController*)self.view.window.windowController;
    [windowController setActive];
    
    [self updateStatus];
    
    LogAnalyzerWindowController *sourceController = [WindowManager sharedInstance].sourceWindowController;
    [self  setPasteEnabled:( sourceController && ( sourceController != windowController ) )];
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
        self->_dataProvider = [DataProvider new];
    }
    return self->_dataProvider;
}

#pragma mark -
#pragma mark Enable/Disable Menu Items
//------------------------------------------------------------------------------
- (void) setMarkFirstAndLastEnabled:(BOOL)enabled
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSMenu     *fileMenu  = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Edit"] submenu];
        NSMenuItem *menuItem  = [fileMenu itemWithTitle:@"Mark first row"];
        [menuItem setEnabled:enabled];
        menuItem  = [fileMenu itemWithTitle:@"Mark last row"];
        [menuItem setEnabled:enabled];
    });
}

//------------------------------------------------------------------------------
- (void) setSaveEnabled:(BOOL)enabled
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSMenu     *fileMenu  = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"File"] submenu];
        NSMenuItem *menuItem  = [fileMenu itemWithTitle:@"Save"];
        [menuItem setEnabled:enabled];
    });
}

//------------------------------------------------------------------------------
- (void) setCopyEnabled:(BOOL)enabled
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSMenu     *fileMenu  = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Edit"] submenu];
        NSMenuItem *menuItem  = [fileMenu itemWithTitle:@"Copy"];
        [menuItem setEnabled:enabled];
    });
}

//------------------------------------------------------------------------------
- (void) setPasteEnabled:(BOOL)enabled
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSMenu     *fileMenu  = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Edit"] submenu];
        NSMenuItem *menuItem  = [fileMenu itemWithTitle:@"Paste"];
        [menuItem setEnabled:enabled];
    });
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
    [self startActivityIndicatorWithMessage:@"Reloading ..."];
    [self.dataProvider removeAllMatchedItemsWithCompletion:^{
        [self reloadLog];
        [self stopActivityIndicator];
    }];
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
- (IBAction) arrowUpAction:(NSButton *)sender
{
    NSUInteger index = [self.dataProvider previousMatchedRowIndex];
    if ( index != NSNotFound ) {
        if ( ( index > 0 ) && ( index < self.dataProvider.lastMatchedRowIndex ) ) {
            index--;
        }
        [self.logTableView scrollRowToVisible:index];
        [self reloadVisibleRowsOnly];
        [self updateStatus];
    }
}

//------------------------------------------------------------------------------
- (IBAction) arrowDownAction:(NSButton *)sender
{
    NSUInteger index = [self.dataProvider nextMatchedRowIndex];
    if ( index != NSNotFound ) {
        if ( index < [self.data count] - 1 ) {
            index++;
        }
        [self.logTableView scrollRowToVisible:index];
        [self reloadVisibleRowsOnly];
        [self updateStatus];
    }
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
            [cell setTextColor:( logItem.matchFilter ? ( ( row == self.dataProvider.currentMatchedRowIndex ) ? [NSColor logTableSelectedMatchedColor] : [NSColor logTableMatchedColor] ) : [NSColor logTablePlainTextColor])];
        }
    }
    
    if ( logItem.matchFilter && ( row == self.dataProvider.currentMatchedRowIndex ) ) {
        [cell setFont:[NSFont logTableBoldFont]];
    }
    else {
        [cell setFont:[NSFont logTableRegularFont]];
    }
    
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

#pragma mark -
#pragma mark NSTableViewDelegate Methods
//------------------------------------------------------------------------------
- (void) doubleClick:(id)object
{
    [self startActivityIndicator];
    NSInteger              row        = [self.logTableView clickedRow];
    [self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    LogItemViewController *controller = (LogItemViewController*)[[NSStoryboard storyboardWithName:kMainStoryboard bundle:nil] instantiateControllerWithIdentifier:kLogItemViewController];
    controller.logItem                = (LogItem*)[self.dataProvider.filteredData objectAtIndex:row];
    controller.mainViewDelegate       = self;
    [self presentViewControllerAsModalWindow:controller];
    [self stopActivityIndicator];
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
- (void) textDidSelected:(LogItemViewController*)controller
{
    NSRange range = controller.textView.selectedRange;
    if ( ( range.location != NSNotFound ) && ( range.length > 0 ) ) {
        [self.searchField setStringValue:[controller.textView.string substringWithRange:range]];
        [self dismissViewController:controller];
        [self.searchField becomeFirstResponder];
        [self fireSearchProcess];
    }
}

//------------------------------------------------------------------------------
- (void) reloadLog
{
    dispatch_async( dispatch_get_main_queue(), ^{
        self->_logTableLoading = YES;
        
        if ( [self.data count] ) {
            [self startActivityIndicatorWithMessage:@"Reloading ..."];
        }
        
        [self.logTableView reloadData];
        [self updateStatus];
    });
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
            }];
        }
        else {
            [self startActivityIndicatorWithMessage:@"Resetting marks ..."];
            [self.dataProvider removeFromToMarksWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:NO];
            }];
        }
    }
    else {
        [self reloadVisibleRowsOnly];
        [self updateStatus];
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
            }];
        }
        else {
            [self startActivityIndicatorWithMessage:@"Resetting marks ..."];
            [self.dataProvider removeFromToMarksWithCompletion:^{
                [self reloadVisibleRowsOnly];
                [self updateStatus];
                [self stopActivityIndicator];
                [self setMarkFirstAndLastEnabled:NO];
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
        }];
    }
}

//------------------------------------------------------------------------------
- (void) markFirstRow
{
    if ( self.dataProvider.currentMatchedRowIndex != NSNotFound ) {
        [self popup:nil didSelectMarkFromWithLogItem:(LogItem*)[self.dataProvider.filteredData objectAtIndex:self.dataProvider.currentMatchedRowIndex]];
    }
}

//------------------------------------------------------------------------------
- (void) markLastRow
{
    if ( self.dataProvider.currentMatchedRowIndex != NSNotFound ) {
        [self popup:nil didSelectMarkToWithItem:(LogItem*)[self.dataProvider.filteredData objectAtIndex:self.dataProvider.currentMatchedRowIndex]];
    }
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
            
            if ( self.dataProvider.firstMatchedRowIndex != NSNotFound ) {
                [self.logTableView scrollRowToVisible:self.dataProvider.firstMatchedRowIndex + 1];
            }
            
            //[self.logTableView selectRowIndexes:self.dataProvider.matchedRowsIndexSet byExtendingSelection:NO];
            
            [self updateStatus];
            
            if ( ![self.dataProvider.originalData count] ) {
                [self stopActivityIndicator];
            }
            
            [self setMarkFirstAndLastEnabled:( self.dataProvider.firstMatchedRowIndex != NSNotFound )];
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
            dispatch_async( dispatch_get_main_queue(), ^{
                [self reloadLog];
                [self stopActivityIndicator];
            });
            [self setMarkFirstAndLastEnabled:( self.dataProvider.firstMatchedRowIndex != NSNotFound )];
        }
        else {
            [self updateStatus];
            [self stopActivityIndicator];
            [self setMarkFirstAndLastEnabled:NO];
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
        NSUInteger index = ( ( self.dataProvider.currentMatchedRow != NSNotFound ) ? self.dataProvider.currentMatchedRow + 1 : 0 );
        [self.matchedCountLabel setStringValue:( ( self.dataProvider.filterType == FILTER_SEARCH )
                                                 ?
                                                 [NSString stringWithFormat:@"matched %lu/%lu, total %lu", (unsigned long)index, (unsigned long)self.dataProvider.matchedRowsCount, (unsigned long)[self.dataProvider.filteredData count]]
                                                 :
                                                 [NSString stringWithFormat:@"matched 0/0, total %lu", (unsigned long)[self.dataProvider.filteredData count]]
                                               )
        ];
        
        BOOL matchedRowsFound               = ( self.dataProvider.matchedRowsCount > 0 );
        BOOL dataTransferEnabled            = ( matchedRowsFound && self.dataProvider.filterType == FILTER_SEARCH );
        
        self.removeMatchedButton.enabled    = dataTransferEnabled;
        self.toggleMatchedButton.enabled    = dataTransferEnabled;
        self.toggleFilterModeButton.enabled = matchedRowsFound;
        self.arrowDownButton.enabled        = dataTransferEnabled;
        self.arrowUpButton.enabled          = dataTransferEnabled;
        
        [self setCopyEnabled:dataTransferEnabled];
    });
}

@end
