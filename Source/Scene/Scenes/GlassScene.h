#pragma once

#include <vector>

#include "../Templates/FirstPersonScene.h"

class Shape;

/// <summary> A refractive cone test scene. </summary>
class GlassScene : public FirstPersonScene {
public:
	void update(float mouseXDelta, float mouseYDelta, bool buttonsPressed[]) override;
	void init(unsigned int viewportWidth, unsigned int viewportHeight) override;
	~GlassScene();
private:
	std::vector<Shape*> shapes;
};
