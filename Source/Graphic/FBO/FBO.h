#pragma once

#include <vector>
#include <Metal/Metal.h>

/// <summary> An FBO represents a render pass </summary>
class FBO {
public:
	FBO(uint32_t width, uint32_t height,
		MTLPixelFormat colorFormat,
		MTLPixelFormat depthFormat = MTLPixelFormatInvalid,
		bool cube = false,
		uint32_t samples = 1);
	~FBO();
	void activateAsTexture(id<MTLRenderCommandEncoder> encoder, uint32_t textureUnit = 0);
	id<MTLRenderCommandEncoder> beginRenderPass(id<MTLCommandBuffer> commandBuffer,
												MTLLoadAction load = MTLLoadActionClear,
												bool keepColor = true,
												bool keepDepth = false,
												uint32_t layersToRender = 1 // Number of cube's layers to be rendered in this pass
	);

	const uint32_t width, height;
private:
	void initTextures(MTLPixelFormat colorFormat,
					  MTLPixelFormat depthFormat,
					  bool cube,
					  uint32_t samples);
	void initRenderPass();

	id<MTLTexture> textureColorObject = nil;
	id<MTLTexture> textureDepthObject = nil;

	id<MTLTexture> resolveTextureColorObject = nil;
	id<MTLTexture> resolveTextureDepthObject = nil;

	MTLRenderPassDescriptor *renderPassDesc = nil;
};
