#include "Time.h"

#include <chrono>

bool Time::initialized = false;
unsigned long long Time::frameCount = 0;
double Time::deltaTime = 0, Time::framesPerSecond = 1, Time::time = 0, Time::lastFpsCouterTime = 0;


double Time::currentTime()
{
	auto curTime = std::chrono::high_resolution_clock::now();
	auto nanosec = curTime.time_since_epoch();

	return nanosec.count() * 0.000000001;
}
