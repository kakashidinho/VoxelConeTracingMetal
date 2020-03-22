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

kernel void copyRgba8Buffer(uint3 idx[[thread_position_in_grid]],
                            const device uint *bufferVoxel [[buffer(0)]],
                            texture3d<float, access::write> textureVoxel [[texture(0)]],
                            constant ClearParams &params [[buffer(COMPUTE_PARAM_START_IDX)]])
{
    uint3 dim = uint3(textureVoxel.get_width(), textureVoxel.get_height(), textureVoxel.get_depth());
    if (idx.x >= dim.x || idx.y >= dim.y || idx.z >= dim.z)
        return;

    uint idx1D = idx.z * (dim.x * dim.y) +
                 idx.y * dim.x +
                 idx.x;

    float4 color = rgba8ToVec4(bufferVoxel[idx1D]) / 255.0;
    textureVoxel.write(color, idx);
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

// -------------- Generate 3D texture mipmaps ----------------------------
#define k3DMipGenThreadGroupXYZ (8 * 8 * 8)
#define k3DMipGenThreadGroupXY (8 * 8)
#define k3DMipGenThreadGroupX 8

struct GenMipParams
{
    uint srcLevel;
    uint numMipLevelsToGen;
};

// NOTE(hqle): For numMipLevelsToGen > 1, this function assumes the texture is power of two. If it
// is not, quality will not be good.
kernel void generate3DMipmaps(uint lIndex [[thread_index_in_threadgroup]],
                              ushort3 gIndices [[thread_position_in_grid]],
                              texture3d<float> srcTexture [[texture(0)]],
                              texture3d<float, access::write> dstMip1 [[texture(1)]],
                              texture3d<float, access::write> dstMip2 [[texture(2)]],
                              texture3d<float, access::write> dstMip3 [[texture(3)]],
                              texture3d<float, access::write> dstMip4 [[texture(4)]],
                              constant GenMipParams &options [[buffer(0)]])
{
    uint firstMipLevel = options.srcLevel + 1;
    ushort3 mipSize =
        ushort3(srcTexture.get_width(firstMipLevel), srcTexture.get_height(firstMipLevel),
                srcTexture.get_depth(firstMipLevel));
    bool validThread = gIndices.x < mipSize.x && gIndices.y < mipSize.y && gIndices.z < mipSize.z;

    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, mip_filter::linear);

    // NOTE(hqle): Use simd_group function whenever available. That could avoid barrier use.

    // Use struct of array style to avoid bank conflict.
    threadgroup float sR[k3DMipGenThreadGroupXYZ];
    threadgroup float sG[k3DMipGenThreadGroupXYZ];
    threadgroup float sB[k3DMipGenThreadGroupXYZ];
    threadgroup float sA[k3DMipGenThreadGroupXYZ];

#define TEXEL_STORE(index, texel) \
    sR[index] = texel.r;          \
    sG[index] = texel.g;          \
    sB[index] = texel.b;          \
    sA[index] = texel.a;

#define TEXEL_LOAD(index) float4(sR[index], sG[index], sB[index], sA[index])

#define OUT_OF_BOUND_CHECK(edgeValue, targetValue, condition) \
    (condition) ? (edgeValue) : (targetValue)

    // ----- First mip level -------
    float4 texel1;
    if (validThread)
    {
        float3 texCoords = (float3(gIndices) + float3(0.5, 0.5, 0.5)) / float3(mipSize);
        texel1    = srcTexture.sample(textureSampler, texCoords, level(options.srcLevel));

        // Write to texture
        dstMip1.write(texel1, gIndices);
    }
    else
    {
        // This will invalidate all subsequent checks
        lIndex = 0xffffffff;
    }

    if (options.numMipLevelsToGen == 1)
    {
        return;
    }

    // ---- Second mip level --------

    // Write to shared memory
    TEXEL_STORE(lIndex, texel1);

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Index must be even
    if ((lIndex & 0x49) == 0)  // (lIndex & b1001001) == 0
    {
        bool3 atEdge = gIndices == (mipSize - ushort3(1));

        // (x+1, y, z)
        // If the width of mip is 1, texel2 will equal to texel1:
        float4 texel2 = OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + 1), atEdge.x);
        // (x, y+1, z)
        float4 texel3 = OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + k3DMipGenThreadGroupX), atEdge.y);
        // (x, y, z+1)
        float4 texel4 = OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + k3DMipGenThreadGroupXY), atEdge.z);
        // (x+1, y+1, z)
        float4 texel5 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (k3DMipGenThreadGroupX + 1)), atEdge.y);
        // (x+1, y, z+1)
        float4 texel6 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (k3DMipGenThreadGroupXY + 1)), atEdge.z);
        // (x, y+1, z+1)
        float4 texel7 = OUT_OF_BOUND_CHECK(
            texel3, TEXEL_LOAD(lIndex + (k3DMipGenThreadGroupXY + k3DMipGenThreadGroupX)), atEdge.z);
        // (x+1, y+1, z+1)
        float4 texel8 = OUT_OF_BOUND_CHECK(
            texel5, TEXEL_LOAD(lIndex + (k3DMipGenThreadGroupXY + k3DMipGenThreadGroupX + 1)), atEdge.z);

        texel1 = (texel1 + texel2 + texel3 + texel4 + texel5 + texel6 + texel7 + texel8) / 8.0;

        dstMip2.write(texel1, gIndices >> 1);

        // Write to shared memory
        TEXEL_STORE(lIndex, texel1);
    }

    if (options.numMipLevelsToGen == 2)
    {
        return;
    }

    // ---- 3rd mip level --------
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Index must be multiple of 4
    if ((lIndex & 0xdb) == 0)  // (lIndex & b11011011) == 0
    {
        mipSize = max(mipSize >> 1, ushort3(1));
        bool3 atEdge = (gIndices >> 1) == (mipSize - ushort3(1));

        // (x+1, y, z)
        // If the width of mip is 1, texel2 will equal to texel1:
        float4 texel2 = OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + 2), atEdge.x);
        // (x, y+1, z)
        float4 texel3 =
            OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupX)), atEdge.y);
        // (x, y, z+1)
        float4 texel4 =
            OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupXY)), atEdge.z);
        // (x+1, y+1, z)
        float4 texel5 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupX + 2)), atEdge.y);
        // (x+1, y, z+1)
        float4 texel6 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupXY + 2)), atEdge.z);
        // (x, y+1, z+1)
        float4 texel7 = OUT_OF_BOUND_CHECK(
            texel3, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupXY + 2 * k3DMipGenThreadGroupX)), atEdge.z);
        // (x+1, y+1, z+1)
        float4 texel8 = OUT_OF_BOUND_CHECK(
            texel5, TEXEL_LOAD(lIndex + (2 * k3DMipGenThreadGroupXY + 2 * k3DMipGenThreadGroupX + 2)), atEdge.z);

        texel1 = (texel1 + texel2 + texel3 + texel4 + texel5 + texel6 + texel7 + texel8) / 8.0;

        dstMip3.write(texel1, gIndices >> 2);

        // Write to shared memory
        TEXEL_STORE(lIndex, texel1);
    }

    if (options.numMipLevelsToGen == 3)
    {
        return;
    }

    // ---- 4th mip level --------
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Index must be multiple of 8
    if ((lIndex & 0x1ff) == 0)  // (lIndex & b111111111) == 0
    {
        mipSize = max(mipSize >> 1, ushort3(1));
        bool3 atEdge = (gIndices >> 2) == (mipSize - ushort3(1));

        // (x+1, y, z)
        // If the width of mip is 1, texel2 will equal to texel1:
        float4 texel2 = OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + 4), atEdge.x);
        // (x, y+1, z)
        float4 texel3 =
            OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupX)), atEdge.y);
        // (x, y, z+1)
        float4 texel4 =
            OUT_OF_BOUND_CHECK(texel1, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupXY)), atEdge.z);
        // (x+1, y+1, z)
        float4 texel5 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupX + 4)), atEdge.y);
        // (x+1, y, z+1)
        float4 texel6 =
            OUT_OF_BOUND_CHECK(texel2, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupXY + 4)), atEdge.z);
        // (x, y+1, z+1)
        float4 texel7 = OUT_OF_BOUND_CHECK(
            texel3, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupXY + 4 * k3DMipGenThreadGroupX)), atEdge.z);
        // (x+1, y+1, z+1)
        float4 texel8 = OUT_OF_BOUND_CHECK(
            texel5, TEXEL_LOAD(lIndex + (4 * k3DMipGenThreadGroupXY + 4 * k3DMipGenThreadGroupX + 4)), atEdge.z);

        texel1 = (texel1 + texel2 + texel3 + texel4 + texel5 + texel6 + texel7 + texel8) / 8.0;

        dstMip4.write(texel1, gIndices >> 3);
    }
}
