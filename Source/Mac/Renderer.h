//
//  Renderer.h
//  VoxelConeTracingMetal
//
//  Created by Le Quyen on 9/2/20.
//  Copyright © 2020 HQgame. All rights reserved.
//

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end

