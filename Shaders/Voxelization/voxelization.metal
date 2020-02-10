// Lit (diffuse) fragment voxelization shader.
// Original Author:    Fredrik Pr‰ntare <prantare@gmail.com>
// Metal Autthor:      Le Hoang Quyen (lehoangq@gmail.com)
// Date:    2020

#include <metal_stdlib>
#include <simd/simd.h>

#include "../common.metal"

using namespace metal;

constant bool kVoxelizationSinglePass[[function_constant(1)]];
constant bool kVoxelizationMultiPass = !kVoxelizationSinglePass;

struct VS_out
{
    float3 worldPosition [[user(locn0)]];
    float3 normal [[user(locn1)]];
    float4 gl_Position [[position]];
    uint layer [[render_target_array_index, function_constant(kVoxelizationSinglePass)]];
};

struct VS_in
{
    packed_float3 position;
    packed_float3 normal;
};

struct VoxelProjectionDir
{
    uint direction;
};

static inline
float3 projectOnAxis(float3 pos, uint axis)
{
    float3 proj;
    proj.x = pos[(axis + 1) % 3];
    proj.y = pos[(axis + 2) % 3];
    proj.z = 0;
    return proj;
}

vertex VS_out VS(uint vid [[ vertex_id ]],
                 const device VS_in *vertices VERTEX_BUFFER_BINDING,
                 const device uint *indices INDEX_BUFFER_BINDING,
                 const device uchar *triDominantAxis [[buffer(TRI_DOMINANT_BUFFER_BINDING_IDX), function_constant(kVoxelizationMultiPass)]],
                 constant ObjectState& transform TRANSFORM_BINDING,
                 constant VoxelProjectionDir& projDir [[buffer(VOXEL_PROJ_BINDING_IDX), function_constant(kVoxelizationMultiPass)]])
{
    uint index = indices[vid];
    VS_in in = vertices[index];

    VS_out out = {};

    out.worldPosition = float3(worldTransform(transform, float4(in.position, 1.0)).xyz);

    if (kVoxelizationMultiPass)
    {
        // In multipass mode, we skip the primitive if the current projection direction
        // is not the same as dominant axis
        uint dominantAxis = triDominantAxis[vid / 3];
        if (dominantAxis != projDir.direction)
        {
            // Degenerate point. This will be culled.
            out.gl_Position = float4(-2,-2,-2,-2);
        }
        else
        {
            out.gl_Position = float4(projectOnAxis(out.worldPosition, dominantAxis), 1);
        }
    }
    else
    {
        // Single pass case: we compute the dominant axis of the triangle containing this vertex
        // inside vertex shader itself.

        // get the triangle's first vertex index
        uint baseVIdx = vid / 3 * 3;

        // compute triangle's normal
        float4 pos0 = worldTransform(transform, float4(vertices[indices[baseVIdx]].position, 1.0));
        float4 pos1 = worldTransform(transform, float4(vertices[indices[baseVIdx+1]].position, 1.0));
        float4 pos2 = worldTransform(transform, float4(vertices[indices[baseVIdx+2]].position, 1.0));
        float3 triNormal = abs(cross(pos1.xyz - pos0.xyz, pos2.xyz - pos0.xyz));

        // decide dominant axis to project
        uint dominantAxis;
        if(triNormal.z > triNormal.x && triNormal.z > triNormal.y){
            dominantAxis = 2;
        } else if (triNormal.x > triNormal.y && triNormal.x > triNormal.z){
            dominantAxis = 0;
        } else {
            dominantAxis = 1;
        }

        // In single pass mode, we only project the triangle to the slice representing its
        // dominant axis
        out.gl_Position = float4(projectOnAxis(out.worldPosition, dominantAxis), 1);
        out.layer = dominantAxis;
    }

    out.normal = normalize(float3x3(transform.invTransM[0].xyz, transform.invTransM[1].xyz, transform.invTransM[2].xyz) * float3(in.normal));
    return out;
}

// Lighting attenuation factors.
#define DIST_FACTOR 1.1f /* Distance is multiplied by this when calculating attenuation. */
#define CONSTANT 1
#define LINEAR 0
#define QUADRATIC 1

// Returns an attenuation factor given a distance.
static inline
float attenuate(float dist){ dist *= DIST_FACTOR; return 1.0f / (CONSTANT + LINEAR * dist + QUADRATIC * dist * dist); }

float3 calculatePointLight(VS_out in, constant PointLight& light){
    const float3 direction = normalize(light.position - in.worldPosition);
    const float distanceToLight = distance(float3(light.position), in.worldPosition);
    const float attenuation = attenuate(distanceToLight);
    const float d = max(dot(normalize(in.normal), direction), 0.0f);
    return d * POINT_LIGHT_INTENSITY * attenuation * light.color;
}

float3 scaleAndBias(float3 p) { return 0.5f * p + float3(0.5f); }

fragment void FS(VS_out in [[stage_in]],
                 constant AppState& appState APPSTATE_BINDING,
                 constant ObjectState &objectState OBJECT_STATE_BINDING,
                 texture3d<float, access::read_write> textureVoxelRW [[texture(2), raster_order_group(0), function_constant(kReadWriteTextureSupported)]],
                 texture3d<float, access::write> textureVoxelW [[texture(2), raster_order_group(0), function_constant(kReadWriteTextureNotSupported)]])
{
    float3 color = float3(0.0f);
    if(!isInsideCube(in.worldPosition, 0)) return;

    // Calculate diffuse lighting fragment contribution.
    const uint maxLights = min(appState.numberOfLights, MAX_LIGHTS);
    for (uint i = 0; i < maxLights; ++i) color += calculatePointLight(in, appState.pointLights[i]);
    float3 spec = objectState.material.specularReflectivity * objectState.material.specularColor;
    float3 diff = objectState.material.diffuseReflectivity * objectState.material.diffuseColor;
    color = (diff + spec) * color + fast::clamp(objectState.material.emissivity, 0, 1) * objectState.material.diffuseColor;

    // Output lighting to 3D texture.
    float3 voxel = scaleAndBias(in.worldPosition);
    float alpha = pow(1 - objectState.material.transparency, 4); // For soft shadows to work better with transparent materials.
    float4 res = alpha * float4(float3(color), 1);
    if (kReadWriteTextureSupported)
    {
        int3 dim = int3(textureVoxelRW.get_width(), textureVoxelRW.get_height(), textureVoxelRW.get_depth());
        uint3 coords = uint3(int3(float3(dim) * voxel));
        // max blend
        res = max(res, textureVoxelRW.read(coords));
        textureVoxelRW.write(res, coords);
    }
    else
    {
        int3 dim = int3(textureVoxelW.get_width(), textureVoxelW.get_height(), textureVoxelW.get_depth());
        uint3 coords = uint3(int3(float3(dim) * voxel));
        textureVoxelW.write(res, coords);
    }
}
