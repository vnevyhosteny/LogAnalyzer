//
//  MainViewController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 06.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "MainViewController.h"
#import "LogTableView.h"
#import "DataProvider.h"
#import "LogItem.h"
#import "LogItemViewController.h"
#import "AppDelegate.h"
#import "WindowManager.h"
#import "LogAnalyzerWindowController.h"

NSString *const kRowId                              = @"RowId";
NSString *const kLogItem                            = @"LogItem";


NSString *const kLogItemViewController              = @"LogItemViewController";


static CGFloat   const LogFontSize                  = 11.0f;
static NSString *const LogFontFamily                = @"Menlo";


//==============================================================================
@interface MainViewController()
{
    BOOL      _isSearchingInProgress;
    NSString *_currentFilterText;
    BOOL      _logTableLoading;
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
@property (nonatomic, readonly) DataProvider     *dataProvider;

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
    
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB( 255.0f, 255.0f, 255.0f, 1.0f )]; //RGB plus Alpha Channel
    [self.topBarBaseView setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [self.topBarBaseView setLayer:viewLayer];

    
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
}

//------------------------------------------------------------------------------
- (void) viewDidLoad
{
    [super viewDidLoad];
}

//------------------------------------------------------------------------------
- (void) viewDidAppear
{
    [self.logTableView becomeFirstResponder];
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
- (void) pasteLogItems:(NSArray*)logItems
{
    [self.dataProvider pasteLogItems:logItems];
}

#pragma mark -
#pragma mark Notifications
//------------------------------------------------------------------------------
- (void) handleNotifications:(NSNotification*)notification
{
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

//------------------------------------------------------------------------------
+ (NSFont*) logFontRegular
{
    static NSFont          *__font__       = nil;
    static dispatch_once_t  __once_token__ = 0;
    dispatch_once(&__once_token__, ^{
        __font__ = [[NSFontManager sharedFontManager] fontWithFamily:LogFontFamily
                                                              traits:NSUnboldFontMask
                                                              weight:0
                                                                size:LogFontSize];
    });
    return __font__;
}

//------------------------------------------------------------------------------
+ (NSFont*) logFontBold
{
    static NSFont          *__font__       = nil;
    static dispatch_once_t  __once_token__ = 0;
    dispatch_once(&__once_token__, ^{
        __font__ = [[NSFontManager sharedFontManager] fontWithFamily:LogFontFamily
                                                              traits:NSBoldFontMask
                                                              weight:0
                                                                size:LogFontSize];
    });
    return __font__;
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
- (IBAction) toggleMatchedAction:(NSButton *)sender
{
    [self startActivityIndicatorWithMessage:@"Toggle matched ..."];
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
        [self.logTableView scrollRowToVisible:index];
        [self updateStatus];
    }
}

//------------------------------------------------------------------------------
- (IBAction) arrowDownAction:(NSButton *)sender
{
    NSUInteger index = [self.dataProvider nextMatchedRowIndex];
    if ( index != NSNotFound ) {
        [self.logTableView scrollRowToVisible:index + 1];
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
    NSTextFieldCell  *cell       = nil;
    LogItem          *logItem    = (LogItem*)[self.data objectAtIndex:row];
    
    if ( [[tableColumn.headerCell stringValue] isEqualToString:kRowId] ) {
        NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)logItem.originalRowId + 1];
        cell           = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];
        if ( cell ) {
            [cell setStringValue:text];
        }
        else {
            cell = [[NSTextFieldCell alloc] initTextCell:text];
        }
        [cell setSelectable:NO];
        [cell setCellAttribute:NSCellDisabled to:1];
        [cell setTextColor:[NSColor lightGrayColor]];
        
        [cell setAlignment:NSRightTextAlignment];
    }
    
    else if ( [[tableColumn.headerCell stringValue] isEqualToString:kLogItem] ) {
        cell           = [tableView viewAtColumn:1 row:row makeIfNecessary:NO];
        if ( cell ) {
            [cell setStringValue:logItem.text];
        }
        else {
            cell = [[NSTextFieldCell alloc] initTextCell:logItem.text];
        }
        [cell setSelectable:YES];
        [cell setCellAttribute:NSCellEditable to:0];
        [cell setTextColor:( logItem.matchFilter ? [NSColor blueColor] : [NSColor blackColor])];
    }
    
    if ( logItem.matchFilter ) {
        [cell setFont:[MainViewController logFontBold]];
    }
    else {
        [cell setFont:[MainViewController logFontRegular]];
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
- (void) appendLogFromFile:(NSString*)fileName
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [self.view.window setTitle:[fileName lastPathComponent]];
    });
    
    [self startActivityIndicatorWithMessage:@"Reading file ..."];
    [self.dataProvider appendLogFromFile:fileName completion:^(NSError *error) {
        if ( !error ) {
            [self reloadLog];
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
    NSRange visibleRows = [self.logTableView rowsInRect:self.logTableScrollView.contentView.bounds];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0];
    [self.logTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:visibleRows]];
    [NSAnimationContext endGrouping];
}

//------------------------------------------------------------------------------
- (void) createNewWindowWithLogItems:(NSArray*)logItems atPoint:(NSPoint)point
{
    LogAnalyzerWindowController *windowController = [[WindowManager sharedInstance] createNewWindowWithLogItems:logItems title:[self.searchField stringValue]];
    
    NSRect frame = windowController.window.frame;
    point.y     -= frame.size.height;
    [windowController.window setFrameOrigin:point];
    
    [windowController.window makeKeyAndOrderFront:self];
    [windowController.mainWiewController reloadLog];
}

//------------------------------------------------------------------------------
- (BOOL) isDragAndDropEnabled
{
    return ( self.dataProvider.filterType == FILTER_SEARCH );
}

#pragma mark -
#pragma mark NSTextViewDelagate Methods
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
        [self startActivityIndicatorWithMessage:@"Searching ..."];
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
            self->_isSearchingInProgress = NO;
        });
    }];
}

//------------------------------------------------------------------------------
- (void) controlTextDidEndEditing:(NSNotification *)notification
{
    if ( notification.object == self.searchField ) {
        [self fireSearchProcess];
    }
}

#pragma mark -
#pragma mark Update View Methods
//------------------------------------------------------------------------------
- (void) updateStatus
{
    dispatch_async( dispatch_get_main_queue(), ^{
        NSUInteger index = ( ( self.dataProvider.currentMatchedRow != NSNotFound ) ? self.dataProvider.currentMatchedRow + 1 : 0 );
        [self.matchedCountLabel setStringValue:[NSString stringWithFormat:@"matched %lu/%lu, total %lu", (unsigned long)index, (unsigned long)self.dataProvider.matchedRowsCount, (unsigned long)[self.dataProvider.filteredData count]]];
        
        BOOL matchedRowsFound               = ( self.dataProvider.matchedRowsCount > 0 );
        self.removeMatchedButton.enabled    = matchedRowsFound;
        self.toggleMatchedButton.enabled    = matchedRowsFound;
        self.toggleFilterModeButton.enabled = matchedRowsFound;
        self.arrowDownButton.enabled        = matchedRowsFound;
        self.arrowUpButton.enabled          = matchedRowsFound;
    });
}

@end
