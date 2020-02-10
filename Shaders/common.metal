using namespace metal;

// Lighting settings.
#define POINT_LIGHT_INTENSITY 1
#define MAX_LIGHTS 1

struct PointLight {
    packed_float3 position;
    packed_float3 color;
};

struct Material {
    packed_float3 diffuseColor;
    packed_float3 specularColor;
    float specularReflectivity;
    float diffuseReflectivity;
    float emissivity;
    float specularDiffusion;
    float transparency;
    float refractiveIndex;
};

struct Settings {
    bool indirectSpecularLight; // Whether indirect specular light should be rendered or not.
    bool indirectDiffuseLight; // Whether indirect diffuse light should be rendered or not.
    bool directLight; // Whether direct light should be rendered or not.
    bool shadows; // Whether shadows should be rendered or not.
};

struct AppState
{
    Settings settings;
    PointLight pointLights[MAX_LIGHTS];
    int numberOfLights;

    // camera transform matrix
    float4x4 V;
    float4x4 P;
    packed_float3 cameraPosition;

    // Debug state
    int state;
};

struct ObjectState
{
    // object's world transform
    float4x4 M;
    float4x4 invTransM;
    Material material;
};

#define TRANSFORM_BINDING [[buffer(0)]]
#define OBJECT_STATE_BINDING TRANSFORM_BINDING
#define APPSTATE_BINDING [[buffer(1)]]
#define VOXEL_PROJ_BINDING_IDX 2
#define VERTEX_BUFFER_BINDING [[buffer(8)]]
#define INDEX_BUFFER_BINDING [[buffer(9)]]
#define TRI_DOMINANT_BUFFER_BINDING_IDX 10
#define TRI_DOMINANT_BUFFER_BINDING [[buffer(TRI_DOMINANT_BUFFER_BINDING_IDX)]]
#define COMPUTE_PARAM_START_IDX 16

constant bool kReadWriteTextureSupported[[function_constant(0)]];
constant bool kReadWriteTextureNotSupported = !kReadWriteTextureSupported;

static constexpr sampler gCommonTextureSampler (mag_filter::linear, min_filter::linear, mip_filter::linear,
                                                s_address::repeat,
                                                r_address::repeat,
                                                t_address::repeat);


static inline
float4 worldTransform(constant ObjectState &transform, float4 pos)
{
    return (transform.M * pos);
}


// Returns true if the point p is inside the unity cube.
static inline
bool isInsideCube(const float3 p, float e) { return abs(p.x) < 1 + e && abs(p.y) < 1 + e && abs(p.z) < 1 + e; }

// This function sample a 3D texture and return transparent black if coordinates are out of bound
float4 textureLod(texture3d<float> texture3D, float3 coordinate, float mipmapLevel)
{
#if __METAL_MACOS__
    constexpr sampler texture3DSampler (mag_filter::linear, min_filter::linear, mip_filter::linear,
                                        s_address::clamp_to_edge,
                                        r_address::clamp_to_edge,
                                        t_address::clamp_to_edge,
                                        border_color::transparent_black);

    return texture3D.sample(texture3DSampler, coordinate, level(mipmapLevel));
#else
    constexpr sampler texture3DSampler (mag_filter::linear, min_filter::linear, mip_filter::linear,
                                        s_address::clamp_to_edge,
                                        r_address::clamp_to_edge,
                                        t_address::clamp_to_edge);
    if (isInsideCube(coordinate, 0))
    {
        float4 currentSample = texture3D.sample(texture3DSampler, coordinate, level(mipmapLevel));
        return currentSample;
    }
    return float4(0, 0, 0, 0);
#endif
}

float4 textureLodNearest(texture3d<float> texture3D, float3 coordinate, float mipmapLevel)
{
#if __METAL_MACOS__
    constexpr sampler texture3DSampler (mag_filter::nearest, min_filter::nearest, mip_filter::nearest,
                                        s_address::clamp_to_edge,
                                        r_address::clamp_to_edge,
                                        t_address::clamp_to_edge,
                                        border_color::transparent_black);

    return texture3D.sample(texture3DSampler, coordinate, level(mipmapLevel));
#else
    constexpr sampler texture3DSampler (mag_filter::nearest, min_filter::nearest, mip_filter::nearest,
                                        s_address::clamp_to_edge,
                                        r_address::clamp_to_edge,
                                        t_address::clamp_to_edge);
    if (isInsideCube(coordinate, 0))
    {
        float4 currentSample = texture3D.sample(texture3DSampler, coordinate, level(mipmapLevel));
        return currentSample;
    }
    return float4(0, 0, 0, 0);
#endif
}
