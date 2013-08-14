//
//  InfColorPickerButton.m
//  Pin Drop
//
//  Created by Giacomo Saccardo on 12/08/2013.
//  Copyright (c) 2013 Caffeinehit Ltd. All rights reserved.
//

#import "InfColorPickerButton.h"
#import <QuartzCore/QuartzCore.h>

@implementation InfColorPickerButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        self.layer.cornerRadius = 3;
        
        [self addTarget:self action:@selector(highlightBorder) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(unhighlightBorder) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(unhighlightBorder) forControlEvents:UIControlEventTouchDragOutside];
    }
    return self;
}

- (void)highlightBorder
{
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.5].CGColor;
}

- (void)unhighlightBorder
{
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
}

- (void)setEnabled:(BOOL)enabled {
    
    [super setEnabled:enabled];
    
    if (enabled) {
        self.titleLabel.alpha = 1.0;
    }
    else {
        self.titleLabel.alpha = 0.5;
    }
}

@end
