#pragma once
class Time {
public:
	static bool initialized;
	static unsigned long long frameCount;
	static double deltaTime, time, lastFpsCouterTime, framesPerSecond;

	static double currentTime();
};
