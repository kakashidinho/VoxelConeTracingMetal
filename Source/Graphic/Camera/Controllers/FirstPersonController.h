#pragma once

#include <iostream> // TODO: Remove.

#include <gtx/rotate_vector.hpp>

#include "../../Camera/Camera.h"
#include "../../../Time/Time.h"
#include "../../Camera/PerspectiveCamera.h"
#include "../../../Application.h"

/// <summary> A first person controller that can be attached to a camera. </summary>
class FirstPersonController {
public:
	const float CAMERA_SPEED = 1.4f;
	const float CAMERA_ROTATION_SPEED = 0.003f;
	const float CAMERA_POSITION_INTERPOLATION_SPEED = 8.0f;
	const float CAMERA_ROTATION_INTERPOLATION_SPEED = 8.0f;

	enum MoveButton
	{
		LEFT,
		RIGHT,
		FORWARD,
		BACKWARD,
	};

	Camera * const renderingCamera;
	Camera * const targetCamera; // Dummy camera used for interpolation.

	FirstPersonController(Camera * camera)
		: targetCamera(new PerspectiveCamera()),
		  renderingCamera(camera)
	{
	}

	~FirstPersonController() { delete targetCamera; }

	void update(float xDelta, float yDelta, bool buttonsPressed[]) {
		if (firstUpdate) {
			targetCamera->rotation = renderingCamera->rotation;
			targetCamera->position = renderingCamera->position;
			firstUpdate = false;
		}

		// ----------
		// Rotation.
		// ----------
		float xRot = static_cast<float>(CAMERA_ROTATION_SPEED * xDelta);
		float yRot = static_cast<float>(CAMERA_ROTATION_SPEED * yDelta);

		// X rotation.

		targetCamera->rotation = glm::rotateY(targetCamera->rotation, xRot);

		// Y rotation.
		glm::vec3 newDirection = glm::rotate(targetCamera->rotation, yRot, targetCamera->right());
		float a = glm::dot(newDirection, glm::vec3(0, 1, 0));
		if (abs(a) < 0.99)
			targetCamera->rotation = newDirection;


		// ----------
		// Position.
		// ----------
		// Move forward.
		if (buttonsPressed[FORWARD]) {
			targetCamera->position += targetCamera->forward() * (float)Time::deltaTime * CAMERA_SPEED;
		}
		// Move backward.
		if (buttonsPressed[BACKWARD]) {
			targetCamera->position -= targetCamera->forward() * (float)Time::deltaTime * CAMERA_SPEED;
		}
		// Strafe right.
		if (buttonsPressed[RIGHT]) {
			targetCamera->position += targetCamera->right() * (float)Time::deltaTime * CAMERA_SPEED;
		}
		// Strafe left.
		if (buttonsPressed[LEFT]) {
			targetCamera->position -= targetCamera->right() * (float)Time::deltaTime * CAMERA_SPEED;
		}

		// Interpolate between target and current camera.
		auto * camera = renderingCamera;
		camera->rotation = mix(camera->rotation, targetCamera->rotation, glm::clamp(Time::deltaTime * CAMERA_ROTATION_INTERPOLATION_SPEED, 0.0, 1.0));
		camera->position = mix(camera->position, targetCamera->position, glm::clamp(Time::deltaTime * CAMERA_POSITION_INTERPOLATION_SPEED, 0.0, 1.0));

		// Update view (camera) matrix.
		camera->updateViewMatrix();
	}
private:
	bool firstUpdate = true;
};
