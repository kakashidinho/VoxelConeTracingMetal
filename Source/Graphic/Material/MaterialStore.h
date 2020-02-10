#pragma once

#include <vector>

#include <Metal/Metal.h>

class Material;

/// <summary> Manages all loaded materials and shader programs. </summary>
class MaterialStore {
public:
	static MaterialStore& getInstance();
	std::vector<Material*> materials;
	Material * findMaterialWithName(std::string name);
	void AddNewMaterial(const std::string &name,
						const std::string &shaderFile,
						MTLPixelFormat colorFormat,
						MTLPixelFormat depthFormat,
						MTLPixelFormat stencilFormat,
						uint32_t samples = 1,
						uint32_t rasterSamples = 1,
						bool blending = true,
						bool enableColorWrite = false
						);
	~MaterialStore();
private:
	MaterialStore();
	MaterialStore(MaterialStore const &) = delete;
	void operator=(MaterialStore const &) = delete;
};
