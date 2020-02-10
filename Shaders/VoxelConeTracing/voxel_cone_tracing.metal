//----------------------------------------------------------------------------------------------//
// A voxel cone tracing implementation for real-time global illumination,                       //
// refraction, specular, glossy and diffuse reflections, and soft shadows.                      //
// The implementation traces cones through a 3D texture which contains a                        //
// direct lit voxelized scene.                                                                  //
//                                                                                              //
// Inspired by "Interactive Indirect Illumination Using Voxel Cone Tracing" by Crassin et al.   //
// (Cyril Crassin, Fabrice Neyret, Miguel Saintz, Simon Green and Elmar Eisemann)               //
// https://research.nvidia.com/sites/default/files/publications/GIVoxels-pg2011-authors.pdf     //
//                                                                                              //
// Original GLSL Author:  Fredrik Präntare <prantare@gmail.com>                                 //
// Metal Autthor:         Le Hoang Quyen (lehoangq@gmail.com)                                   //
//                                                                                              //
//----------------------------------------------------------------------------------------------//

#include <metal_stdlib>
#include <simd/simd.h>

#include "../common.metal"

using namespace metal;

struct VS_out
{
    float3 worldPosition [[user(locn0)]];
    float3 normal [[user(locn1)]];
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
    out.normal = normalize(float3x3(transform.invTransM[0].xyz, transform.invTransM[1].xyz, transform.invTransM[2].xyz) * float3(in.normal));
    out.gl_Position = (appState.P * appState.V) * float4(out.worldPosition, 1.0);
    return out;
}

#define TSQRT2 2.828427
#define SQRT2 1.414213
#define ISQRT2 0.707106
// --------------------------------------
// Light (voxel) cone tracing settings.
// --------------------------------------
#define MIPMAP_HARDCAP 5.4f /* Too high mipmap levels => glitchiness, too low mipmap levels => sharpness. */
#define VOXEL_SIZE (1/64.0) /* Size of a voxel. 128x128x128 => 1/128 = 0.0078125. */
#define SHADOWS 1 /* Shadow cone tracing. */
#define DIFFUSE_INDIRECT_FACTOR 0.52f /* Just changes intensity of diffuse indirect lighting. */
// --------------------------------------
// Other lighting settings.
// --------------------------------------
#define SPECULAR_MODE 1 /* 0 == Blinn-Phong (halfway vector), 1 == reflection model. */
#define SPECULAR_FACTOR 4.0f /* Specular intensity tweaking factor. */
#define SPECULAR_POWER 65.0f /* Specular power in Blinn-Phong. */
#define DIRECT_LIGHT_INTENSITY 0.96f /* (direct) point light intensity factor. */

// Lighting attenuation factors. See the function "attenuate" (below) for more information.
#define DIST_FACTOR 1.1f /* Distance is multiplied by this when calculating attenuation. */
#define CONSTANT 1
#define LINEAR 0 /* Looks meh when using gamma correction. */
#define QUADRATIC 1

// Other settings.
#define GAMMA_CORRECTION 1 /* Whether to use gamma correction or not. */

// Returns an attenuation factor given a distance.
static inline
float attenuate(float dist){ dist *= DIST_FACTOR; return 1.0f / (CONSTANT + LINEAR * dist + QUADRATIC * dist * dist); }

// Returns a vector that is orthogonal to u.
static inline
float3 orthogonal(float3 u){
    u = normalize(u);
    float3 v = float3(0.99146, 0.11664, 0.05832); // Pick any normalized vector.
    return abs(dot(u, v)) > 0.99999f ? cross(u, float3(0, 1, 0)) : cross(u, v);
}

// Scales and bias a given vector (i.e. from [-1, 1] to [0, 1]).
static inline
float3 scaleAndBias(const float3 p) { return 0.5f * p + float3(0.5f); }

// Returns a soft shadow blend by using shadow cone tracing.
// Uses 2 samples per step, so it's pretty expensive.
static inline
float traceShadowCone(VS_out in, float3 direction, float targetDistance, texture3d<float> texture3D){
    const float3 normal = in.normal;
    float3 from = in.worldPosition;
    from += normal * 0.05f; // Removes artifacts but makes self shadowing for dense meshes meh.

    float acc = 0;

    float dist = 3 * VOXEL_SIZE;
    // I'm using a pretty big margin here since I use an emissive light ball with a pretty big radius in my demo scenes.
    const float STOP = targetDistance - 16 * VOXEL_SIZE;

    while(dist < STOP && acc < 1){
        float3 c = from + dist * direction;
        c = scaleAndBias(c);
        if(!isInsideCube(c, 0)) break;
        float l = pow(dist, 2); // Experimenting with inverse square falloff for shadows.
        float s1 = 0.5 * textureLod(texture3D, c, l).a;
        float s2 = 0.03 * textureLod(texture3D, c, 2 * l).a;
        float s = s1 + s2;
        acc += (1 - acc) * s;
        dist += 0.9 * VOXEL_SIZE * (1 + 0.05 * l);
    }
    return 1 - pow(smoothstep(0, 1, acc * 1.4), 1.0 / 1.4);
}

// Traces a diffuse voxel cone.
static inline
float3 traceDiffuseVoxelCone(const float3 from, float3 direction, texture3d<float> texture3D){
    direction = normalize(direction);

    const float CONE_SPREAD = 0.325;

    float4 acc = float4(0.0f);

    // Controls bleeding from close surfaces.
    // Low values look rather bad if using shadow cone tracing.
    // Might be a better choice to use shadow maps and lower this value.
    float dist = 0.1953125;

    // Trace.
    while(dist < SQRT2 && acc.a < 1){
        float3 c = from + dist * direction;
        c = scaleAndBias(c);
        if(!isInsideCube(c, 0)) break;
        float radius = (2 * CONE_SPREAD * dist / VOXEL_SIZE);
        float level = log2(radius);
        float4 voxel = textureLod(texture3D, c, min(MIPMAP_HARDCAP, level));
        acc += attenuate(dist) * voxel * pow(1 - voxel.a, 2);
        dist += radius * VOXEL_SIZE;
    }
    return pow(acc.rgb * 2.0, float3(1.5));
}

// Calculates indirect diffuse light using voxel cone tracing.
// The current implementation uses 9 cones. I think 5 cones should be enough, but it might generate
// more aliasing and bad blur.
static inline
float3 indirectDiffuseLight(VS_out in, texture3d<float> texture3D, constant ObjectState &objectState){
    const float ANGLE_MIX = 0.5f; // Angle mix (1.0f => orthogonal direction, 0.0f => direction of normal).

    const float w[3] = {1.0, 1.0, 1.0}; // Cone weights.

    const float3 normal = in.normal;

    // Find a base for the side cones with the normal as one of its base vectors.
    const float3 ortho = normalize(orthogonal(normal));
    const float3 ortho2 = normalize(cross(ortho, normal));

    // Find base vectors for the corner cones too.
    const float3 corner = 0.5f * (ortho + ortho2);
    const float3 corner2 = 0.5f * (ortho - ortho2);

    // Find start position of trace (start with a bit of offset).
    const float3 N_OFFSET = normal * (1 + 4 * ISQRT2) * VOXEL_SIZE;
    const float3 C_ORIGIN = in.worldPosition + N_OFFSET;

    // Accumulate indirect diffuse light.
    float3 acc = float3(0);

    // We offset forward in normal direction, and backward in cone direction.
    // Backward in cone direction improves GI, and forward direction removes
    // artifacts.
    const float CONE_OFFSET = -0.01;

    // Trace front cone
    acc += w[0] * traceDiffuseVoxelCone(C_ORIGIN + CONE_OFFSET * normal, normal, texture3D);

    // Trace 4 side cones.
    const float3 s1 = mix(normal, ortho, ANGLE_MIX);
    const float3 s2 = mix(normal, -ortho, ANGLE_MIX);
    const float3 s3 = mix(normal, ortho2, ANGLE_MIX);
    const float3 s4 = mix(normal, -ortho2, ANGLE_MIX);

    acc += w[1] * traceDiffuseVoxelCone(C_ORIGIN + CONE_OFFSET * ortho, s1, texture3D);
    acc += w[1] * traceDiffuseVoxelCone(C_ORIGIN - CONE_OFFSET * ortho, s2, texture3D);
    acc += w[1] * traceDiffuseVoxelCone(C_ORIGIN + CONE_OFFSET * ortho2, s3, texture3D);
    acc += w[1] * traceDiffuseVoxelCone(C_ORIGIN - CONE_OFFSET * ortho2, s4, texture3D);

    // Trace 4 corner cones.
    const float3 c1 = mix(normal, corner, ANGLE_MIX);
    const float3 c2 = mix(normal, -corner, ANGLE_MIX);
    const float3 c3 = mix(normal, corner2, ANGLE_MIX);
    const float3 c4 = mix(normal, -corner2, ANGLE_MIX);

    acc += w[2] * traceDiffuseVoxelCone(C_ORIGIN + CONE_OFFSET * corner, c1, texture3D);
    acc += w[2] * traceDiffuseVoxelCone(C_ORIGIN - CONE_OFFSET * corner, c2, texture3D);
    acc += w[2] * traceDiffuseVoxelCone(C_ORIGIN + CONE_OFFSET * corner2, c3, texture3D);
    acc += w[2] * traceDiffuseVoxelCone(C_ORIGIN - CONE_OFFSET * corner2, c4, texture3D);

    // Return result.
    return DIFFUSE_INDIRECT_FACTOR * objectState.material.diffuseReflectivity * acc * (objectState.material.diffuseColor + float3(0.001f));
}

// Traces a specular voxel cone.
static inline
float3 traceSpecularVoxelCone(VS_out in, float3 direction, texture3d<float> texture3D, constant ObjectState &objectState){
    const float3 normal = in.normal;

    const float OFFSET = 8 * VOXEL_SIZE;
    const float STEP = VOXEL_SIZE;

    float3 from = in.worldPosition;
    from += OFFSET * normal;

    float4 acc = float4(0.0f);
    float dist = OFFSET;

    // Trace.
    while(dist < SQRT2 && acc.a < 1){
        float3 c = from + dist * direction;
        c = scaleAndBias(c);
        if(!isInsideCube(c, 0)) break;

        float level = 0.1 * objectState.material.specularDiffusion * log2(1 + dist / VOXEL_SIZE);
        float4 voxel = textureLod(texture3D, c, min(level, MIPMAP_HARDCAP));
        float f = 1 - acc.a;
        acc.rgb += attenuate(dist) * 0.25 * (1 + objectState.material.specularDiffusion) * voxel.rgb * voxel.a * f;
        acc.a += 0.25 * voxel.a * f;
        dist += STEP * (1.0f + 0.125f * level);
    }
    return 1.0 * pow(objectState.material.specularDiffusion + 1, 0.8) * acc.rgb;
}

// Calculates indirect specular light using voxel cone tracing.
static inline
float3 indirectSpecularLight(VS_out in, float3 viewDirection, texture3d<float> texture3D, constant ObjectState &objectState){
    const float3 normal = in.normal;
    const float3 reflection = normalize(reflect(viewDirection, normal));
    return objectState.material.specularReflectivity * objectState.material.specularColor *
           traceSpecularVoxelCone(in, reflection, texture3D, objectState);
}

// Calculates refractive light using voxel cone tracing.
static inline
float3 indirectRefractiveLight(VS_out in, float3 viewDirection, texture3d<float> texture3D, constant ObjectState &objectState){
    const float3 normal = in.normal;
    const float3 refraction = normalize(refract(viewDirection, normal, 1.0 / objectState.material.refractiveIndex));
    const float3 cmix = mix(objectState.material.specularColor, 0.5 * (objectState.material.specularColor + float3(1)),
                            objectState.material.transparency);
    return cmix * traceSpecularVoxelCone(in, refraction, texture3D, objectState);
}

// Calculates diffuse and specular direct light for a given point light.
// Uses shadow cone tracing for soft shadows.
static inline
float3 calculateDirectLight(VS_out in, PointLight light, const float3 viewDirection,
                            texture3d<float> texture3D,
                            constant AppState &appState,
                            constant ObjectState &objectState)
{
    const float3 normal = in.normal;
    float3 lightDirection = light.position - in.worldPosition;
    const float distanceToLight = length(lightDirection);
    lightDirection = lightDirection / distanceToLight;
    const float lightAngle = dot(normal, lightDirection);

    // --------------------
    // Diffuse lighting.
    // --------------------
    float diffuseAngle = max(lightAngle, 0.0f); // Lambertian.

    // --------------------
    // Specular lighting.
    // --------------------
#if (SPECULAR_MODE == 0) /* Blinn-Phong. */
    const float3 halfwayVector = normalize(lightDirection + viewDirection);
    float specularAngle = max(dot(normal, halfwayVector), 0.0f);
#endif

#if (SPECULAR_MODE == 1) /* Perfect reflection. */
    const float3 reflection = normalize(reflect(viewDirection, normal));
    float specularAngle = max(0.0, dot(reflection, lightDirection));
#endif

    float refractiveAngle = 0;
    if(objectState.material.transparency > 0.01){
        float3 refraction = refract(viewDirection, normal, 1.0 / objectState.material.refractiveIndex);
        refractiveAngle = max(0.0, objectState.material.transparency * dot(refraction, lightDirection));
    }

    // --------------------
    // Shadows.
    // --------------------
    float shadowBlend = 1;
#if (SHADOWS == 1)
    if(diffuseAngle * (1.0f - objectState.material.transparency) > 0 && appState.settings.shadows)
        shadowBlend = traceShadowCone(in, lightDirection, distanceToLight, texture3D);
#endif

    // --------------------
    // Add it all together.
    // --------------------
    diffuseAngle = min(shadowBlend, diffuseAngle);
    specularAngle = min(shadowBlend, max(specularAngle, refractiveAngle));
    const float df = 1.0f / (1.0f + 0.25f * objectState.material.specularDiffusion); // Diffusion factor.
    const float specular = SPECULAR_FACTOR * pow(specularAngle, df * SPECULAR_POWER);
    const float diffuse = diffuseAngle * (1.0f - objectState.material.transparency);

    const float3 diff = objectState.material.diffuseReflectivity * objectState.material.diffuseColor * diffuse;
    const float3 spec = objectState.material.specularReflectivity * objectState.material.specularColor * specular;
    const float3 total = light.color * (diff + spec);
    return attenuate(distanceToLight) * total;
}

// Sums up all direct light from point lights (both diffuse and specular).
static inline
float3 directLight(VS_out in, const float3 viewDirection,
                   texture3d<float> texture3D,
                   constant AppState &appState,
                   constant ObjectState &objectState){
    float3 direct = float3(0.0f);
    const uint maxLights = min(appState.numberOfLights, MAX_LIGHTS);
    for (uint i = 0; i < maxLights; ++i)
        direct += calculateDirectLight(in, appState.pointLights[i], viewDirection, texture3D, appState, objectState);
    direct *= DIRECT_LIGHT_INTENSITY;
    return direct;
}

fragment float4 FS(VS_out input [[stage_in]],
                   texture3d<float> texture3D [[texture(2)]],
                   constant AppState& appState APPSTATE_BINDING,
                   constant ObjectState &objectState OBJECT_STATE_BINDING)
{
    VS_out in = input;
    in.normal = normalize(in.normal);

    float4 color = float4(0, 0, 0, 1);
    const float3 viewDirection = normalize(in.worldPosition - appState.cameraPosition);

#if 1
    // Indirect diffuse light.
    if(appState.settings.indirectDiffuseLight &&
       objectState.material.diffuseReflectivity * (1.0f - objectState.material.transparency) > 0.01f)
        color.rgb += indirectDiffuseLight(in, texture3D, objectState);

    // Indirect specular light (glossy reflections).
    if(appState.settings.indirectSpecularLight &&
       objectState.material.specularReflectivity * (1.0f - objectState.material.transparency) > 0.01f)
        color.rgb += indirectSpecularLight(in, viewDirection, texture3D, objectState);

    // Emissivity.
    color.rgb += objectState.material.emissivity * objectState.material.diffuseColor;

    // Transparency
    if(objectState.material.transparency > 0.01f)
        color.rgb = mix(color.rgb,
                        indirectRefractiveLight(in, viewDirection, texture3D, objectState), objectState.material.transparency);
#endif

    // Direct light.
    if(appState.settings.directLight)
        color.rgb += directLight(in, viewDirection, texture3D, appState, objectState);

#if (GAMMA_CORRECTION == 1)
    color.rgb = pow(color.rgb, float3(1.0 / 2.2));
#endif

    return color;
}
