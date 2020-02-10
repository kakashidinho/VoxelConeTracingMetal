#include "ObjLoader.h"
#include "System.h"

#define __UTILITY_LOG_LOADING_TIME true

#include <fstream>
#include <vector>
#include <algorithm>

#if __UTILITY_LOG_LOADING_TIME
#include <iostream>
#include <iomanip>
#include "../Time/Time.h"
#endif

#include "External/tiny_obj_loader.h"
#include "../Shape/VertexData.h"
#include "../Shape/Mesh.h"

Shape * ObjLoader::loadObjFile(const std::string relativePath) {
	auto path = System::fullResourcePath(relativePath);
#if __UTILITY_LOG_LOADING_TIME
	double logTimestamp = Time::currentTime();
	double took;
	std::cout << "Loading obj '" << path << "'..." << std::endl;
#endif

	std::vector<tinyobj::shape_t> shapes;
	std::vector<tinyobj::material_t> materials;
	Shape * result = new Shape();

	std::string err;
	if (!tinyobj::LoadObj(shapes, materials, err, path.c_str()) || shapes.size() == 0) {
#if __UTILITY_LOG_LOADING_TIME
		std::cerr << "Failed to load object with path '" << path << "'. Error message:" << std::endl << err << std::endl;
#endif
		return nullptr;
	}

#if __UTILITY_LOG_LOADING_TIME
	took = Time::currentTime() - logTimestamp;
	std::cout << std::setprecision(4) << " - Parsing '" << path << "' took " << took << " seconds (by tinyobjloader)." << std::endl;
	logTimestamp = Time::currentTime();
#endif

	// Load all shapes.
	for (const auto & shape : shapes) {

		// Create a new mesh.
		Mesh newMesh;
		auto & vertexData = newMesh.vertexData;
		auto & indices = newMesh.indices;

		indices.reserve(shape.mesh.indices.size());

		// Push back all indices.
		for (const auto index : shape.mesh.indices) {
			indices.push_back(index);
		}

		vertexData.reserve(shape.mesh.positions.size());

		// Positions.
		for (unsigned int i = 0, j = 0; i < shape.mesh.positions.size(); i += 3, ++j) {
			if (j >= vertexData.size()) {
				vertexData.push_back(VertexData());
			}
			vertexData[j].position.x = shape.mesh.positions[i + 0];
			vertexData[j].position.y = shape.mesh.positions[i + 1];
			vertexData[j].position.z = shape.mesh.positions[i + 2];
		}

		// Normals.
		for (unsigned int i = 0, j = 0; i < shape.mesh.normals.size(); i += 3, ++j) {
			if (j >= vertexData.size()) {
				vertexData.push_back(VertexData());
			}
			vertexData[j].normal.x = shape.mesh.normals[i + 0];
			vertexData[j].normal.y = shape.mesh.normals[i + 1];
			vertexData[j].normal.z = shape.mesh.normals[i + 2];
		}

		result->meshes.push_back(newMesh);
	}

#if __UTILITY_LOG_LOADING_TIME
	took = Time::currentTime() - logTimestamp;
	std::cout << std::setprecision(4) << " - Loading '" << path << "' took " << took << " seconds." << std::endl;
#endif
	return result;
}
