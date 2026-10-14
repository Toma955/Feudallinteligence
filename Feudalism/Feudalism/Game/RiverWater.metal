#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Feudalism voda (rijeka + more): SceneKit custom Metal program.
// Lokalni prostor mape: XZ tlocrt, Z = visina (teren je rotiran -90° oko X).

struct RiverNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};

struct RiverVertexIn {
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal   [[attribute(SCNVertexSemanticNormal)]];
};

struct RiverVertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 worldNormal;
    float  wavePeak;   // 0..1 — pjena na vrhovima
    float  seaFlag;    // 1 = more, 0 = rijeka
};

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise21(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Gerstner-ish valovi: pomak visine + nagib normale. `amp` jača more.
static RiverVertexOut waterVertex(RiverVertexIn in,
                                  constant SCNSceneBuffer& scn_frame,
                                  constant RiverNodeBuffer& scn_node,
                                  float amp,
                                  float seaFlag) {
    float t = scn_frame.time;
    // Tlocrt u lokalnom prostoru (x, y≈-mapZ).
    float2 xz = in.position.xy;

    // Više frekvencija — more je šire i sporije od rijeke.
    float s = seaFlag > 0.5 ? 1.0 : 1.35;
    float2 d1 = normalize(float2(1.0, 0.35));
    float2 d2 = normalize(float2(-0.55, 1.0));
    float2 d3 = normalize(float2(0.25, -0.95));
    float2 d4 = normalize(float2(-0.9, -0.4));

    float k1 = 1.15 * s, a1 = 0.055 * amp, w1 = 1.05;
    float k2 = 1.85 * s, a2 = 0.038 * amp, w2 = 1.35;
    float k3 = 3.40 * s, a3 = 0.018 * amp, w3 = 1.90;
    float k4 = 0.55 * s, a4 = 0.070 * amp, w4 = 0.55;

    float p1 = dot(xz, d1) * k1 + t * w1;
    float p2 = dot(xz, d2) * k2 - t * w2;
    float p3 = dot(xz, d3) * k3 + t * w3;
    float p4 = dot(xz, d4) * k4 + t * w4;

    float h = a1 * sin(p1) + a2 * sin(p2) + a3 * sin(p3) + a4 * sin(p4);
    // Sitni šum za „nemir”.
    h += (noise21(xz * 0.35 + t * 0.08) - 0.5) * (0.012 * amp);

    // Derivacije za normalu (∂h/∂x, ∂h/∂y).
    float dhdx = a1 * cos(p1) * k1 * d1.x
               + a2 * cos(p2) * k2 * d2.x
               + a3 * cos(p3) * k3 * d3.x
               + a4 * cos(p4) * k4 * d4.x;
    float dhdy = a1 * cos(p1) * k1 * d1.y
               + a2 * cos(p2) * k2 * d2.y
               + a3 * cos(p3) * k3 * d3.y
               + a4 * cos(p4) * k4 * d4.y;

    float3 pos = in.position;
    pos.z += h;
    // Lokalna normala: gore = +Z.
    float3 localN = normalize(float3(-dhdx, -dhdy, 1.0));

    float peak = saturate(0.5 + 0.5 * (sin(p1) * 0.45 + sin(p4) * 0.55));

    RiverVertexOut out;
    float4 world = scn_node.modelTransform * float4(pos, 1.0);
    out.position = scn_frame.viewProjectionTransform * world;
    out.worldPos = world.xyz;
    out.worldNormal = normalize((scn_node.modelTransform * float4(localN, 0.0)).xyz);
    out.wavePeak = peak;
    out.seaFlag = seaFlag;
    return out;
}

vertex RiverVertexOut feudalismRiverVertex(RiverVertexIn in [[stage_in]],
                                           constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                           constant RiverNodeBuffer& scn_node [[buffer(1)]]) {
    return waterVertex(in, scn_frame, scn_node, 1.0, 0.0);
}

vertex RiverVertexOut feudalismSeaVertex(RiverVertexIn in [[stage_in]],
                                         constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                         constant RiverNodeBuffer& scn_node [[buffer(1)]]) {
    return waterVertex(in, scn_frame, scn_node, 2.1, 1.0);
}

static float4 waterFragment(RiverVertexOut in, constant SCNSceneBuffer& scn_frame) {
    bool sea = in.seaFlag > 0.5;
    float3 cam = (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
    float3 view = normalize(cam - in.worldPos);
    float3 n = normalize(in.worldNormal);
    float facing = saturate(dot(n, view));
    float fresnel = pow(1.0 - facing, sea ? 2.6 : 2.2);

    float3 sun = normalize(float3(0.45, 0.75, 0.35));
    float3 reflectDir = reflect(-sun, n);
    float spec = pow(saturate(dot(reflectDir, view)), sea ? 64.0 : 36.0);
    // Široki glitter.
    float glitter = pow(saturate(dot(reflectDir, view)), 12.0) * 0.35;

    // Plavo more / svjetlija rijeka.
    float3 deep  = sea ? float3(0.02, 0.12, 0.42) : float3(0.22, 0.48, 0.72);
    float3 body  = sea ? float3(0.08, 0.36, 0.78) : float3(0.40, 0.72, 0.92);
    float3 skin  = sea ? float3(0.42, 0.70, 0.98) : float3(0.82, 0.94, 1.00);
    float3 foam  = float3(0.85, 0.93, 1.00);

    float3 rgb = mix(deep, body, facing * 0.7 + 0.3);
    rgb = mix(rgb, skin, fresnel * 0.85);
    // Pjena na vrhovima valova (more).
    if (sea) {
        float foamAmt = smoothstep(0.62, 0.92, in.wavePeak) * (0.25 + fresnel * 0.2);
        rgb = mix(rgb, foam, foamAmt);
    }
    rgb += spec * (sea ? float3(0.90, 0.96, 1.0) : float3(0.85, 0.92, 1.0));
    rgb += glitter * float3(0.7, 0.85, 1.0);

    // Prozirnost: more jasnije u sredini, gušće na rubu (fresnel).
    float clear = sea ? 0.38 : 0.28;
    float rim   = sea ? 0.78 : 0.65;
    float alpha = mix(clear, rim, fresnel) + spec * 0.12;
    alpha = saturate(alpha);

    return float4(saturate(rgb), alpha);
}

fragment float4 feudalismRiverFragment(RiverVertexOut in [[stage_in]],
                                       constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    return waterFragment(in, scn_frame);
}

fragment float4 feudalismSeaFragment(RiverVertexOut in [[stage_in]],
                                     constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    return waterFragment(in, scn_frame);
}
