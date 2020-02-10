#include "System.h"

#import <Foundation/Foundation.h>

namespace System {
std::string fullResourcePath(const std::string &relativePath)
{
	NSString *filePath = [NSString stringWithFormat:@"%@/%s", [[NSBundle mainBundle] resourcePath], relativePath.c_str()];
	return filePath.UTF8String;
}
}
