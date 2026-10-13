#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Kamenito tlo: grbavi komadi, pukotine, tamna i svijetla siva.

struct StoneNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};

struct StoneVertexIn {
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal [[attribute(SCNVertexSemanticNormal)]];
};

struct StoneVertexOut {
    float4 position [[position]];
    float3 localPos;
    float3 localNormal;
    float3 worldNormal;
};

vertex StoneVertexOut feudalismStoneVertex(StoneVertexIn in [[stage_in]],
                                           constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                           constant StoneNodeBuffer& scn_node [[buffer(1)]]) {
    StoneVertexOut out;
    float4 world = scn_node.modelTransform * float4(in.position, 1.0);
    out.position = scn_frame.viewProjectionTransform * world;
    out.localPos = in.position;
    out.localNormal = in.normal;
    out.worldNormal = normalize((scn_node.modelTransform * float4(in.normal, 0.0)).xyz);
    return out;
}

static float stoneHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

struct RockSample {
    float crack;
    float height;
    float2 slope;
};

static RockSample sampleRock(float2 xz, float cell) {
    float2 g = xz / cell;
    float2 origin = floor(g);
    float best = 8.0;
    float second = 8.0;
    float height = 0.5;
    float2 slope = float2(0.0);
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            float2 id = origin + float2(i, j);
            float2 jitter = float2(stoneHash(id), stoneHash(id + 19.2));
            float2 center = id + 0.12 + jitter * 0.76;
            float d = length(g - center);
            float h = stoneHash(id + 4.4);
            if (d < best) {
                second = best;
                best = d;
                height = h;
                slope = (g - center) / max(d, 0.001);
            } else if (d < second) {
                second = d;
            }
        }
    }
    RockSample sample;
    sample.crack = smoothstep(0.02, 0.16, second - best);
    sample.height = height;
    sample.slope = slope;
    return sample;
}

static float4 shadeRock(float2 xz, float3 dark, float3 mid, float3 light, float3 ambientTint, constant SCNSceneBuffer& scn_frame) {
    float2 patch = floor(xz / 0.62);
    bool boulder = stoneHash(patch + 2.2) > 0.46;
    RockSample rock = boulder ? sampleRock(xz, 0.62) : sampleRock(xz, 0.13);
    float3 color = mix(dark, light, smoothstep(0.12, 0.88, rock.height));
    color = mix(color, mid, 0.2);
    color = mix(dark * 0.62, color, rock.crack);
    float3 bump = normalize(float3(-rock.slope.x, 0.5 + rock.height * 0.9, -rock.slope.y));
    float3 sun = normalize(float3(0.35, 0.82, 0.25));
    float lit = saturate(dot(bump, sun));
    float3 ambient = max(scn_frame.ambientLightingColor.rgb, ambientTint);
    color *= ambient + lit * float3(0.85, 0.82, 0.78);
    color += pow(saturate(dot(bump, sun)), 18.0) * rock.crack * 0.16;
    return float4(saturate(color), 1.0);
}

fragment float4 feudalismStoneFragment(StoneVertexOut in [[stage_in]],
                                       constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    float3 nLocal = in.localNormal;
    float2 xz = abs(nLocal.y) > 0.7 ? in.localPos.xz : float2(in.localPos.x, -in.localPos.y);
    return shadeRock(xz,
                     float3(0.16, 0.16, 0.18),
                     float3(0.42, 0.43, 0.46),
                     float3(0.78, 0.78, 0.80),
                     float3(0.38, 0.38, 0.40),
                     scn_frame);
}

fragment float4 feudalismIronFragment(StoneVertexOut in [[stage_in]],
                                      constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    float3 nLocal = in.localNormal;
    float2 xz = abs(nLocal.y) > 0.7 ? in.localPos.xz : float2(in.localPos.x, -in.localPos.y);
    return shadeRock(xz,
                     float3(0.14, 0.08, 0.08),
                     float3(0.55, 0.16, 0.12),
                     float3(0.82, 0.42, 0.28),
                     float3(0.42, 0.32, 0.28),
                     scn_frame);
}
