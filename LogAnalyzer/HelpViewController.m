//
//  HelpViewController.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 31.03.15.
//  Copyright (c) 2015 Vladimír Nevyhoštěný. All rights reserved.
//

#import "HelpWebView.h"
#import "HelpViewController.h"
#import "HelpWindowController.h"


@interface HelpViewController ()
@property (weak) IBOutlet HelpWebView *helpView;
@end

@implementation HelpViewController

//------------------------------------------------------------------------------
- (void) viewDidLoad
{
    [super viewDidLoad];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"index"
                                                         ofType:@"html"
                                                    inDirectory:@"LogAnalyzerHelp"];
    [[self.helpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:filePath]]];
    [self.helpView setPolicyDelegate:self];
}

//------------------------------------------------------------------------------
- (void)                webView:(WebView *)webView
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
                        request:(NSURLRequest *)request
                          frame:(WebFrame *)frame
               decisionListener:(id < WebPolicyDecisionListener >)listener
{
    NSString *host = [[request URL] host];
    if ( [host length] ) {
        // Open external links in the default system browser ...
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    }
    else {
        [listener use];
    }
}


@end
