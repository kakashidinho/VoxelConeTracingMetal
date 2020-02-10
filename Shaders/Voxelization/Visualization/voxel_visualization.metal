// A simple fragment shader path tracer used to visualize 3D textures.
// Original GLSL Author:    Fredrik Pr‰ntare <prantare@gmail.com>
// Metal Autthor:           Le Hoang Quyen (lehoangq@gmail.com)
// Date:    2020
#include <metal_stdlib>
#include <simd/simd.h>

#include "../../common.metal"

using namespace metal;

// Vertex shader
struct VS_out
{
    float2 textureCoordinateFrag [[user(locn0)]];
    float4 gl_Position [[position]];
};

struct VS_in
{
    packed_float3 position;
    packed_float3 normal;
};

static inline __attribute__((always_inline))
float2 scaleAndBias(thread const float2& p)
{
    return (p * 0.5) + float2(0.5);
}

vertex VS_out VS(const device VS_in *vertices VERTEX_BUFFER_BINDING,
                 const device uint *indices INDEX_BUFFER_BINDING,
                 uint vid [[ vertex_id ]])
{
    uint index = indices[vid];
    VS_in in = vertices[index];

    VS_out out = {};
    float2 param = in.position.xy;
    param.y = -param.y;
    out.textureCoordinateFrag = scaleAndBias(param);
    out.gl_Position = float4(in.position, 1.0);
    return out;
}

// Fragment shader
#define INV_STEP_LENGTH (1.0f/STEP_LENGTH)
#define STEP_LENGTH 0.005f

// Scales and bias a given vector (i.e. from [-1, 1] to [0, 1]).
static inline
float3 scaleAndBias(float3 p) { return 0.5f * p + float3(0.5f); }

fragment float4 FS(VS_out in [[stage_in]],
                   texture2d<float> textureBack [[texture(0)]], // Unit cube back FBO.
                   texture2d<float> textureFront [[texture(1)]], // Unit cube front FBO.
                   texture3d<float> texture3D [[texture(2)]], // Texture in which voxelization is stored.
                   constant AppState& appState APPSTATE_BINDING) {
    float4 color;

    const float mipmapLevel = appState.state;

    // Initialize ray.
    const float3 origin = isInsideCube(appState.cameraPosition, 0.2f) ?
        appState.cameraPosition : textureFront.sample(gCommonTextureSampler, in.textureCoordinateFrag).xyz;
    float3 direction = textureBack.sample(gCommonTextureSampler, in.textureCoordinateFrag).xyz - origin;
    const uint numberOfSteps = uint(INV_STEP_LENGTH * length(direction));
    direction = normalize(direction);

    // Trace.
    color = float4(0.0f);
    for (uint step = 0; step < numberOfSteps && color.a < 0.99f; ++step) {
        const float3 currentPoint = origin + STEP_LENGTH * step * direction;
        float3 coordinate = scaleAndBias(currentPoint);
        float4 currentSample = textureLodNearest(texture3D, coordinate, mipmapLevel);
        color += (1.0f - color.a) * currentSample;
    }
    color.rgb = pow(color.rgb, float3(1.0 / 2.2));

    return color;
}
