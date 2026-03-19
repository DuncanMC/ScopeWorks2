//
//  Shaders.metal
//  ScopeWorks2
//
//  Created by Duncan Champney on 3/18/26.
//

#include <metal_stdlib>
using namespace metal;
#define M_PI 3.14159265358979323846

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float rotation;
    float segments;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = positions[vertexID] * 0.5 + 0.5;
    return out;
}

fragment float4 fragment_kaleidoscope(VertexOut in [[stage_in]],
                                     constant Uniforms &u [[buffer(1)]],
                                     texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(address::repeat, filter::linear);
    
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    // Rotation
    float c = cos(u.rotation);
    float s2 = sin(u.rotation);
    uv = float2(uv.x * c - uv.y * s2, uv.x * s2 + uv.y * c);
    
    // Convert to polar + mirror by segment
    float r = length(uv);
    float θ = atan2(uv.y, uv.x);
    float n = max(u.segments, 1.0);
    float angle = 2.0 * M_PI / n;
    θ = fmod(θ, angle * 2.0);
    if (θ > angle) θ = angle * 2.0 - θ;
    
    float2 mirrored = float2(r * cos(θ), r * sin(θ));
    mirrored = mirrored * 0.5 + 0.5;
    
    return tex.sample(s, mirrored);
}

