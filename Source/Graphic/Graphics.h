#pragma once

#include <vector>

#include <MetalKit/MetalKit.h>
#include <Metal/Metal.h>

#include "../Scene/Scene.h"
#include "Material/Material.h"
#include "Camera/OrthographicCamera.h"
#include "../Shape/Mesh.h"

#define MAX_LIGHTS 1

class MeshRenderer;
class Shape;
class Texture3D;
class FBO;

/// <summary> A graphical context used for rendering. </summary>
class Graphics {
	using RenderingQueue = std::vector<MeshRenderer*>;
public:
	enum RenderingMode {
		VOXELIZATION_VISUALIZATION = 0, // Voxelization visualization.
		VOXEL_CONE_TRACING = 1			// Global illumination using voxel cone tracing.
	};

	struct Settings
	{
		static_assert(sizeof(bool) == 1, "bool is expected to be 1 byte");
		bool indirectSpecularLight = true;
		bool indirectDiffuseLight = true;
		bool directLight = true;
		bool shadows = true;
	};

	/// Binding index for Uniform buffers
	static constexpr uint32_t OBJECT_STATE_BINDING = 0;
	static constexpr uint32_t APPSTATE_BINDING = 1;
	static constexpr uint32_t VOXEL_PROJ_BINDING = 2;
	static constexpr uint32_t VERTEX_BUFFER_BINDING = 8;
	static constexpr uint32_t INDEX_BUFFER_BINDING = 9;

	/// <summary> Initializes rendering. </summary>
	virtual void init(id<MTLDevice> _metalDevice, unsigned int viewportWidth, unsigned int viewportHeight); // Called pre-render once per run.

	/// <sumamry> Renders a scene using a given rendering mode. </summary>
	virtual void render(id<MTLCommandBuffer> commandBuffer,
						MTLRenderPassDescriptor *backbufferRenderPassDesc,
						Scene & renderingScene,
						unsigned int viewportWidth,
						unsigned int viewportHeight,
						RenderingMode renderingMode = RenderingMode::VOXEL_CONE_TRACING
	);

	id<MTLDevice> getMetalDevice() { return metalDevice; }
	// ----------------
	// Rendering.
	// ----------------
	Settings &settings() { return globalConstants; }

	// ----------------
	// Voxelization.
	// ----------------
	bool automaticallyRegenerateMipmap = true;
	bool regenerateMipmapQueued = true;
	bool automaticallyVoxelize = true;
	bool voxelizationQueued = true;
	int voxelizationSparsity = 1; // Number of ticks between mipmap generation.
	// (voxelization sparsity gives unstable framerates, so not sure if it's worth it in interactive applications.)

	~Graphics();
private:
	struct GlobalUniformData : public Settings
	{
		PointLight pointLights[MAX_LIGHTS];
		int numberOfLights;

		// camera transform matrix
		glm::mat4 V;
		glm::mat4 P;
		glm::vec3 cameraPosition;

		// Debug state
		int state;
	};

	// ----------------
	// Rendering.
	// ----------------
	void renderScene(id<MTLCommandBuffer> commandBuffer,
					 MTLRenderPassDescriptor *backbufferRenderPassDesc,
					 Scene & renderingScene,
					 unsigned int viewportWidth,
					 unsigned int viewportHeight);
	void renderQueue(id<MTLRenderCommandEncoder> encoder, const RenderingQueue &renderingQueue) const;
	void updateGlobalConstants(Scene & renderingScene);
	void uploadGlobalConstants(id<MTLRenderCommandEncoder> encoder) const;

	GlobalUniformData globalConstants;

	// ----------------
	// Metal resources
	// ----------------
	id<MTLDevice> metalDevice;
	id<MTLDepthStencilState> depthDisabledState;
	id<MTLDepthStencilState> depthEnabledState;
	void initMetalResources();

	// ----------------
	// Voxel cone tracing.
	// ----------------
	Material * voxelConeTracingMaterial;

	// ----------------
	// Voxelization.
	// ----------------
	int ticksSinceLastVoxelization = voxelizationSparsity;
	uint32_t voxelTextureSize = 64; // Must be set to a power of 2.
	OrthographicCamera voxelCamera;
	Material * voxelizationMaterial;
	Texture3D * voxelTexture = nullptr;
	void initVoxelization();
	void voxelize(id<MTLCommandBuffer> commandBuffer, Scene & renderingScene, bool clearVoxelizationFirst = true);

	// ----------------
	// Voxelization visualization.
	// ----------------
	void initVoxelVisualization(unsigned int viewportWidth, unsigned int viewportHeight);
	void renderVoxelVisualization(id<MTLCommandBuffer> commandBuffer,
								  MTLRenderPassDescriptor *backbufferRenderPassDesc,
								  Scene & renderingScene,
								  unsigned int viewportWidth, unsigned int viewportHeight);
	FBO *vvfbo1, *vvfbo2;
	FBO *dummyVoxelizationFbo;
	Material * worldPositionMaterial, *voxelVisualizationMaterial;
	// --- Screen quad. ---
	MeshRenderer * quadMeshRenderer;
	Mesh quad;
	// --- Screen cube. ---
	MeshRenderer * cubeMeshRenderer;
	Shape * cubeShape;
};
