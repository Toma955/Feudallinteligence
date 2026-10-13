#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Voda: prozirno tijelo i gornja koža s valovima i odsjajem.

struct RiverNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};

struct RiverVertexIn {
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal [[attribute(SCNVertexSemanticNormal)]];
};

struct RiverVertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 worldNormal;
};

vertex RiverVertexOut feudalismRiverVertex(RiverVertexIn in [[stage_in]],
                                           constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                           constant RiverNodeBuffer& scn_node [[buffer(1)]]) {
    float t = scn_frame.time;
    float2 uv = in.position.xy;
    float h = sin(uv.x * 4.8 + t * 1.05) * 0.04;
    h += sin(uv.y * 3.6 - t * 0.8) * 0.032;
    h += sin((uv.x + uv.y) * 8.5 + t * 1.5) * 0.014;
    float dhdx = cos(uv.x * 4.8 + t * 1.05) * 4.8 * 0.04;
    dhdx += cos((uv.x + uv.y) * 8.5 + t * 1.5) * 8.5 * 0.014;
    float dhdy = cos(uv.y * 3.6 - t * 0.8) * 3.6 * 0.032;
    dhdy += cos((uv.x + uv.y) * 8.5 + t * 1.5) * 8.5 * 0.014;

    float3 pos = in.position;
    pos.z += h;
    float3 localN = normalize(float3(-dhdx, -dhdy, 1.0));

    RiverVertexOut out;
    float4 world = scn_node.modelTransform * float4(pos, 1.0);
    out.position = scn_frame.viewProjectionTransform * world;
    out.worldPos = world.xyz;
    out.worldNormal = normalize((scn_node.modelTransform * float4(localN, 0.0)).xyz);
    return out;
}

static float4 waterSurface(RiverVertexOut in, constant SCNSceneBuffer& scn_frame, bool sea) {
    float3 cam = (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
    float3 view = normalize(cam - in.worldPos);
    float3 n = normalize(in.worldNormal);
    float facing = saturate(dot(n, view));
    float fresnel = pow(1.0 - facing, 2.2);
    float3 sun = normalize(float3(0.4, 0.82, 0.28));
    float3 reflectDir = reflect(-sun, n);
    float spec = pow(saturate(dot(reflectDir, view)), 36.0);

    float3 body = sea ? float3(0.05, 0.22, 0.48) : float3(0.42, 0.74, 0.94);
    float3 skin = sea ? float3(0.62, 0.80, 0.92) : float3(0.86, 0.95, 1.0);
    float3 rgb = mix(body, skin, fresnel);
    rgb += spec * float3(0.9, 0.95, 1.0);
    float clear = sea ? 0.46 : 0.30;
    float rim = sea ? 0.82 : 0.68;
    float alpha = mix(clear, rim, fresnel) + spec * 0.22;
    return float4(saturate(rgb), saturate(alpha));
}

fragment float4 feudalismRiverFragment(RiverVertexOut in [[stage_in]],
                                       constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    return waterSurface(in, scn_frame, false);
}

fragment float4 feudalismSeaFragment(RiverVertexOut in [[stage_in]],
                                     constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    return waterSurface(in, scn_frame, true);
}
