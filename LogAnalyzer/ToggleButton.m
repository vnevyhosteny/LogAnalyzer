//
//  ToggleButton.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 21.12.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

#import "ToggleButton.h"

//==============================================================================
@interface ToggleButton()
{
    NSImageView *_toggleImageView;
    BOOL         _isToggled;
}
@end

//==============================================================================
@implementation ToggleButton

//------------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ( ( self = [super initWithCoder:coder] ) ) {
        
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) awakeFromNib
{
    CGSize size                  = self.frame.size;
    self->_toggleImageView       = [[NSImageView alloc] initWithFrame:CGRectMake( 0.0f, 0.0f, size.width, size.height)];
    self->_toggleImageView.image = [NSImage imageNamed:@"ButtonToggleUp"];
    [self addSubview:self->_toggleImageView];
    self->_isToggled             = NO;
}

//------------------------------------------------------------------------------
- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
}

//------------------------------------------------------------------------------
- (void) setEnabled:(BOOL)newValue
{
    CGFloat newAlpha = ( newValue ? 1.0f : 0.5f );
    [self->_toggleImageView setAlphaValue:newAlpha];
    [super setEnabled:newValue];
}

//------------------------------------------------------------------------------
- (void) toggleImage
{
    static CGFloat const LowAlpha     = 0.5f;
    static CGFloat const NormalAlpha  = 1.0f;
    static CGFloat const TimeInterval = 0.2f;
    
    [self->_toggleImageView setAlphaValue:LowAlpha];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TimeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isToggled             = !self->_isToggled;
        self->_toggleImageView.image = ( self->_isToggled ? [NSImage imageNamed:@"ButtonToggleDown"] : [NSImage imageNamed:@"ButtonToggleUp"] );
        [self->_toggleImageView setAlphaValue:LowAlpha];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TimeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_toggleImageView setAlphaValue:NormalAlpha];
        });
    });
}

@end
