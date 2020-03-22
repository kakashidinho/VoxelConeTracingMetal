#include "Application.h"

// Standard library.
#include <iostream>
#include <iomanip>
#include <time.h>

// Internal.
#include "Scene/Scene.h"
#include "Scene/ScenePack.h"
#include "Graphic/Graphics.h"
#include "Graphic/Material/MaterialStore.h"
#include "Graphic/Renderer/MeshRenderer.h"
#include "Graphic/Camera/Controllers/FirstPersonController.h"
#include "Time/Time.h"

static constexpr double kFPSInterval = 1.0;

using __DEFAULT_LEVEL = MultipleObjectsScene; // The scene that will be loaded on startup.
// (see ScenePack.h for more scenes)

Application & Application::getInstance() {
	static Application application;
	return application;
}

void Application::init(id<MTLDevice> metalDevice, uint32_t viewportWidth, uint32_t viewportHeight) {
	graphics.init(metalDevice, viewportWidth, viewportHeight);
	// -------------------------------------
	// Initialize scene.
	// -------------------------------------
	scene = new __DEFAULT_LEVEL();
	scene->init(viewportWidth, viewportHeight);
	std::cout << "[3] : Scene initialized." << std::endl;
}

void Application::iterate(id<MTLCommandBuffer> commandBuffer,
						  MTLRenderPassDescriptor *backbufferRenderPassDesc,
						  uint32_t viewportWidth,
						  uint32_t viewportHeight)
{
	// --------------------------------------------------
	// Fps counter
	// --------------------------------------------------
	auto curTime = Time::currentTime();
	if (!Time::initialized)
	{
		Time::time = curTime;
		Time::initialized = true;
	}

	Time::frameCount++;
	Time::deltaTime = curTime - Time::time;
	Time::time = curTime;
	if (Time::deltaTime > 0.0000001 && curTime - Time::lastFpsCouterTime >= kFPSInterval)
	{
		Time::framesPerSecond = 0.8 * Time::framesPerSecond + 0.2 * (1.0 / Time::deltaTime);
		Time::lastFpsCouterTime = curTime;
	}
	// --------------------------------------------------
	// Update world.
	// --------------------------------------------------
	if (!pause)
		scene->update(mouseDelta[0], mouseDelta[1], transientCameraMoveKeyPressed);

	// --------------------------------------------------
	// Rendering.
	// --------------------------------------------------

	graphics.render(commandBuffer, backbufferRenderPassDesc,
					*scene,
					viewportWidth, viewportHeight,
					currentRenderingMode);

	// Reset state
	mouseDelta[0] = mouseDelta[1] = 0;
	for (int i = 0; i < 4; ++i)
	{
		transientCameraMoveKeyPressed[i] = cameraMoveKeyPressed[i];
	}
}

Application::~Application() {
	delete scene;
}

Application::Application() {

}

void Application::onMouseMoved(float mouseXDelta, float mouseYDelta)
{
	mouseDelta[0] += mouseXDelta;
	mouseDelta[1] += mouseYDelta;
}

void Application::onKeyDown(char key)
{
	switch (key)
	{
		case 'A': case 'a':
			transientCameraMoveKeyPressed[FirstPersonController::LEFT] =
			cameraMoveKeyPressed[FirstPersonController::LEFT] = true;
			break;
		case 'S': case 's':
		transientCameraMoveKeyPressed[FirstPersonController::BACKWARD] =
			cameraMoveKeyPressed[FirstPersonController::BACKWARD] = true;
			break;
		case 'W': case 'w':
			transientCameraMoveKeyPressed[FirstPersonController::FORWARD] =
			cameraMoveKeyPressed[FirstPersonController::FORWARD] = true;
			break;
		case 'D': case 'd':
			transientCameraMoveKeyPressed[FirstPersonController::RIGHT] =
			cameraMoveKeyPressed[FirstPersonController::RIGHT] = true;
			break;
	}
}

void Application::onKeyUp(char key)
{
	switch (key)
	{
		case 'X': case 'x':
			std::cout << "Application state: " << ++state << std::endl;
			break;
		case 'Z': case 'z':
			std::cout << "Application state: " << --state << std::endl;
			break;
		case 'R': case 'r':
		{
			using GRM = Graphics::RenderingMode;
			if (currentRenderingMode == GRM::VOXELIZATION_VISUALIZATION) {
				currentRenderingMode = GRM::VOXEL_CONE_TRACING;
			}
			else {
				currentRenderingMode = GRM::VOXELIZATION_VISUALIZATION;
			}
		}
			break;
		case 'A': case 'a':
			cameraMoveKeyPressed[FirstPersonController::LEFT] = false;
			break;
		case 'S': case 's':
			cameraMoveKeyPressed[FirstPersonController::BACKWARD] = false;
			break;
		case 'W': case 'w':
			cameraMoveKeyPressed[FirstPersonController::FORWARD] = false;
			break;
		case 'D': case 'd':
			cameraMoveKeyPressed[FirstPersonController::RIGHT] = false;
			break;
		case 'I': case 'i':
			graphics.settings().indirectDiffuseLight = !graphics.settings().indirectDiffuseLight;
			graphics.settings().indirectSpecularLight = !graphics.settings().indirectSpecularLight;
			std::cout << "Application indirect diffuse light: " << graphics.settings().indirectDiffuseLight << std::endl;
			std::cout << "Application indirect specular light: " << graphics.settings().indirectSpecularLight << std::endl;
			break;
		case 'U': case 'u':
			graphics.settings().indirectDiffuseLight = !graphics.settings().indirectDiffuseLight;
			std::cout << "Application indirect diffuse light: " << graphics.settings().indirectDiffuseLight << std::endl;
			break;
		case 'P': case 'p':
			graphics.settings().indirectSpecularLight = !graphics.settings().indirectSpecularLight;
			std::cout << "Application indirect specular light: " << graphics.settings().indirectSpecularLight << std::endl;
			break;
		case 'C': case 'c':
			graphics.settings().shadows = !graphics.settings().shadows;
			std::cout << "Application indirect shadow: " << graphics.settings().shadows << std::endl;
			break;
		case 'T': case 't':
			pause = !pause;
			if (!pause)
			{
				Time::time = Time::currentTime();
			}
			break;
		case 'M': case 'm':
			graphics.useComputeShaderToGenMip = !graphics.useComputeShaderToGenMip;
			std::cout << "Mipmap generation use computeshader: " << graphics.useComputeShaderToGenMip << std::endl;
			break;
	}
}
