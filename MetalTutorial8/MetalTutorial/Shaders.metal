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

vertex VertexOut vertexFunction(Vertex in [[stage_in]], constant float4x4& projectionMatrix [[buffer(0)]], constant float4x4& viewMatrix [[buffer(1)]], constant ModelMatrix& model [[buffer(2)]]) {
    VertexOut out;
    out.worldPosition = (model.modelMatrix * float4(in.position, 1.0)).xyz;
    out.position = projectionMatrix * viewMatrix * float4(out.worldPosition, 1.0);
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

inline float3 phongLighting(float3 worldPosition, float3 diffuseColor, float specularColor, float3 normal, float3 viewPosition) {
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
    
    return ambient + diffuse + specular;
}

struct MaterialInfo {
    bool hasDiffuseTexture;
    bool hasSpecularTexture;
    bool hasNormalTexture;
};

fragment float4 fragmentFunction(VertexOut in [[stage_in]], constant float3& viewPosition [[buffer(0)]], constant MaterialInfo& materialInfo [[buffer(1)]], texture2d<float> diffuseTexture [[texture(0)]], texture2d<float> specularTexture [[texture(1)]], texture2d<float> normalTexture [[texture(2)]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear, address::repeat);

    float4 diffuseColor  = (materialInfo.hasDiffuseTexture ? diffuseTexture.sample(colorSampler, in.texCoord) : float4(1.0));
    float specularColor = (materialInfo.hasSpecularTexture ? specularTexture.sample(colorSampler, in.texCoord).r : 1.0);
    float3 tangentSpaceNormal = (materialInfo.hasNormalTexture ? normalTexture.sample(colorSampler, in.texCoord).rgb : float3(0.5, 0.5, 1.0));
    
    // Calculate the normal
    tangentSpaceNormal = normalize(tangentSpaceNormal * 2.0 - 1.0); // Transform from [0...1] to [-1...1]
    float3x3 TBN = float3x3(in.T, in.B, in.N);
    float3 normal = normalize(TBN * tangentSpaceNormal);
    
    return float4(phongLighting(in.worldPosition, diffuseColor.rgb, specularColor, normal, viewPosition), 1.0);
}
