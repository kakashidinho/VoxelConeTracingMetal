#pragma once
#include "../Shape/Shape.h"

#include <string>

namespace ObjLoader {
	/// <summary> Loads an .obj-file into a Shape object. </summary>
	Shape * loadObjFile(const std::string path = "Assets/Models/teapot.obj");
}
