//
//  GameViewController.m
//  VoxelConeTracingMetal
//
//  Created by Le Quyen on 9/2/20.
//  Copyright © 2020 HQgame. All rights reserved.
//

#import "GameViewController.h"
#import "GameView.h"
#import "Renderer.h"

#include "../Application.h"

@implementation GameViewController
{
	GameView *_view;

	Renderer *_renderer;

	NSPoint _lastMousePoint;
	BOOL _lastMousePointValid;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	_view = (GameView *)self.view;

	_view.controller = self;

#if 0
	// Try to use integrated GPU
	auto devices = MTLCopyAllDevices();
	_view.device = devices[0];
	for (id<MTLDevice> device in devices)
	{
		// favor low power
		if (device.lowPower)
		{
			_view.device = device;
		}
	}
#else
	_view.device = MTLCreateSystemDefaultDevice();
#endif

	if(!_view.device)
	{
		NSLog(@"Metal is not supported on this device");
		self.view = [[NSView alloc] initWithFrame:self.view.frame];
		return;
	}

	_renderer = [[Renderer alloc] initWithMetalKitView:_view];

	[_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];

	_view.delegate = _renderer;
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	self.view.window.acceptsMouseMovedEvents = YES;
	_lastMousePointValid = NO;

	CGWarpMouseCursorPosition(self.view.window.frame.origin);
}

- (void)viewDidDisappear
{
}

- (void)mouseMoved:(NSEvent *)nsEvent
{
	if (!_lastMousePointValid)
	{
		_lastMousePointValid = YES;
	}
	else
	{
		float deltaX = _lastMousePoint.x - nsEvent.locationInWindow.x;
		float deltaY = nsEvent.locationInWindow.y - _lastMousePoint.y;
		Application::getInstance().onMouseMoved(deltaX, deltaY);
	}

	_lastMousePoint = [nsEvent locationInWindow];
}

- (void)keyDown:(NSEvent *)nsEvent {
	if (nsEvent.isARepeat || !nsEvent.characters.UTF8String)
		return;
	const char *characters = nsEvent.characters.UTF8String;
	size_t len = strlen(characters);
	for (size_t i = 0; i < len; ++i)
		Application::getInstance().onKeyDown(characters[i]);
}

- (void)keyUp:(NSEvent *)nsEvent {
	if (nsEvent.isARepeat || !nsEvent.characters.UTF8String)
		return;

	const char *characters = nsEvent.characters.UTF8String;
	size_t len = strlen(characters);
	for (size_t i = 0; i < len; ++i)
		Application::getInstance().onKeyUp(characters[i]);
}

@end
