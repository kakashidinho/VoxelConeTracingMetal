#include "Graphics.h"

// Stdlib.
#include <queue>
#include <algorithm>
#include <vector>

// External.
#include <glm.hpp>
#include <gtc/type_ptr.hpp>

// Internal.
#include "Texture3D.h"
#include "FBO/FBO.h"
#include "Material/Material.h"
#include "Camera/OrthographicCamera.h"
#include "Material/MaterialStore.h"
#include "../Application.h"
#include "../Time/Time.h"
#include "../Shape/Mesh.h"
#include "../Shape/StandardShapes.h"
#include "Renderer/MeshRenderer.h"
#include "../Utility/ObjLoader.h"
#include "../Shape/Shape.h"

namespace
{

MTLViewport viewport(uint32_t viewportWidth, uint32_t viewportHeight)
{
	MTLViewport viewport;
	viewport.width = viewportWidth;
	viewport.height = viewportHeight;
	viewport.originX = viewport.originY = 0;
	viewport.znear = 0;
	viewport.zfar = 1;

	return viewport;
}
}

// ----------------------
// Rendering pipeline.
// ----------------------
void Graphics::init(id<MTLDevice> _metalDevice, unsigned int viewportWidth, unsigned int viewportHeight)
{
	metalDevice = _metalDevice;

	BOOL macGpuFamily2 = NO;
#ifdef __MAC_10_14
	macGpuFamily2 = [metalDevice supportsFeatureSet:MTLFeatureSet_macOS_GPUFamily2_v1];
#endif
	if (!macGpuFamily2 &&
		!metalDevice.rasterOrderGroupsSupported)
	{
		NSLog(@"Voxel Cone Tracing requires Raster Order Group capability in GPU");
		abort();
	}

	initMetalResources();

	voxelConeTracingMaterial = MaterialStore::getInstance().findMaterialWithName("voxel_cone_tracing");
	voxelCamera = OrthographicCamera(viewportWidth / float(viewportHeight));
	initVoxelization();
	initVoxelVisualization(viewportWidth, viewportHeight);
}

void Graphics::initMetalResources()
{
	MTLDepthStencilDescriptor *dsDesc = [[MTLDepthStencilDescriptor alloc] init];
	depthDisabledState = [metalDevice newDepthStencilStateWithDescriptor:dsDesc];

	dsDesc.depthWriteEnabled = YES;
	dsDesc.depthCompareFunction = MTLCompareFunctionLess;
	depthEnabledState = [metalDevice newDepthStencilStateWithDescriptor:dsDesc];
}

void Graphics::render(id<MTLCommandBuffer> commandBuffer,
					  MTLRenderPassDescriptor *backbufferRenderPassDesc,
					  Scene & renderingScene,
					  unsigned int viewportWidth, unsigned int viewportHeight,
					  RenderingMode renderingMode)
{
	// Update global constants
	updateGlobalConstants(renderingScene);

	// Voxelize.
	bool voxelizeNow = voxelizationQueued || (automaticallyVoxelize && voxelizationSparsity > 0 && ++ticksSinceLastVoxelization >= voxelizationSparsity);
	if (voxelizeNow) {
		voxelize(commandBuffer, renderingScene, true);
		ticksSinceLastVoxelization = 0;
		voxelizationQueued = false;
	}

	// Render.
	backbufferRenderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
	backbufferRenderPassDesc.depthAttachment.clearDepth = 1;
	backbufferRenderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
	backbufferRenderPassDesc.depthAttachment.loadAction = MTLLoadActionClear;

	switch (renderingMode) {
	case RenderingMode::VOXELIZATION_VISUALIZATION:
		renderVoxelVisualization(commandBuffer, backbufferRenderPassDesc, renderingScene, viewportWidth, viewportHeight);
		break;
	case RenderingMode::VOXEL_CONE_TRACING:
		renderScene(commandBuffer, backbufferRenderPassDesc, renderingScene, viewportWidth, viewportHeight);
		break;
	}
}

// ----------------------
// Scene rendering.
// ----------------------
void Graphics::renderScene(id<MTLCommandBuffer> commandBuffer,
						   MTLRenderPassDescriptor *backbufferRenderPassDesc,
						   Scene & renderingScene,
						   unsigned int viewportWidth, unsigned int viewportHeight)
{
	// Start rendering encoding
	auto encoder = [commandBuffer renderCommandEncoderWithDescriptor:backbufferRenderPassDesc];

	// Fetch references.
	Material * material = voxelConeTracingMaterial;
	material->activate(encoder);

	// Graphics settings
	[encoder setViewport:viewport(viewportWidth, viewportHeight)];
	[encoder setDepthStencilState:depthEnabledState];
	[encoder setFrontFacingWinding:MTLWindingCounterClockwise];
	[encoder setCullMode:MTLCullModeBack];

	// Upload uniforms.
	uploadGlobalConstants(encoder);

	// Bind voxel texture
	voxelTexture->activate(encoder, 2);

	// Render.
	renderQueue(encoder, renderingScene.renderers);

	[encoder endEncoding];
}

void Graphics::updateGlobalConstants(Scene &renderingScene)
{
	// Debug state
	globalConstants.state = Application::getInstance().state;

	// Point lights.
	globalConstants.numberOfLights = std::min<int>(renderingScene.pointLights.size(), MAX_LIGHTS);
	for (unsigned int i = 0; i < globalConstants.numberOfLights; ++i) globalConstants.pointLights[i] = renderingScene.pointLights[i];

	// Camera
	auto & camera = *renderingScene.renderingCamera;
	globalConstants.V = camera.viewMatrix;
	globalConstants.P = camera.getProjectionMatrix();
	globalConstants.cameraPosition = camera.position;
}

void Graphics::uploadGlobalConstants(id<MTLRenderCommandEncoder> encoder) const
{
	[encoder setVertexBytes:&globalConstants length:sizeof(globalConstants) atIndex:APPSTATE_BINDING];
	[encoder setFragmentBytes:&globalConstants length:sizeof(globalConstants) atIndex:APPSTATE_BINDING];
}

void Graphics::renderQueue(id<MTLRenderCommandEncoder> encoder, const RenderingQueue &renderingQueue) const
{
	for (unsigned int i = 0; i < renderingQueue.size(); ++i) if (renderingQueue[i]->enabled)
		renderingQueue[i]->transform.updateTransformMatrix();

	for (unsigned int i = 0; i < renderingQueue.size(); ++i) if (renderingQueue[i]->enabled) {
		renderingQueue[i]->render(encoder);
	}
}

// ----------------------
// Voxelization.
// ----------------------
void Graphics::initVoxelization()
{
	voxelizationMaterial = MaterialStore::getInstance().findMaterialWithName("voxelization");

	assert(voxelizationMaterial != nullptr);

	// Voxel texture
	voxelTexture = new Texture3D(voxelTextureSize, voxelTextureSize, voxelTextureSize);

	// Dummy render target
	dummyVoxelizationFbo = new FBO(voxelTextureSize, voxelTextureSize,
								   MTLPixelFormatRGBA8Unorm,
								   MTLPixelFormatInvalid,
								   false,
								   8);
}

void Graphics::voxelize(id<MTLCommandBuffer> commandBuffer,
						Scene & renderingScene, bool clearVoxelization)
{
	if (clearVoxelization) {
		auto computeEncoder = [commandBuffer computeCommandEncoder];
		float clearColor[4] = { 0, 0, 0, 0 };
		voxelTexture->clear(computeEncoder, clearColor);
		[computeEncoder endEncoding];
	}

	auto renderEncoder = dummyVoxelizationFbo->beginRenderPass(commandBuffer,
															   MTLLoadActionDontCare,
															   false, false, 1);

	Material * material = voxelizationMaterial;
	material->activate(renderEncoder);

	// Settings.
	uploadGlobalConstants(renderEncoder);
	[renderEncoder setViewport:viewport(voxelTextureSize, voxelTextureSize)];
	[renderEncoder setCullMode:MTLCullModeNone];
	[renderEncoder setDepthStencilState:depthDisabledState];

	// Texture.
	voxelTexture->activate(renderEncoder, 2);

	// ----- Render.
	// Use 3 projection passes.
	// This is because we need to use independent raster order groups for each direction
	for (uint32_t i = 0; i < 3; ++i)
	{
		[renderEncoder setVertexBytes:&i length:sizeof(i) atIndex:VOXEL_PROJ_BINDING];
		renderQueue(renderEncoder, renderingScene.renderers);
	}
	[renderEncoder endEncoding];

	// Mipmap generation
	if (automaticallyRegenerateMipmap || regenerateMipmapQueued) {
		auto blitEncoder = [commandBuffer blitCommandEncoder];
		voxelTexture->generateMips(blitEncoder);
		regenerateMipmapQueued = false;
		[blitEncoder endEncoding];
	}
}

// ----------------------
// Voxelization visualization.
// ----------------------
void Graphics::initVoxelVisualization(unsigned int viewportWidth, unsigned int viewportHeight)
{
	// Materials.
	worldPositionMaterial = MaterialStore::getInstance().findMaterialWithName("world_position");
	voxelVisualizationMaterial = MaterialStore::getInstance().findMaterialWithName("voxel_visualization");

	assert(worldPositionMaterial != nullptr);
	assert(voxelVisualizationMaterial != nullptr);

	// FBOs for rendering world space positions of front and back facing of cube
	// Since we use unit size cube, everything will be within range -1, 1. So use Snorm format is OK, and this format is supported
	// on all hardwares according to https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf.
	vvfbo1 = new FBO(viewportHeight, viewportWidth, MTLPixelFormatRGBA16Snorm, MTLPixelFormatDepth32Float);
	vvfbo2 = new FBO(viewportHeight, viewportWidth, MTLPixelFormatRGBA16Snorm, MTLPixelFormatDepth32Float);

	// Rendering cube.
	cubeShape = ObjLoader::loadObjFile("Assets/Models/cube.obj");
	assert(cubeShape->meshes.size() == 1);
	cubeMeshRenderer = new MeshRenderer(&cubeShape->meshes[0]);

	// Rendering quad.
	quad = StandardShapes::createQuad();
	quadMeshRenderer = new MeshRenderer(&quad);
}

void Graphics::renderVoxelVisualization(id<MTLCommandBuffer> commandBuffer,
										MTLRenderPassDescriptor *backbufferRenderPassDesc,
										Scene & renderingScene,
										unsigned int viewportWidth, unsigned int viewportHeight)
{
	// -------------------------------------------------------
	// Render cube to FBOs.
	// -------------------------------------------------------
	// Back
	auto renderEncoder = vvfbo1->beginRenderPass(commandBuffer);
	worldPositionMaterial->activate(renderEncoder);
	uploadGlobalConstants(renderEncoder);
	[renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	[renderEncoder setCullMode:MTLCullModeFront];
	[renderEncoder setDepthStencilState:depthEnabledState];
	[renderEncoder setViewport:viewport(vvfbo1->width, vvfbo1->height)];

	cubeMeshRenderer->render(renderEncoder);
	[renderEncoder endEncoding];

	// Front.
	renderEncoder = vvfbo2->beginRenderPass(commandBuffer);
	worldPositionMaterial->activate(renderEncoder);
	uploadGlobalConstants(renderEncoder);
	[renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	[renderEncoder setCullMode:MTLCullModeBack];
	[renderEncoder setDepthStencilState:depthEnabledState];
	[renderEncoder setViewport:viewport(vvfbo2->width, vvfbo2->height)];

	cubeMeshRenderer->render(renderEncoder);
	[renderEncoder endEncoding];

	// -------------------------------------------------------
	// Render 3D texture to screen.
	// -------------------------------------------------------
	renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:backbufferRenderPassDesc];
	voxelVisualizationMaterial->activate(renderEncoder);
	uploadGlobalConstants(renderEncoder);

	// Settings.
	[renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
	[renderEncoder setCullMode:MTLCullModeBack];
	[renderEncoder setDepthStencilState:depthDisabledState];
	[renderEncoder setViewport:viewport(viewportWidth, viewportHeight)];

	// Activate textures.
	vvfbo1->activateAsTexture(renderEncoder, 0);
	vvfbo2->activateAsTexture(renderEncoder, 1);
	voxelTexture->activate(renderEncoder, 2);

	// Render.
	quadMeshRenderer->render(renderEncoder);
	[renderEncoder endEncoding];
}

Graphics::~Graphics()
{
	if (vvfbo1) delete vvfbo1;
	if (vvfbo2) delete vvfbo2;
	if (dummyVoxelizationFbo) delete dummyVoxelizationFbo;
	if (quadMeshRenderer) delete quadMeshRenderer;
	if (cubeMeshRenderer) delete cubeMeshRenderer;
	if (cubeShape) delete cubeShape;
	if (voxelTexture) delete voxelTexture;
}
