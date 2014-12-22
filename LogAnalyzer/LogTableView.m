//
//  LogTableView.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 07.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogTableView.h"
#import "LogItem.h"
#import "LogAnalyzerWindow.h"
#import "WindowManager.h"
#import "MainViewController.h"

@interface LogTableView()
{
    NSDate *_lastMouseDown;
}
@end

@implementation LogTableView

static NSString *const kPrivateDragUTI         = @"cz.nefa.DragAndDrop";
NSString *const LogTableRowClickedNotification = @"LogTableRowClickedNotification";
NSString *const kClickedRow                    = @"ClickedRow";

//------------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ( ( self = [super initWithCoder:coder] ) ) {
        [self registerForDraggedTypes:@[NSFilenamesPboardType, LogItemPasteboardType]];
        self->_clickedRowAtMouseDown = -1;
        self->_lastMouseDown         = nil;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) dealloc
{
    [self unregisterDraggedTypes];
}

//------------------------------------------------------------------------------
- (void) drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
}

#pragma mark -
#pragma mark Helper Methods
//------------------------------------------------------------------------------
- (NSString*) fileNameWithDraggingInfo:(id <NSDraggingInfo>)sender
{
    NSPasteboard *paste       = [sender draggingPasteboard];
    NSArray      *types       = [NSArray arrayWithObjects:NSTIFFPboardType, NSFilenamesPboardType, nil];
    NSString     *desiredType = [paste availableTypeFromArray:types];
    NSData       *carriedData = [paste dataForType:desiredType];
    
    if ( [carriedData length] ) {
        //the pasteboard was able to give us some meaningful data
        if ( [desiredType isEqualToString:NSFilenamesPboardType] ) {
            //we have a list of file names in an NSData object
            NSArray  *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
            NSString *path      = ( [fileArray count] ? [fileArray firstObject] : nil );
            return ( ( [path length] && ( [[path pathExtension] rangeOfString:@"log" options:NSCaseInsensitiveSearch].location != NSNotFound ) ) ? path : nil );
        }
        else {
            //this can't happen
            NSAssert(NO, @"This can't happen");
            return nil;
        }
    }
    
    return nil;
}

#pragma mark -
#pragma mark NSDraggingDestination Methods
//------------------------------------------------------------------------------
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
    [self.mainViewDelegate startActivityIndicatorWithMessage:@"Drag proceeds ..."];
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric) {
        //this means that the sender is offering the type of operation we want
        //return that we want the NSDragOperationGeneric operation that they
        //are offering
        return NSDragOperationGeneric;
    }
    else if (( NSDragOperationCopy & [sender draggingSourceOperationMask]) == NSDragOperationCopy ) {
        return NSDragOperationCopy;
    }
    else {
        //since they aren't offering the type of operation we want, we have
        //to tell them we aren't interested
        return NSDragOperationNone;
    }
}

//------------------------------------------------------------------------------
- (void) draggingExited:(id <NSDraggingInfo>)sender
{
//    [self.mainViewDelegate stopActivityIndicator];
}

//------------------------------------------------------------------------------
- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric) {
        //this means that the sender is offering the type of operation we want
        //return that we want the NSDragOperationGeneric operation that they
        //are offering
        return NSDragOperationGeneric;
    }
    else if (( NSDragOperationCopy & [sender draggingSourceOperationMask]) == NSDragOperationCopy ) {
        return NSDragOperationCopy;
    }
    else {
        //since they aren't offering the type of operation we want, we have
        //to tell them we aren't interested
        return NSDragOperationNone;
    }
}

//------------------------------------------------------------------------------
- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return [self.mainViewDelegate isDragAndDropEnabled];
}

//------------------------------------------------------------------------------
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric) {
        
        NSString *path = [self fileNameWithDraggingInfo:sender];
        if ( [path length] ) {
            [self.mainViewDelegate appendLogFromFile:path];
        }
        
        [self setNeedsDisplay:YES];    //redraw us with the new image
        return YES;
    }
    
    else if (( NSDragOperationCopy & [sender draggingSourceOperationMask]) == NSDragOperationCopy ) {
        return YES;
    }
    
    else {
        return NO;
    }
}

//------------------------------------------------------------------------------
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
    [self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark NSDraggingSource Methods
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
//- (BOOL) ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session
//{
//    NSArray *draggedItems = session.draggingPasteboard.pasteboardItems;
//    if ( [draggedItems count] ) {
//        LogItem *logItem = (LogItem*)[NSKeyedUnarchiver unarchiveObjectWithData:[[draggedItems firstObject] dataForType:LogItemPasteboardType]];
//        return !logItem.matchFilter;
//    }
//    else {
//        return YES;
//    }
//}

//------------------------------------------------------------------------------
- (void) draggingSession:(NSDraggingSession *)session
            endedAtPoint:(NSPoint)screenPoint
               operation:(NSDragOperation)operation
{
    NSArray        *draggedItems   = session.draggingPasteboard.pasteboardItems;
    NSMutableArray *aux            = [NSMutableArray new];
    
    
    if ( [draggedItems count] ) {
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
    id                  controller     = [[[WindowManager sharedInstance] controllerWithWindowNumber:windowNumber] mainWiewController];
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

//------------------------------------------------------------------------------
- (void) mouseDown:(NSEvent *)event
{
    NSPoint eventLocation        = [event locationInWindow];
    NSPoint localPoint           = [self convertPoint:eventLocation toView:nil];
    
    self->_clickedRowAtMouseDown = [self rowAtPoint:localPoint];
    [self.mainViewDelegate clickedRowAtIndex:self->_clickedRowAtMouseDown atPoint:localPoint];
    
    [super mouseDown:event];
}
@end
