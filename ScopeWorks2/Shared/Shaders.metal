#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct TrianglePoints {
    float2 point1;
    float2 point2;
    float2 point3;
};

struct Uniforms {
    float4 color;
    bool drawWithTexture;
    bool drawTextureTriangles;
    TrianglePoints trianglePoints;
    float texAspect;
    float4x4 orthoMatrix;
};


vertex VertexOut vertex_main(const device float2* position [[buffer(0)]],
                             constant Uniforms& uniforms [[buffer(1)]],
                             uint vid [[vertex_id]]) {
    VertexOut out;
    float2 pos = position[vid];
//    pos.x /= uniforms.texAspect;
    out.position = uniforms.orthoMatrix * float4(pos, 0, 1);


    // Map each vertex to its corresponding triangle point UV
    float2 triPoints[3] = {
        uniforms.trianglePoints.point1,
        uniforms.trianglePoints.point2,
        uniforms.trianglePoints.point3
    };
    
    out.texCoord = uniforms.drawTextureTriangles ? triPoints[vid % 3] : pos * 0.5 + 0.5; // basic mapping

    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    if (uniforms.drawWithTexture) {
        float2 coord = in.texCoord;
        coord.x /= uniforms.texAspect;
        // Texture co-ord is flipped vertically. flip it back.
//        coord[1] = 1.0 - coord[1];
        return tex.sample(s, coord);
    } else {
        return uniforms.color;
    }
}
