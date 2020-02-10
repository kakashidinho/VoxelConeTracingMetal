#include <metal_stdlib>
#include <simd/simd.h>

#include "../../common.metal"

using namespace metal;

struct VS_out
{
    float3 worldPosition [[user(locn0)]];
    float4 gl_Position [[position]];
};

struct VS_in
{
    packed_float3 position;
    packed_float3 normal;
};

vertex VS_out VS(const device VS_in *vertices VERTEX_BUFFER_BINDING,
                 const device uint *indices INDEX_BUFFER_BINDING,
                 uint vid [[ vertex_id ]],
                 constant AppState &appState APPSTATE_BINDING,
                 constant ObjectState& transform TRANSFORM_BINDING)
{
    uint index = indices[vid];
    VS_in in = vertices[index];

    VS_out out = {};
    out.worldPosition = float3(worldTransform(transform, float4(in.position, 1.0)).xyz);
    out.gl_Position = (appState.P * appState.V) * float4(out.worldPosition, 1.0);
    return out;
}

fragment float4 FS(VS_out in [[stage_in]])
{
    return float4(in.worldPosition.x, in.worldPosition.y, in.worldPosition.z, 1.0);
}

