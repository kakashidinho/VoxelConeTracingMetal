#pragma once

#include <string>

#include <Metal/Metal.h>

/// <summary> Represents a shader program. </summary>
class Shader {
public:
	static id<MTLLibrary> loadMetalLibrary(id<MTLDevice> metalDevice, const std::string &file);
	static id<MTLFunction> loadShader(id<MTLLibrary> library, MTLFunctionConstantValues *shaderConstants, const std::string &entryName);
};
