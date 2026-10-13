#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Jedna kontinuirana zemlja. Težine dolaze iz splat mape (bilinearno),
// teksture teku preko ćelija iz svjetskih koordinata.

struct EarthUniforms {
    float2 origin;
    float2 mapSize;
    float preview;
    float previewSize;
    float2 pad;
};

struct EarthNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};

struct EarthVertexIn {
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal [[attribute(SCNVertexSemanticNormal)]];
};

struct EarthVertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 worldNormal;
    float3 localPos;
    float3 localNormal;
};

vertex EarthVertexOut feudalismEarthVertex(EarthVertexIn in [[stage_in]],
                                           constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                           constant EarthNodeBuffer& scn_node [[buffer(1)]]) {
    EarthVertexOut out;
    float4 world = scn_node.modelTransform * float4(in.position, 1.0);
    out.position = scn_frame.viewProjectionTransform * world;
    out.worldPos = world.xyz;
    out.worldNormal = normalize((scn_node.modelTransform * float4(in.normal, 0.0)).xyz);
    out.localPos = in.position;
    out.localNormal = in.normal;
    return out;
}

static float earthHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float earthNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = earthHash(i);
    float b = earthHash(i + float2(1.0, 0.0));
    float c = earthHash(i + float2(0.0, 1.0));
    float d = earthHash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float earthFbm(float2 p) {
    return earthNoise(p) * 0.55 + earthNoise(p * 2.13) * 0.3 + earthNoise(p * 4.27) * 0.15;
}

static float2 atlasUV(float2 uv, int index) {
    float slice = 1.0 / 3.0;
    return float2(fract(uv.x) * slice + float(index) * slice, fract(uv.y));
}

static float3 sampleSoil(texture2d<float> atlas, float2 uv, int index) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    return atlas.sample(smp, atlasUV(uv, index)).rgb;
}

static float sampleHeight(texture2d<float> atlas, float2 uv, int index) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    return atlas.sample(smp, atlasUV(uv, index)).a;
}

fragment float4 feudalismEarthFragment(EarthVertexOut in [[stage_in]],
                                       constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                       constant EarthUniforms& earth [[buffer(3)]],
                                       texture2d<float> colors [[texture(0)]]) {
    float2 ground = abs(in.localNormal.y) > 0.6 ? in.localPos.xz : in.worldPos.xz;
    // Ground048 je baza (indeks 2), najmanje oko pola. Druge dvije su rijetke organske mrlje.
    float nA = earthFbm(ground * 0.038);
    float nB = earthFbm(ground * 0.026 + 8.4);
    float w0 = smoothstep(0.57, 0.80, nA);
    float w1 = smoothstep(0.60, 0.82, nB);
    w0 = min(w0, 0.55);
    w1 = min(w1, 0.55);
    float extra = w0 + w1;
    if (extra > 1.05) {
        w0 *= 1.05 / extra;
        w1 *= 1.05 / extra;
    }
    float3 weights = float3(w0, w1, 1.0);
    weights /= max(weights.x + weights.y + weights.z, 1e-4);

    float3 scales = float3(0.22, 0.081, 0.029);
    float3 mixScale = float3(0.55, 0.30, 0.15);
    float3 rgb = float3(0.0);
    for (int i = 0; i < 3; ++i) {
        float ang = 0.4 + float(i) * 1.15;
        float c = cos(ang);
        float s = sin(ang);
        float2 turned = float2(c * ground.x - s * ground.y, s * ground.x + c * ground.y);
        float3 layered = sampleSoil(colors, turned * scales.x, i) * mixScale.x
            + sampleSoil(colors, turned * scales.y, i) * mixScale.y
            + sampleSoil(colors, turned * scales.z, i) * mixScale.z;
        rgb += layered * weights[i];
    }

    float macro = earthFbm(ground * 0.012);
    rgb *= mix(0.80, 1.14, macro);
    rgb = mix(rgb, rgb * float3(1.06, 0.97, 0.88), (macro - 0.5) * 0.35);

    float3 n = normalize(in.worldNormal);
    float light = saturate(dot(n, normalize(float3(0.34, 0.86, 0.28))));
    float3 ambient = max(scn_frame.ambientLightingColor.rgb, float3(0.42, 0.40, 0.36));
    rgb *= ambient + light * float3(0.72, 0.68, 0.60);
    return float4(saturate(rgb), 1.0);
}
