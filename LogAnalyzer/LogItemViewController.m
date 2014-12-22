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

@interface LogItemViewController ()
{
    BOOL _isInitializing;
}
@end

@implementation LogItemViewController

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    
}

//------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
}

//------------------------------------------------------------------------------
- (void) viewWillAppear
{
//    CGSize size     = self.view.bounds.size;
//    CGRect frame    = self.view.superview.frame;
//    self.view.frame = CGRectMake( ( frame.size.width - size.width )/2.0f, ( frame.size.height - size.height )/2.0f, size.width, size.height  );
}

//------------------------------------------------------------------------------
- (void) viewDidAppear
{
    self->_isInitializing = YES;
    
    [self.textView setFont:[NSFont logTableRegularFont]];
    [self.textView setString:self.logItem.text];
    [self setTitle:[NSString stringWithFormat:@"Item at row:%lu", self.logItem.originalRowId + 1]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isInitializing = NO;
    });
}

#pragma mark -
#pragma mark NSTextViewDelegate Methods
//------------------------------------------------------------------------------
- (void) textViewDidChangeSelection:(NSNotification *)notification
{
    if ( !self->_isInitializing ) {
        [self.mainViewDelegate textDidSelected:self];
    }
}

@end
