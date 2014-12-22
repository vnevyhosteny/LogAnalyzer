//
//  LogTablePopup.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 18.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "LogTablePopup.h"

@interface LogTablePopup ()
@property (weak) IBOutlet NSButton *markFromButton;
@property (weak) IBOutlet NSButton *markToButton;

- (IBAction)markFromAction:(NSButton *)sender;
- (IBAction)markToAction:(NSButton *)sender;

@end

@implementation LogTablePopup

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

//------------------------------------------------------------------------------
- (IBAction) markFromAction:(NSButton *)sender
{
    [self.mainViewDelegate popup:self didSelectMarkFromWithLogItem:self.logItem];
}

//------------------------------------------------------------------------------
- (IBAction) markToAction:(NSButton *)sender
{
    [self.mainViewDelegate popup:self didSelectMarkToWithItem:self.logItem];
}

@end
