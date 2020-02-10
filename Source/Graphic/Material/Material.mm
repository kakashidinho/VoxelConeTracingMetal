#include "Material.h"
#include "Shader.h"

#include "../../Application.h"

#include <iostream>
#include <fstream>
#include <vector>

#include <gtc/type_ptr.hpp>

Material::~Material()
{
}

Material::Material(const std::string & _name,
				   const std::string & shaderFile,
				   MTLPixelFormat colorFormat,
				   MTLPixelFormat depthFormat,
				   MTLPixelFormat stencilFormat,
				   uint32_t samples,
				   uint32_t rasterSamples,
				   bool blending,
				   bool disableColorWrite)
	: name(_name)
{
	// Setup descriptor
	auto desc = renderPipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
	desc.colorAttachments[0].pixelFormat = colorFormat;
	desc.depthAttachmentPixelFormat = depthFormat;
	desc.stencilAttachmentPixelFormat = stencilFormat;
	if (blending)
	{
		desc.colorAttachments[0].blendingEnabled = blending;
		desc.colorAttachments[0].sourceAlphaBlendFactor = desc.colorAttachments[0].sourceRGBBlendFactor
			= MTLBlendFactorSourceAlpha;
		desc.colorAttachments[0].destinationAlphaBlendFactor = desc.colorAttachments[0].destinationRGBBlendFactor
		= MTLBlendFactorOneMinusSourceAlpha;
	}
	if (disableColorWrite)
	{
		desc.colorAttachments[0].writeMask = MTLColorWriteMaskNone;
	}

	desc.rasterSampleCount = rasterSamples;
	desc.sampleCount = samples;
	desc.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
	desc.label = [NSString stringWithUTF8String:_name.c_str()];

	// Verify that we can read and write texture in shader at the same time
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();
	BOOL readWriteTextureSupported = metalDevice.readWriteTextureSupport == MTLReadWriteTextureTier2;
	MTLFunctionConstantValues *shaderConstants = [[MTLFunctionConstantValues alloc] init];
	[shaderConstants setConstantValue:&readWriteTextureSupported type:MTLDataTypeBool atIndex:0];

	// Load shaders
	auto library = Shader::loadMetalLibrary(metalDevice, shaderFile);
	desc.vertexFunction = Shader::loadShader(library, shaderConstants, "VS");
	desc.fragmentFunction = Shader::loadShader(library, shaderConstants, "FS");

	// Create pipeline state
	NSError *err = nil;
	renderPipelineState = [metalDevice newRenderPipelineStateWithDescriptor:desc
																	  error:&err];
	if (!renderPipelineState && err)
	{
		NSLog(@"Render pipeline compilation error=%@", [err localizedDescription]);
		abort();
	}
}

void Material::activate(id<MTLRenderCommandEncoder> encoder)
{
	[encoder setRenderPipelineState:renderPipelineState];
}
