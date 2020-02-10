#include "MaterialStore.h"

#include <iostream>

#include "Material.h"
#include "../../Application.h"

MaterialStore::MaterialStore()
{
	// Voxelization.
	AddNewMaterial("voxelization",
				   "Voxelization/voxelization",
				   MTLPixelFormatRGBA8Unorm,
				   MTLPixelFormatInvalid,
				   MTLPixelFormatInvalid,
				   8,
				   8, // enable MSAA for conservative rasterization
				   false,
				   true
				   );

	// Voxelization visualization.
	AddNewMaterial("voxel_visualization",
				   "Voxelization/Visualization/voxel_visualization",
				   MTLPixelFormatBGRA8Unorm,
				   MTLPixelFormatDepth32Float,
				   MTLPixelFormatInvalid,
				   Application::MSAA_SAMPLES,
				   Application::MSAA_SAMPLES);
	AddNewMaterial("world_position",
				   "Voxelization/Visualization/world_position",
				   MTLPixelFormatRGBA16Snorm,
				   MTLPixelFormatDepth32Float,
				   MTLPixelFormatInvalid
				   );

	// Cone tracing.
	AddNewMaterial("voxel_cone_tracing",
				   "VoxelConeTracing/voxel_cone_tracing",
				   MTLPixelFormatBGRA8Unorm,
				   MTLPixelFormatDepth32Float,
				   MTLPixelFormatInvalid,
				   Application::MSAA_SAMPLES,
				   Application::MSAA_SAMPLES);
}

void MaterialStore::AddNewMaterial(const std::string &name,
								   const std::string &shaderFile,
								   MTLPixelFormat colorFormat,
								   MTLPixelFormat depthFormat,
								   MTLPixelFormat stencilFormat,
								   uint32_t samples,
								   uint32_t rasterSamples,
								   bool blending,
								   bool enableColorWrite)
{
	const std::string shaderPath = "Shaders/";
	materials.push_back(new Material(name,
									 shaderPath + shaderFile,
									 colorFormat,
									 depthFormat,
									 stencilFormat,
									 samples,
									 rasterSamples,
									 blending,
									 enableColorWrite
									 ));
}

Material * MaterialStore::findMaterialWithName(std::string name)
{
	for (unsigned int i = 0; i < materials.size(); ++i) {
		if (materials[i]->name == name) {
			return materials[i];
		}
	}
	std::cerr << "Couldn't find material with name " << name << std::endl;
	return nullptr;
}

MaterialStore& MaterialStore::getInstance()
{
	static MaterialStore instance;
	return instance;
}

MaterialStore::~MaterialStore() {
	for (unsigned int i = 0; i < materials.size(); ++i)
	{
		delete materials[i];
	}
}
