//
//  HeaderImage.m
//  Insek
//
//  Created by Kevin Filteau on 2010-09-29.
//  Copyright 2010 Kevin Filteau. All rights reserved.
//

#import "BannerView.h"


@implementation BannerView

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 1) {

		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://playwithmyled.com/insek/"]];
		
		/*NSURL *url = [NSURL URLWithString:@"http://playwithmyled.com/insek/"];
		[[NSWorkspace sharedWorkspace] openURL: url];   */
	}
}
- (void) resetCursorRects
{
    [super resetCursorRects];
    [self addCursorRect: [self bounds] cursor: [NSCursor
												pointingHandCursor]];
	
}

@end
