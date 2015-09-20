//
//  LogItemViewController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 08.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogItemViewController.h"
#import "MainViewController.h"
#import "NSFont+LogAnalyzer.h"
#import "LogTextView.h"

//==============================================================================
@interface LogItemViewController ()
{
    BOOL              _isInitializing;
}
@end

//==============================================================================
@implementation LogItemViewController

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    self.textView.closeCompletion = ^{
        [self.mainViewDelegate textDidSelected:self];
    };
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
    self->_isInitializing = YES;
    
    self.view.window.styleMask = NSClosableWindowMask | NSTitledWindowMask;
    
    [self.textView setFont:[NSFont logTableRegularFont]];
    if ( [[[self logItem] text] length] ) {
        [self.textView setString:self.logItem.text];
        [self setTitle:[NSString stringWithFormat:@"Item at row:%lu", self.logItem.originalRowId + 1]];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isInitializing = NO;
    });
}



@end
