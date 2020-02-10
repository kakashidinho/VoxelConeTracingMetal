#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ClearParams
{
    float4 color;
};

kernel void clear(uint3 idx[[thread_position_in_grid]],
                  texture3d<float, access::write> textureVoxel [[texture(0)]],
                  constant ClearParams &params [[buffer(0)]])
{
    uint3 dim = uint3(textureVoxel.get_width(), textureVoxel.get_height(), textureVoxel.get_depth());
    if (idx.x >= dim.x || idx.y >= dim.y || idx.z >= dim.z)
        return;

    textureVoxel.write(params.color, idx);
}
