#include <metal_stdlib>
#include <simd/simd.h>

#include "../common.metal"

using namespace metal;

struct ClearParams
{
    float4 color;
};

kernel void clear(uint3 idx[[thread_position_in_grid]],
                  texture3d<float, access::write> textureVoxel [[texture(0)]],
                  constant ClearParams &params [[buffer(COMPUTE_PARAM_START_IDX)]])
{
    uint3 dim = uint3(textureVoxel.get_width(), textureVoxel.get_height(), textureVoxel.get_depth());
    if (idx.x >= dim.x || idx.y >= dim.y || idx.z >= dim.z)
        return;

    textureVoxel.write(params.color, idx);
}


struct VS_in
{
    packed_float3 position;
    packed_float3 normal;
};

struct TriangleParams
{
    uint numTriangles;
};

// Compute the dominant axis of each triangle and store in a buffer
kernel void computeTriangleDominantAxis(uint triIdx[[thread_position_in_grid]],
                                        const device VS_in *vertices VERTEX_BUFFER_BINDING,
                                        const device uint *indices INDEX_BUFFER_BINDING,
                                        constant ObjectState &transform TRANSFORM_BINDING,
                                        constant TriangleParams &params [[buffer(COMPUTE_PARAM_START_IDX)]],
                                        device uchar *triDominantAxis TRI_DOMINANT_BUFFER_BINDING /* output buffer */)
{
    if (triIdx >= params.numTriangles)
        return;

    uint baseVIdx = 3 * triIdx;

    // compute triangle's normal
    float4 pos0 = worldTransform(transform, float4(vertices[indices[baseVIdx]].position, 1.0));
    float4 pos1 = worldTransform(transform, float4(vertices[indices[baseVIdx+1]].position, 1.0));
    float4 pos2 = worldTransform(transform, float4(vertices[indices[baseVIdx+2]].position, 1.0));
    float3 triNormal = abs(cross(pos1.xyz - pos0.xyz, pos2.xyz - pos0.xyz));

    // Decide dominant axis
    uchar dominantAxis;
    if(triNormal.z > triNormal.x && triNormal.z > triNormal.y){
        dominantAxis = 2;
    } else if (triNormal.x > triNormal.y && triNormal.x > triNormal.z){
        dominantAxis = 0;
    } else {
        dominantAxis = 1;
    }

    triDominantAxis[triIdx] = dominantAxis;
}
