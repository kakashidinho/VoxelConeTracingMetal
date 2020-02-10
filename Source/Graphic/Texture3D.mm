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
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();
	auto library = Shader::loadMetalLibrary(metalDevice, "Shaders/Voxelization/voxel_compute_kernels");
	auto shader = [library newFunctionWithName:@"clear"];

	NSError *err = nil;
	clearPipelineState = [metalDevice newComputePipelineStateWithFunction:shader error:&err];
	if (!clearPipelineState && err)
	{
		NSLog(@"Compute pipeline compiled failed error=%@", [err localizedDescription]);
		abort();
	}
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

void Texture3D::clear(id<MTLComputeCommandEncoder> computeEncoder, float clearColor[4])
{
	[computeEncoder setComputePipelineState:clearPipelineState];
	[computeEncoder setBytes:clearColor length:4 * sizeof(float) atIndex:0];

	for (auto levelView : textureObjectViews)
	{
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
