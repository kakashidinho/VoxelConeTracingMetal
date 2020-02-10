#import "ComputePipelineCache.h"
#import "Graphics.h"

#include "Material/Shader.h"

id<MTLLibrary> ComputePipelineCache::getLibrary(const std::string &file)
{
	auto ite = libraryCache.find(file);
	if (ite != libraryCache.end())
	{
		return ite->second;
	}

	id<MTLDevice> metalDevice = context.getMetalDevice();
	auto library = Shader::loadMetalLibrary(metalDevice, file);
	libraryCache[file] = library;
	return library;
}

id<MTLComputePipelineState> ComputePipelineCache::getComputeShader(const std::string &label,
																   id<MTLLibrary> library,
																   const std::string &entryName)
{
	auto ite = computeShaderCache.find(label);
	if (ite != computeShaderCache.end())
	{
		return ite->second;
	}
	auto shader = [library newFunctionWithName:[NSString stringWithUTF8String:entryName.c_str()]];

	NSError *err = nil;
	auto pipeline = [context.getMetalDevice() newComputePipelineStateWithFunction:shader error:&err];
	if (!pipeline && err)
	{
		NSLog(@"Compute pipeline compiled failed error=%@", [err localizedDescription]);
		abort();
	}

	computeShaderCache[label] = pipeline;

	return pipeline;
}
