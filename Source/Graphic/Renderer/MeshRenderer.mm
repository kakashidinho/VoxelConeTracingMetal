#include "MeshRenderer.h"

#include "../../Application.h"
#include "../../Shape/Mesh.h"
#include "../Material/Material.h"
#include "../../Scene/Scene.h"
#include "../../Graphic/Camera/Camera.h"
#include "../../Time/Time.h"
#include "../../Graphic/Graphics.h"
#include "../../Graphic/Lighting/PointLight.h"

#include <TargetConditionals.h>
#include <cassert>

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
constexpr MTLResourceOptions kDefaultBufferStorageMode = MTLResourceStorageModeManaged;
#else
constexpr MTLResourceOptions kDefaultBufferStorageMode = MTLResourceStorageModeShared;
#endif

struct ObjectStateUniformData
{
	glm::mat4 model;
	glm::mat4 modelInverseTranspose;
	MaterialSetting material;
};

MeshRenderer::MeshRenderer(Mesh * _mesh, MaterialSetting * _materialSetting)
	: materialSetting(_materialSetting)
{
	assert(_mesh != nullptr);

	mesh = _mesh;

	// Dominant axis buffer will be needed for multipass voxelization
	setupMeshRenderer(!Graphics::VOXEL_SINGLE_PASS);
}

void MeshRenderer::setupMeshRenderer(bool initDominantAxisBuffer)
{
	if (initDominantAxisBuffer)
		initComputeShader();

	if (mesh->meshUploaded) { return; }

	// Upload to GPU.
	reuploadIndexDataToGPU(initDominantAxisBuffer);
	reuploadVertexDataToGPU();

	mesh->meshUploaded = true;
}

MeshRenderer::~MeshRenderer()
{
	if (materialSetting != nullptr) delete materialSetting;
}

void MeshRenderer::render(id<MTLRenderCommandEncoder> encoder)
{
	ObjectStateUniformData uniformData;
	uniformData.model = transform.getTransformMatrix();
	uniformData.modelInverseTranspose = transform.getInverseTransposeTransformMatrix();
	if (materialSetting)
		uniformData.material = *materialSetting;

	[encoder setVertexBytes:&uniformData
					 length:sizeof(uniformData)
					atIndex:Graphics::OBJECT_STATE_BINDING];

	[encoder setFragmentBytes:&uniformData
					   length:sizeof(uniformData)
					  atIndex:Graphics::OBJECT_STATE_BINDING];

	[encoder setVertexBuffer:mesh->vbo
					  offset:0
					 atIndex:Graphics::VERTEX_BUFFER_BINDING];

	[encoder setVertexBuffer:mesh->ebo
					  offset:0
					 atIndex:Graphics::INDEX_BUFFER_BINDING];

	if (mesh->triDominantAxisBuffer)
	{
		// Triangle's dominant axis buffer, useful for multipass voxelization
		[encoder setVertexBuffer:mesh->triDominantAxisBuffer
						  offset:0
						 atIndex:Graphics::TRI_DOMINANT_BUFFER_BINDING];
	}

	// We read the index buffer inside vertex shader directly instead of using drawIndexedPrimitive
	[encoder drawPrimitives:MTLPrimitiveTypeTriangle
				vertexStart:0
				vertexCount:mesh->indices.size()];
}

void MeshRenderer::computeDominantAxis(id<MTLComputeCommandEncoder> encoder)
{
	// Generate dominant axis list for triangles inside mesh
	assert(dominantAxisCompute);

	ObjectStateUniformData uniformData;
	uniformData.model = transform.getTransformMatrix();
	uniformData.modelInverseTranspose = transform.getInverseTransposeTransformMatrix();
	if (materialSetting)
		uniformData.material = *materialSetting;

	uint32_t triangles = (uint32_t)(mesh->indices.size() / 3);
	[encoder setComputePipelineState:dominantAxisCompute];
	[encoder setBytes:&triangles
			   length:sizeof(triangles)
			  atIndex:Graphics::COMPUTE_PARAM_START_IDX];

	[encoder setBytes:&uniformData
			   length:sizeof(uniformData)
			  atIndex:Graphics::OBJECT_STATE_BINDING];

	[encoder setBuffer:mesh->vbo
				offset:0
			   atIndex:Graphics::VERTEX_BUFFER_BINDING];

	[encoder setBuffer:mesh->ebo
				offset:0
			   atIndex:Graphics::INDEX_BUFFER_BINDING];

	[encoder setBuffer:mesh->triDominantAxisBuffer
				offset:0
			   atIndex:Graphics::TRI_DOMINANT_BUFFER_BINDING];

	auto warpSize = dominantAxisCompute.threadExecutionWidth;
	NSUInteger threadGroupSize = warpSize;
	auto threadGroups = (triangles + threadGroupSize - 1) / threadGroupSize;

	[encoder dispatchThreadgroups:MTLSizeMake(threadGroups, 1, 1) threadsPerThreadgroup:MTLSizeMake(threadGroupSize, 1, 1)];
}

void MeshRenderer::reuploadIndexDataToGPU(bool initDominantAxisBuffer)
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();

	mesh->ebo = [metalDevice newBufferWithBytes:mesh->indices.data()
										 length:(mesh->indices.size() * sizeof(unsigned int))
										options:kDefaultBufferStorageMode];

	if (initDominantAxisBuffer)
		mesh->triDominantAxisBuffer = [metalDevice newBufferWithLength:mesh->indices.size() / 3 options:MTLResourceStorageModePrivate];
}

void MeshRenderer::reuploadVertexDataToGPU()
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();
	auto dataSize = sizeof(VertexData);
	mesh->vbo = [metalDevice newBufferWithBytes:mesh->vertexData.data()
										 length:(mesh->vertexData.size() * dataSize)
										options:kDefaultBufferStorageMode];
}


void MeshRenderer::initComputeShader()
{
	auto &graphics = Application::getInstance().graphics;
	auto library = graphics.getComputeCache().getLibrary("Shaders/Voxelization/voxel_compute_kernels");

	dominantAxisCompute = graphics.getComputeCache().getComputeShader("voxel_tri_dominant_axis", library, "computeTriangleDominantAxis");
}
