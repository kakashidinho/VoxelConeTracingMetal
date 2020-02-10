//
//  Renderer.m
//  VoxelConeTracingMetal
//
//  Created by Le Quyen on 9/2/20.
//  Copyright © 2020 HQgame. All rights reserved.
//

#import "Renderer.h"
#import "GameView.h"
#include "../Application.h"
#include "../Time/Time.h"

@implementation Renderer
{
	id <MTLDevice> _device;
	id <MTLCommandQueue> _commandQueue;
	BOOL initedScene;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
	self = [super init];
	if(self)
	{
		_device = view.device;
		[self _loadMetalWithView:view];
	}

	return self;
}

- (void)_loadMetalWithView:(nonnull MTKView *)view;
{
	((GameView*)view).fpsCounter.stringValue = @"LOADING ...";

	/// Load Metal state objects and initalize renderer dependent view properties

	view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
	view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
	view.sampleCount = 1;

	_commandQueue = [_device newCommandQueue];
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
	/// Per frame updates here

	id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
	commandBuffer.label = @"MyCommand";

	/// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
	///   holding onto the drawable and blocking the display pipeline any longer than necessary
	MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

	if(renderPassDescriptor != nil) {
		if (!initedScene)
		{
			/// Init Rendering Application Logic
			Application::getInstance().init(_device,
											(uint32_t)view.currentDrawable.texture.width,
											(uint32_t)view.currentDrawable.texture.height);

			initedScene = YES;
		}
		Application::getInstance().iterate(commandBuffer,
										   renderPassDescriptor,
										   (uint32_t)view.currentDrawable.texture.width,
										   (uint32_t)view.currentDrawable.texture.height);

		[commandBuffer presentDrawable:view.currentDrawable];
	}

	[commandBuffer commit];

	((GameView*)view).fpsCounter.stringValue = [NSString stringWithFormat:@"FPS: %d", (int)Time::framesPerSecond];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

@end
