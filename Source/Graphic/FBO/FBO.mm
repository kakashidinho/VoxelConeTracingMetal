#include "FBO.h"
#include "../../Application.h"

#include <iostream>

FBO::FBO(uint32_t w, uint32_t h,
		 MTLPixelFormat colorFormat,
		 MTLPixelFormat depthFormat,
		 bool cube,
		 uint32_t samples)
	: width(w), height(h)
{
	initTextures(colorFormat, depthFormat, cube, samples);
	initRenderPass();
}

void FBO::initTextures(MTLPixelFormat colorFormat,
					   MTLPixelFormat depthFormat,
					   bool cube,
					   uint32_t samples)
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();

	// Init color texture.
	MTLTextureDescriptor *texDesc = [[MTLTextureDescriptor alloc] init];
	texDesc.width = width;
	texDesc.height = height;
	texDesc.storageMode = MTLStorageModePrivate;
	texDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
	if (cube)
	{
		texDesc.height = texDesc.width;
		if (samples > 1)
		{
			NSLog(@"Metal doesn't support multisample cube texture");
			abort();
		}
		texDesc.textureType = MTLTextureTypeCube;
	}
	else
	{
		texDesc.textureType = (samples > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
	}

	texDesc.sampleCount = samples;
	texDesc.pixelFormat = colorFormat;

	textureColorObject = [metalDevice newTextureWithDescriptor:texDesc];

	// Generate MSAA resolve texture
	if (samples > 1)
	{
		texDesc.sampleCount = 1;
		texDesc.textureType = MTLTextureType2D;
		resolveTextureColorObject = [metalDevice newTextureWithDescriptor:texDesc];
	}

	// Generate depth texture
	if (depthFormat != MTLPixelFormatInvalid)
	{
		texDesc.sampleCount = samples;
		texDesc.pixelFormat = depthFormat;
		texDesc.textureType = textureColorObject.textureType;

		textureDepthObject = [metalDevice newTextureWithDescriptor:texDesc];

		// Generate MSAA resolve texture for depth buffer
		if (samples > 1)
		{
			texDesc.sampleCount = 1;
			texDesc.textureType = MTLTextureType2D;
			resolveTextureDepthObject = [metalDevice newTextureWithDescriptor:texDesc];
		}
	}
}

void FBO::initRenderPass()
{
	renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
	renderPassDesc.colorAttachments[0].texture = textureColorObject;
	renderPassDesc.depthAttachment.clearDepth = 1;
	renderPassDesc.depthAttachment.texture = textureDepthObject;
}

void FBO::activateAsTexture(id<MTLRenderCommandEncoder> encoder, uint32_t textureUnit)
{
	auto texture = resolveTextureColorObject ? resolveTextureColorObject : textureColorObject;
	[encoder setVertexTexture:texture atIndex:textureUnit];
	[encoder setFragmentTexture:texture atIndex:textureUnit];
}

id<MTLRenderCommandEncoder> FBO::beginRenderPass(id<MTLCommandBuffer> commandBuffer,
												 MTLLoadAction load,
												 bool keepColor, bool keepDepth,
												 uint32_t layersToRender)
{
	// Setup load & store actions
	renderPassDesc.renderTargetArrayLength = layersToRender;
	renderPassDesc.colorAttachments[0].loadAction = load;
	renderPassDesc.depthAttachment.loadAction = textureDepthObject ? load : MTLLoadActionDontCare;

	if (keepColor)
	{
		if (resolveTextureColorObject)
		{
			renderPassDesc.colorAttachments[0].resolveTexture = resolveTextureColorObject;
			renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStoreAndMultisampleResolve;
		}
		else
		{
			renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
		}
	}
	else
	{
		renderPassDesc.colorAttachments[0].resolveTexture = nil;
		renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionDontCare;
	}

	if (keepDepth && textureDepthObject)
	{
		if (resolveTextureDepthObject)
		{
			renderPassDesc.depthAttachment.resolveTexture = resolveTextureDepthObject;
			renderPassDesc.depthAttachment.storeAction = MTLStoreActionStoreAndMultisampleResolve;
		}
		else
		{
			renderPassDesc.depthAttachment.storeAction = MTLStoreActionStore;
		}
	}
	else
	{
		renderPassDesc.depthAttachment.resolveTexture = nil;
		renderPassDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
	}

	// Create render command encoder
	return [commandBuffer renderCommandEncoderWithDescriptor:renderPassDesc];
}

FBO::~FBO()
{
}
