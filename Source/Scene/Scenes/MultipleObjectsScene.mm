#include "MultipleObjectsScene.h"

#include <gtx/rotate_vector.hpp>

#include "../../Graphic/Lighting/PointLight.h"
#include "../../Graphic/Camera/Camera.h"
#include "../../Graphic/Camera/PerspectiveCamera.h"
#include "../../Time/Time.h"
#include "../../Utility/ObjLoader.h"
#include "../../Graphic/Renderer/MeshRenderer.h"
#include "../../Graphic/Material/MaterialSetting.h"
#include "../../Application.h"

// Settings.
namespace {
unsigned int lightSphereIndex = 0;
MaterialSetting * objectMaterialSetting;
}

void MultipleObjectsScene::init(unsigned int viewportWidth, unsigned int viewportHeight) {
	FirstPersonScene::init(viewportWidth, viewportHeight);

	// Cornell box.
	Shape * cornell = ObjLoader::loadObjFile("Assets/Models/cornell.obj");
	shapes.push_back(cornell);
	for (unsigned int i = 0; i < cornell->meshes.size(); ++i) {
		renderers.push_back(new MeshRenderer(&(cornell->meshes[i])));
	}
	for (auto & r : renderers) {
		r->transform.position -= glm::vec3(0.00f, 0.0f, 0);
		r->transform.scale = glm::vec3(0.995f);
		r->transform.updateTransformMatrix();
	}

	renderers[0]->materialSetting = MaterialSetting::Red(); // Green wall.
	renderers[1]->materialSetting = MaterialSetting::White(); // Floor.
	renderers[1]->materialSetting->diffuseReflectivity = 0.7f;
	renderers[1]->materialSetting->specularReflectivity = 0.3f;
	renderers[1]->materialSetting->specularDiffusion = 5.f;
	renderers[2]->materialSetting = MaterialSetting::White(); // Roof.
	renderers[3]->materialSetting = MaterialSetting::Blue(); // Red wall.
	renderers[4]->materialSetting = MaterialSetting::White(); // White wall.
	renderers[5]->materialSetting = MaterialSetting::White(); // Left box.
	renderers[6]->materialSetting = MaterialSetting::White(); // Right box.
	renderers[5]->enabled = false; // Disable boxes.
	renderers[6]->enabled = false; // Disable boxes.

	// Susanne.
	int objectIndex = renderers.size();
	Shape * object = ObjLoader::loadObjFile("Assets/Models/susanne.obj");
	shapes.push_back(object);
	for (unsigned int i = 0; i < object->meshes.size(); ++i) {
		renderers.push_back(new MeshRenderer(&(object->meshes[i])));
	}

	MeshRenderer * objectRenderer = renderers[objectIndex];
	objectRenderer->materialSetting = MaterialSetting::White();
	objectMaterialSetting = objectRenderer->materialSetting;
	objectMaterialSetting->specularColor = glm::vec3(0.2, 0.8, 1.0);
	objectMaterialSetting->diffuseColor = objectMaterialSetting->specularColor;
	objectMaterialSetting->emissivity = 0.00f;
	objectMaterialSetting->specularReflectivity = 0.9f;
	objectMaterialSetting->diffuseReflectivity = 0.1f;
	objectMaterialSetting->specularDiffusion = 3.2f;
	objectMaterialSetting->transparency = 0.5f;
	objectRenderer->tweakable = true;
	objectRenderer->transform.scale = glm::vec3(0.23f);
	objectRenderer->transform.rotation = glm::vec3(0.00, 0.30, 0.00);
	objectRenderer->transform.position = glm::vec3(0.07, -0.49, 0.36);
	objectRenderer->transform.updateTransformMatrix();

	// Dragon.
	objectIndex = renderers.size();
	object = ObjLoader::loadObjFile("Assets/Models/dragon.obj");
	shapes.push_back(object);
	for (unsigned int i = 0; i < object->meshes.size(); ++i) {
		renderers.push_back(new MeshRenderer(&(object->meshes[i])));
	}

	objectRenderer = renderers[objectIndex];
	objectRenderer->materialSetting = MaterialSetting::White();
	objectMaterialSetting = objectRenderer->materialSetting;
	objectMaterialSetting->specularColor = glm::vec3(1.0, 0.8, 0.6);
	objectMaterialSetting->diffuseColor = objectMaterialSetting->specularColor;
	objectMaterialSetting->emissivity = 0.00f;
	objectMaterialSetting->specularReflectivity = 0.65f;
	objectMaterialSetting->diffuseReflectivity = 0.35f;
	objectMaterialSetting->specularDiffusion = 2.2f;
	objectRenderer->tweakable = true;
	objectRenderer->transform.scale = glm::vec3(1.3f);
	objectRenderer->transform.rotation = glm::vec3(0, 2.1, 0);
	objectRenderer->transform.position = glm::vec3(-0.28, -0.52, 0.00);
	objectRenderer->transform.updateTransformMatrix();

	// Bunny.
	objectIndex = renderers.size();
	object = ObjLoader::loadObjFile("Assets/Models/bunny.obj");
	shapes.push_back(object);
	for (unsigned int i = 0; i < object->meshes.size(); ++i) {
		renderers.push_back(new MeshRenderer(&(object->meshes[i])));
	}

	objectRenderer = renderers[objectIndex];
	objectRenderer->materialSetting = MaterialSetting::White();
	objectMaterialSetting = objectRenderer->materialSetting;
	objectMaterialSetting->specularColor = glm::vec3(0.7, 0.8, 0.7);
	objectMaterialSetting->diffuseColor = objectMaterialSetting->specularColor;
	objectMaterialSetting->emissivity = 0.00f;
	objectMaterialSetting->specularReflectivity = 0.6f;
	objectMaterialSetting->diffuseReflectivity = 0.4f;
	objectMaterialSetting->specularDiffusion = 3.4f;
	objectRenderer->tweakable = true;
	objectRenderer->transform.scale = glm::vec3(0.31f);
	objectRenderer->transform.rotation = glm::vec3(0, 0.4, 0);
	objectRenderer->transform.position = glm::vec3(0.44, -0.52, 0);
	objectRenderer->transform.updateTransformMatrix();

	// Light sphere.
	Shape * lightSphere = ObjLoader::loadObjFile("Assets/Models/sphere.obj");
	shapes.push_back(lightSphere);
	for (unsigned int i = 0; i < lightSphere->meshes.size(); ++i) {
		renderers.push_back(new MeshRenderer(&(lightSphere->meshes[i])));
	}

	// Light Sphere.
	lightSphereIndex = renderers.size() - 1;
	renderers[lightSphereIndex]->materialSetting = MaterialSetting::Emissive();
	renderers[lightSphereIndex]->materialSetting->diffuseColor.r = 1.0f;
	renderers[lightSphereIndex]->materialSetting->diffuseColor.g = 1.0f;
	renderers[lightSphereIndex]->materialSetting->diffuseColor.b = 1.0f;
	renderers[lightSphereIndex]->materialSetting->emissivity = 8.0f;
	renderers[lightSphereIndex]->materialSetting->specularReflectivity = 0.0f;
	renderers[lightSphereIndex]->materialSetting->diffuseReflectivity = 0.0f;

	// ----------
	// Lighting.
	// ----------
	PointLight p;
	pointLights.push_back(p);
	pointLights[0].color = glm::vec3(1, 1, 1);
}

void MultipleObjectsScene::update(float mouseXDelta, float mouseYDelta, bool buttonsPressed[])
{
	FirstPersonScene::update(mouseXDelta, mouseYDelta, buttonsPressed);

	// Lighting rotation.
	glm::vec3 r = glm::vec3(sinf(float(Time::time * 0.97)), sinf(float(Time::time * 0.45)), sinf(float(Time::time * 0.32)));

	renderers[lightSphereIndex]->transform.position = glm::vec3(0, 0.5, 0.1) + r * 0.1f;
	renderers[lightSphereIndex]->transform.position.x *= 4.5f;
	renderers[lightSphereIndex]->transform.position.z *= 4.5f;
	renderers[lightSphereIndex]->transform.rotation = r;
	renderers[lightSphereIndex]->transform.scale = glm::vec3(0.049f);
	renderers[lightSphereIndex]->transform.updateTransformMatrix();

	pointLights[0].position = renderers[lightSphereIndex]->transform.position;
	renderers[lightSphereIndex]->materialSetting->diffuseColor = pointLights[0].color;
}

MultipleObjectsScene::~MultipleObjectsScene() {
	for (auto * r : renderers) delete r;
	for (auto * s : shapes) delete s;
}
