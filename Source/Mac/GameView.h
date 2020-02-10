//
//  GameView.h
//  VoxelConeTracingMetal
//
//  Created by Le Quyen on 10/2/20.
//  Copyright © 2020 HQgame. All rights reserved.
//

#import <MetalKit/MetalKit.h>

#import "GameViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface GameView : MTKView

@property (weak) IBOutlet NSTextField* fpsCounter;

@property (strong) GameViewController* controller;

@end

NS_ASSUME_NONNULL_END
