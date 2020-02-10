#pragma once

#include <iostream>
#include <string>

/// <summary> A simple point light. </summary>
class PointLight {
public:
	glm::vec3 position, color;
	PointLight(glm::vec3 _position = { 0, 0, 0 }, glm::vec3 _color = { 1, 1, 1 }) : position(_position), color(_color) {}
};
