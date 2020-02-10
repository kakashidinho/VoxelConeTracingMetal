#pragma once

#include <string>
#include <unordered_map>
#include <Metal/Metal.h>

class Graphics;

class ComputePipelineCache
{
public:
	ComputePipelineCache(Graphics &ctx) : context(ctx) {}
	id<MTLLibrary> getLibrary(const std::string &file);
	id<MTLComputePipelineState> getComputeShader(const std::string &label, id<MTLLibrary> library, const std::string &entryName);
private:
	Graphics &context;

	std::unordered_map<std::string, id<MTLLibrary>> libraryCache;
	std::unordered_map<std::string, id<MTLComputePipelineState>> computeShaderCache;
};
