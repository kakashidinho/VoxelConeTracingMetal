// This is the main entry for the voxel cone tracing demo.
// See 'Graphics.h' and 'voxel_cone_tracing.frag' for the code relevant to voxel cone tracing.
#pragma once

#include "Graphic/Graphics.h"

class Scene;

/// <summary>
/// Singleton implementation of an application and the main entry for the whole application.
/// </summary>
class Application {
public:
	// MSAA samples for main rendering
	static constexpr unsigned int MSAA_SAMPLES = 1;

	int state = 0; // Used to simplify debugging. Sent to all shaders continuously.
	Graphics::RenderingMode currentRenderingMode = Graphics::RenderingMode::VOXEL_CONE_TRACING;

	~Application();

	/// <summary> The graphical context that is used for rendering the current scene. </summary>
	Graphics graphics;

	/// <summary> Returns the application instance (which is a singleton). </summary>
	static Application & getInstance();

	/// <summary> Initializes the application. </summary>
	void init(id<MTLDevice> metalDevice, uint32_t viewportWidth, uint32_t viewportHeight);

	/// <summary> Rendering loop </summary>
	void iterate(id<MTLCommandBuffer> commandBuffer,
				 MTLRenderPassDescriptor *backbufferRenderPassDesc,
				 uint32_t viewportWidth,
				 uint32_t viewportHeight);

	// Delete copy constructors.
	Application(Application const &) = delete;
	void operator=(Application const &) = delete;

	void onMouseMoved(float mouseXDelta, float mouseYDelta);
	void onKeyDown(char key);
	void onKeyUp(char key);
private:
	Application(); // Make sure constructor is private to prevent instantiating outside of singleton pattern.

	/// <summary> The scene to update and render. </summary>
	Scene * scene;

	float mouseDelta[2] = {0, 0};
	bool cameraMoveKeyPressed[4] = {false, false, false, false};
	// These variables are to store transient key press event which happen before application has a chance
	// to process them
	bool transientCameraMoveKeyPressed[4] = {false, false, false, false};

	// Pause updating?
	bool pause = false;
};
