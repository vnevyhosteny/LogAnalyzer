//
//  HistoryTableCell.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 04.04.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import "HistoryTableCell.h"

@implementation HistoryTableCell

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    self.backgroundStyle = NSBackgroundStyleDark;
}

//------------------------------------------------------------------------------
- (void) setTitle:(NSString *)title
{
    static NSUInteger const MaxTitleLength = 150;
    
    if ( [title length] > MaxTitleLength ) {
        [super setTitle:[NSString stringWithFormat:@"%@ ...", [title substringToIndex:MaxTitleLength]]];
    }
    else {
        [super setTitle:title];
    }
}

@end
