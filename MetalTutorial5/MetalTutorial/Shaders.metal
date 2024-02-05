#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float2 texCoord;
    float3 normal;
};

vertex VertexOut vertexFunction(Vertex in [[stage_in]], constant float4x4& projectionMatrix [[buffer(0)]], constant float4x4& viewMatrix [[buffer(1)]], constant float4x4& modelMatrix [[buffer(2)]]) {
    VertexOut out;
    out.worldPosition = (modelMatrix * float4(in.position, 1.0)).xyz;
    out.position = projectionMatrix * viewMatrix * float4(out.worldPosition, 1.0);
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    
    return out;
}

constant float3 lightDirection = float3(0.436436, -0.872872, 0.218218);
constant float3 lightAmbient = float3(0.2);
constant float3 lightDiffuse = float3(1.0);
constant float3 lightSpecular = float3(0.5);

inline float3 phongLighting(float3 worldPosition, float3 diffuseColor, float3 normal, float3 viewPosition) {
    //Ambient
    float3 ambient = lightAmbient * diffuseColor;
    
    //Diffuse
    float3 diff = max(dot(normal, -lightDirection), 0.0);
    float3 diffuse = lightDiffuse * diff * diffuseColor;
    
    //Specular
    float3 viewDir = normalize(viewPosition - worldPosition);
    float3 reflectDir = reflect(lightDirection, normal);
    float3 spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    float3 specular = lightSpecular * spec;
    
    return ambient + diffuse + specular;
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]], constant float3& viewPosition [[buffer(0)]], texture2d<float> diffuseTexture [[texture(0)]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

    float4 diffuseColor = diffuseTexture.sample(colorSampler, in.texCoord);
    
    return float4(phongLighting(in.worldPosition, diffuseColor.rgb, normalize(in.normal), viewPosition), 1.0);
}
