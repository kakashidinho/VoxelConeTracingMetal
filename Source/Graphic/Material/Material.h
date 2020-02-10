#pragma once

#include <string>
#include <vector>
#include <memory>
#include <unordered_map>

#include <Metal/Metal.h>

/// <summary> Represents a material that references shaders, blending settings, etc. </summary>
class Material {
public:
	~Material();
	Material(const std::string & _name,
			 const std::string & shaderFile,
			 MTLPixelFormat colorFormat,
			 MTLPixelFormat depthFormat,
			 MTLPixelFormat stencilFormat,
			 uint32_t samples = 1,
			 uint32_t rasterSamples = 1,
			 bool blending = true,
			 bool enableColorWrite = false
			 );
	/// <summary> Apply this material to the render command
	void activate(id<MTLRenderCommandEncoder> encoder);

	MTLRenderPipelineDescriptor *getRenderPipelineDesc() const { return renderPipelineDesc; }

	/// <summary> A name. Just an identifier. Doesn't do anything practical. </summary>
	const std::string name;

private:
	/// <summary> The Metal render pipeline state. </summary>
	id<MTLRenderPipelineState> renderPipelineState;

	MTLRenderPipelineDescriptor *renderPipelineDesc;
};
