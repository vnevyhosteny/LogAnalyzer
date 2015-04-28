//
//  HistoryTableView.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 04.04.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

@import Carbon;
#import "HistoryTableView.h"
#import "MainViewController.h"
#import "WindowManager.h"

//==============================================================================
@interface HistoryTableView()

@end

//==============================================================================
@implementation HistoryTableView

//------------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ( ( self = [super initWithCoder:coder] ) ) {
        [self registerForDraggedTypes:@[LogItemPasteboardType]];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) dealloc
{
    [self unregisterDraggedTypes];
}


//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

//------------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
{
    switch ( event.keyCode ) {
        case kVK_Delete:
           [self.mainViewDelegate deleteSelectedHistoryRows];
            break;
            
        case kVK_ANSI_A:
            if ( event.modifierFlags & NSCommandKeyMask ) {
                [self.mainViewDelegate selectAllHistoryRows];
            }
            else {
                [super keyDown:event];
            }
            break;
            
        default:
            [super keyDown:event];
    }
}


#pragma mark -
#pragma mark NSDraggingSource Methods
//------------------------------------------------------------------------------
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
    [self setNeedsDisplay:YES];
}

//------------------------------------------------------------------------------
- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    if ( context == NSDraggingContextWithinApplication ) {
        return NSDragOperationCopy;
    }
    else {
        return ( ( context == NSDraggingContextOutsideApplication ) ? NSDragOperationGeneric : NSDragOperationNone );
    }
}

//------------------------------------------------------------------------------
- (void) draggingSession:(NSDraggingSession *)session
        willBeginAtPoint:(NSPoint)screenPoint
{
    [self.mainViewDelegate startActivityIndicatorWithMessage:@"Drag proceeds ..."];
}

//------------------------------------------------------------------------------
- (void) draggingSession:(NSDraggingSession *)session
            endedAtPoint:(NSPoint)screenPoint
               operation:(NSDragOperation)operation
{
    NSArray        *draggedItems   = session.draggingPasteboard.pasteboardItems;
    NSUInteger      count          = [draggedItems count];
    NSMutableArray *aux            = nil;
    
    if ( count > 0 ) {
        aux = [NSMutableArray arrayWithCapacity:count];
        LogItem *logItem;
        for ( __weak NSPasteboardItem *item in draggedItems ) {
            logItem = (LogItem*)[NSKeyedUnarchiver unarchiveObjectWithData:[item dataForType:LogItemPasteboardType]];
            [logItem setMatchFilter:NO];
            [aux addObject:logItem];
        }
    }
    
    [session.draggingPasteboard clearContents];
    
    if ( ![aux count] ) {
        [self.mainViewDelegate stopActivityIndicator];
        return;
    }
    
    NSInteger           windowNumber   = [NSWindow windowNumberAtPoint:screenPoint belowWindowWithWindowNumber:0];
    id                  controller     = [[[WindowManager sharedInstance] controllerWithWindowNumber:windowNumber] mainViewController];
    MainViewController *mainController = ( [controller isKindOfClass:[MainViewController class]] ? (MainViewController*)controller : nil );
    
    if ( mainController ) {
        [mainController pasteLogItems:aux withCompletion:^{
            [mainController reloadLog];
        }];
    }
    else {
        [self.mainViewDelegate createNewWindowWithLogItems:aux atPoint:screenPoint];
    }
    
    [self.mainViewDelegate stopActivityIndicator];
}


@end
