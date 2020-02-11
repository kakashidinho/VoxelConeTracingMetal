#include "Texture3D.h"
#include "Material/Shader.h"
#include "../Application.h"

#include <vector>
#include <cmath>

Texture3D::Texture3D(const uint32_t _width,
					 const uint32_t _height,
					 const uint32_t _depth) :
	width(_width), height(_height), depth(_depth)
{
	initTexture();
	initComputeShader();
}

void Texture3D::initTexture()
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();

	// Generate texture on GPU.
	auto texDesc = [[MTLTextureDescriptor alloc] init];
	texDesc.textureType = MTLTextureType3D;
	texDesc.pixelFormat = MTLPixelFormatRGBA8Unorm;
	texDesc.width = width;
	texDesc.height = height;
	texDesc.depth = depth;
	// Only support up to 7 mipmap levels
	texDesc.mipmapLevelCount = 1 + std::max((uint32_t)log2(width), (uint32_t)log2(height));
	texDesc.mipmapLevelCount = std::min<NSUInteger>(7, texDesc.mipmapLevelCount);
	texDesc.storageMode = MTLStorageModePrivate;
	texDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsagePixelFormatView;

	textureObject = [metalDevice newTextureWithDescriptor:texDesc];

	// Create mip level views
	textureObjectViews.resize(textureObject.mipmapLevelCount);
	for (int i = 0; i < textureObject.mipmapLevelCount; ++i)
	{
		auto texView = [textureObject newTextureViewWithPixelFormat:texDesc.pixelFormat
														textureType:texDesc.textureType
															 levels:NSMakeRange(i, 1)
															 slices:NSMakeRange(0, 1)];
		textureObjectViews[i] = texView;
	}
}

void Texture3D::initComputeShader()
{
	auto &graphics = Application::getInstance().graphics;
	auto library = graphics.getComputeCache().getLibrary("Shaders/Voxelization/voxel_compute_kernels");

	clearPipelineState = graphics.getComputeCache().getComputeShader("voxel_clear", library, "clear");
	copyBufferPipelineState = graphics.getComputeCache().getComputeShader("voxel_copyFromBuffer", library, "copyRgba8Buffer");
}

void Texture3D::activate(id<MTLRenderCommandEncoder> encoder, uint32_t textureUnit)
{
	[encoder setVertexTexture:textureObject atIndex:textureUnit];
	[encoder setFragmentTexture:textureObject atIndex:textureUnit];
}

void Texture3D::dispatchCompute(id<MTLComputeCommandEncoder> computeEncoder,
								NSUInteger warpSize,
								const MTLSize &dimensions)
{
	MTLSize threadsPerThreadgroup = MTLSizeMake(1, 1, 1);
	if (warpSize > dimensions.width)
	{
		threadsPerThreadgroup.width = dimensions.width;
		threadsPerThreadgroup.height = warpSize / dimensions.width;
	}
	else
	{
		threadsPerThreadgroup.width = warpSize;
		threadsPerThreadgroup.height = clearPipelineState.maxTotalThreadsPerThreadgroup / warpSize;
	}
	threadsPerThreadgroup.height = std::min(threadsPerThreadgroup.height, dimensions.height);

	threadsPerThreadgroup.depth = clearPipelineState.maxTotalThreadsPerThreadgroup /
								  (threadsPerThreadgroup.width * threadsPerThreadgroup.height);

	threadsPerThreadgroup.depth = std::min(threadsPerThreadgroup.depth, dimensions.depth);

	MTLSize groups = MTLSizeMake((dimensions.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
								 (dimensions.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
								 (dimensions.depth + threadsPerThreadgroup.depth - 1) / threadsPerThreadgroup.depth);

	[computeEncoder dispatchThreadgroups:groups threadsPerThreadgroup:threadsPerThreadgroup];
}

void Texture3D::clear(id<MTLComputeCommandEncoder> computeEncoder, float clearColor[4], uint32_t startLevel)
{
	[computeEncoder setComputePipelineState:clearPipelineState];
	[computeEncoder setBytes:clearColor length:4 * sizeof(float) atIndex:Graphics::COMPUTE_PARAM_START_IDX];

	for (uint32_t i = startLevel; i < textureObjectViews.size(); ++i)
	{
		auto levelView = textureObjectViews[i];
		[computeEncoder setTexture:levelView atIndex:0];
		dispatchCompute(computeEncoder,
						clearPipelineState.threadExecutionWidth,
						MTLSizeMake(levelView.width, levelView.height, levelView.depth));
	}
}


void Texture3D::generateMips(id<MTLBlitCommandEncoder> encoder)
{
	[encoder generateMipmapsForTexture:textureObject];
}

void Texture3D::generateMips(id<MTLComputeCommandEncoder> encoder)
{
	// TODO: compute shader verstion
	abort();
}

void Texture3D::copyFirstLevelFromBuffer(id<MTLComputeCommandEncoder> encoder, id<MTLBuffer> buffer)
{
	[encoder setComputePipelineState:copyBufferPipelineState];
	[encoder setTexture:textureObject atIndex:0];
	[encoder setBuffer:buffer offset:0 atIndex:0];

	dispatchCompute(encoder, copyBufferPipelineState.threadExecutionWidth, MTLSizeMake(width, height, depth));
}
