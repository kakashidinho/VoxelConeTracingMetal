#pragma once

#include <vector>

#include <Metal/Metal.h>

/// <summary> A 3D texture wrapper class. This texture is used for shader writing, not for rendering.</summary>
class Texture3D {
public:

	/// <summary> Activates this texture and passes it on to a texture unit on the GPU. </summary>
	void activate(id<MTLRenderCommandEncoder> encoder, uint32_t textureUnit = 0);

	/// <summary> Clears this texture using a given clear color. </summary>
	void clear(id<MTLComputeCommandEncoder> computeEncoder, float clearColor[4]);

	/// <summary> Generate mipmaps
	void generateMips(id<MTLBlitCommandEncoder> encoder);
	void generateMips(id<MTLComputeCommandEncoder> encoder);

	Texture3D(const uint32_t width, const uint32_t height, const uint32_t depth);
private:
	void initTexture();
	void initComputeShader();
	void dispatchCompute(id<MTLComputeCommandEncoder> computeEncoder,
						 NSUInteger warpSize,
						 const MTLSize &dimensions);

	uint32_t width, height, depth;

	id<MTLTexture> textureObject;
	std::vector<id<MTLTexture>> textureObjectViews;

	id<MTLComputePipelineState> clearPipelineState;
};
