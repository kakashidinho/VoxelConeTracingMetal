#pragma once

#include <glm.hpp>

/// <summary> Contains information about vertices such as position, normal, texture coordinate and color. </summary>
class VertexData {
public:
	glm::vec3 position, normal;
	VertexData(
		glm::vec3 _position = glm::vec3(0, 0, 0),
		glm::vec3 _normal = glm::vec3(0, 0, 0)) :
		position(_position), normal(_normal) {}
};
