//
//  LogItemViewController.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 08.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LogItem.h"
#import "Protocols.h"

@interface LogItemViewController : NSViewController <NSTextViewDelegate>
@property (unsafe_unretained) IBOutlet NSTextView          *textView;
@property (nonatomic, weak) LogItem                        *logItem;
@property (nonatomic, weak) id<MainViewControllerDelegate>  mainViewDelegate;
@end
