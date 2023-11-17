#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexFunction(Vertex in [[stage_in]], constant float4x4& projectionMatrix [[buffer(0)]], constant float4x4& modelViewMatrix [[buffer(1)]]) {
    VertexOut out;
    out.position = projectionMatrix * modelViewMatrix * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]], texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(colorSampler, in.texCoord);
    
    return float4(color.rgb, 1.0);
}
