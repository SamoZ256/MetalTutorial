#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 normal [[attribute(2)]];
    float4 tangent [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float2 texCoord;
    float3 T, B, N;
};

struct ModelMatrix {
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

vertex VertexOut vertexFunction(Vertex in [[stage_in]], constant float4x4& viewProjMatrix [[buffer(0)]], constant ModelMatrix& model [[buffer(1)]]) {
    VertexOut out;
    out.worldPosition = (model.modelMatrix * float4(in.position, 1.0)).xyz;
    out.position = viewProjMatrix * float4(out.worldPosition, 1.0);
    out.texCoord = in.texCoord;
    
    // Create the TBN vectors
    float3 T = normalize(model.normalMatrix * in.tangent.xyz);
    float3 N = normalize(model.normalMatrix * in.normal);
    // Gram-Schmidt process, can improve the results slightly if the TBN vectors aren't perpendicular
    T = normalize(T - dot(T, N) * N);
    float3 B = cross(N, T) * in.tangent.w;
    
    out.T = T;
    out.B = B;
    out.N = N;
    
    return out;
}

constant float3 lightDirection = float3(0.436436, -0.872872, 0.218218);
constant float3 lightAmbient = float3(0.4);
constant float3 lightDiffuse = float3(1.0);
constant float3 lightSpecular = float3(0.8);

inline float3 phongLighting(float3 worldPosition, float3 diffuseColor, float specularColor, float3 normal, float3 viewPosition, float visibility) {
    //Ambient
    float3 ambient = lightAmbient * diffuseColor;
    
    //Diffuse
    float3 diff = max(dot(normal, -lightDirection), 0.0);
    float3 diffuse = lightDiffuse * diff * diffuseColor;
    
    //Specular
    float3 viewDir = normalize(viewPosition - worldPosition);
    float3 reflectDir = reflect(lightDirection, normal);
    float3 spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    float3 specular = lightSpecular * spec * specularColor;
    
    return ambient + (diffuse + specular) * visibility;
}

struct MaterialInfo {
    bool hasDiffuseTexture;
    bool hasSpecularTexture;
    bool hasNormalTexture;
};

// Shadow constants
constant float SHADOW_BIAS = 0.001;
constant int SHADOW_SAMPLE_COUNT = 16;
constant float SHADOW_PENUMBRA_SIZE = 2.0;

constant float2 poissonDisk[16] = {
    float2( -0.94201624, -0.39906216 ),
    float2( 0.94558609, -0.76890725 ),
    float2( -0.094184101, -0.92938870 ),
    float2( 0.34495938, 0.29387760 ),
    float2( -0.91588581, 0.45771432 ),
    float2( -0.81544232, -0.87912464 ),
    float2( -0.38277543, 0.27676845 ),
    float2( 0.97484398, 0.75648379 ),
    float2( 0.44323325, -0.97511554 ),
    float2( 0.53742981, -0.47373420 ),
    float2( -0.26496911, -0.41893023 ),
    float2( 0.79197514, 0.19090188 ),
    float2( -0.24188840, 0.99706507 ),
    float2( -0.81409955, 0.91437590 ),
    float2( 0.19984126, 0.78641367 ),
    float2( 0.14383161, -0.14100790 )
};

// Random number generator
float random(float3 seed, int i) {
    float dotProduct = dot(float4(seed, i), float4(12.9898, 78.233, 45.164, 94.673));
    return fract(sin(dotProduct) * 43758.5453);
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]], constant float3& viewPosition [[buffer(0)]], constant float4x4& lightViewProjMatrix [[buffer(1)]], constant MaterialInfo& materialInfo [[buffer(2)]], depth2d<float> shadowMap [[texture(0)]], texture2d<float> diffuseTexture [[texture(1)]], texture2d<float> specularTexture [[texture(2)]], texture2d<float> normalTexture [[texture(3)]], sampler shadowSampler [[sampler(0)]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear, address::repeat);

    float4 diffuseColor  = (materialInfo.hasDiffuseTexture ? diffuseTexture.sample(colorSampler, in.texCoord) : float4(1.0));
    float specularColor = (materialInfo.hasSpecularTexture ? specularTexture.sample(colorSampler, in.texCoord).r : 1.0);
    float3 tangentSpaceNormal = (materialInfo.hasNormalTexture ? normalTexture.sample(colorSampler, in.texCoord).rgb : float3(0.5, 0.5, 1.0));
    
    // Calculate the normal
    tangentSpaceNormal = normalize(tangentSpaceNormal * 2.0 - 1.0); // Transform from [0...1] to [-1...1]
    float3x3 TBN = float3x3(in.T, in.B, in.N);
    float3 normal = normalize(TBN * tangentSpaceNormal);
    
    // Shadow
    float4 positionInLightSpace = lightViewProjMatrix * float4(in.worldPosition, 1.0);
    positionInLightSpace.xyz /= positionInLightSpace.w;
    float2 lightSpaceCoord = positionInLightSpace.xy * 0.5 + 0.5;
    lightSpaceCoord.y = 1.0 - lightSpaceCoord.y;
    
    const float2 texelSize = 1.0 / float2(shadowMap.get_width(), shadowMap.get_height());
    float visibility = 0.0;
    for (int i = 0; i < SHADOW_SAMPLE_COUNT; i++) {
        float2 coord = float2(lightSpaceCoord.xy + normalize(poissonDisk[i]) * random(in.worldPosition, i) * SHADOW_PENUMBRA_SIZE * texelSize);
        visibility += shadowMap.sample_compare(shadowSampler, coord, positionInLightSpace.z - SHADOW_BIAS);
    }
    visibility /= SHADOW_SAMPLE_COUNT;
    
    return float4(phongLighting(in.worldPosition, diffuseColor.rgb, specularColor, normal, viewPosition, visibility), 1.0);
}

vertex float4 shadowVertexFunction(Vertex in [[stage_in]], constant float4x4& viewProjMatrix [[buffer(0)]], constant float4x4& modelMatrix [[buffer(1)]]) {
    float3 worldPosition = (modelMatrix * float4(in.position, 1.0)).xyz;
    float4 position = viewProjMatrix * float4(worldPosition, 1.0);
    
    return position;
}

fragment void shadowFragmentFunction() {}
