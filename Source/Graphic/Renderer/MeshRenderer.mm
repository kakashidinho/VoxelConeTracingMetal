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

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
constexpr MTLResourceOptions kBufferStorageMode = MTLResourceStorageModeManaged;
#else
constexpr MTLResourceOptions kBufferStorageMode = MTLResourceStorageModeShared;
#endif

struct ObjectStateUniformData
{
	glm::mat4 model;
	glm::mat4 modelInverseTranspose;
	MaterialSetting material;
};

MeshRenderer::MeshRenderer(Mesh * _mesh, MaterialSetting * _materialSetting) : materialSetting(_materialSetting)
{
	assert(_mesh != nullptr);

	mesh = _mesh;

	setupMeshRenderer();
}

void MeshRenderer::setupMeshRenderer()
{
	if (mesh->meshUploaded) { return; }

	// Upload to GPU.
	reuploadIndexDataToGPU();
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

	// We read the index buffer inside vertex shader directly instead of using drawIndexedPrimitive
	[encoder drawPrimitives:MTLPrimitiveTypeTriangle
				vertexStart:0
				vertexCount:mesh->indices.size()];
}

void MeshRenderer::reuploadIndexDataToGPU()
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();

	mesh->ebo = [metalDevice newBufferWithBytes:mesh->indices.data()
										 length:(mesh->indices.size() * sizeof(unsigned int))
										options:kBufferStorageMode];
}

void MeshRenderer::reuploadVertexDataToGPU()
{
	id<MTLDevice> metalDevice = Application::getInstance().graphics.getMetalDevice();
	auto dataSize = sizeof(VertexData);
	mesh->vbo = [metalDevice newBufferWithBytes:mesh->vertexData.data()
										 length:(mesh->vertexData.size() * dataSize)
										options:kBufferStorageMode];
}
