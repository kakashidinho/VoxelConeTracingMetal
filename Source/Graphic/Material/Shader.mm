#include "Shader.h"
#include "../../Utility/System.h"

#include <TargetConditionals.h>

id<MTLLibrary> Shader::loadMetalLibrary(id<MTLDevice> metalDevice, const std::string &oriFile)
{
	auto file = oriFile;
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
	file += ".osx.metallib";
#else
	// TODO: support more platforms
#   error "Unsupported platform"
#endif
	NSString *filePath = [NSString stringWithUTF8String:System::fullResourcePath(file).c_str()];

	NSError *err = nil;
	auto library = [metalDevice newLibraryWithFile:filePath error:&err];

	if (!library && err)
	{
		NSLog(@"Shader compile error=%@", [err localizedDescription]);
		abort();
	}
	return library;
}

id<MTLFunction> Shader::loadShader(id<MTLLibrary> library, MTLFunctionConstantValues *shaderConstants, const std::string &entryName)
{
	NSError *err = nil;
	auto shader = [library newFunctionWithName:[NSString stringWithUTF8String:entryName.c_str()]
								constantValues:shaderConstants
										 error:&err];
	if (!shader && err)
	{
		NSLog(@"Shader load error=%@", [err localizedDescription]);
		abort();
	}

	return shader;
}
