//
//  GameView.m
//  VoxelConeTracingMetal
//
//  Created by Le Quyen on 10/2/20.
//  Copyright © 2020 HQgame. All rights reserved.
//

#import "GameView.h"

@implementation GameView

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)mouseMoved:(NSEvent *)nsEvent
{
	[_controller mouseMoved:nsEvent];
}

- (void)keyDown:(NSEvent *)nsEvent {
	[_controller keyDown:nsEvent];
}

- (void)keyUp:(NSEvent *)nsEvent {
	[_controller keyUp:nsEvent];
}

@end
