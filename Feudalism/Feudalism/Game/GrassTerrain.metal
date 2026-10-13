#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Trava u grafičkom prolazu. Jedna prostorna jedinica je 1 m.
// Unutar nje su niske, guste vlati: tamnija baza, svjetliji vrh, nasumična nijansa.

struct GrassNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};

struct GrassVertexIn {
    float3 position [[attribute(SCNVertexSemanticPosition)]];
    float3 normal [[attribute(SCNVertexSemanticNormal)]];
};

struct GrassVertexOut {
    float4 position [[position]];
    float3 localPos;
    float3 localNormal;
    float3 worldNormal;
};

vertex GrassVertexOut feudalismGrassVertex(GrassVertexIn in [[stage_in]],
                                           constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                           constant GrassNodeBuffer& scn_node [[buffer(1)]]) {
    GrassVertexOut out;
    float4 world = scn_node.modelTransform * float4(in.position, 1.0);
    out.position = scn_frame.viewProjectionTransform * world;
    out.localPos = in.position;
    out.localNormal = in.normal;
    out.worldNormal = normalize((scn_node.modelTransform * float4(in.normal, 0.0)).xyz);
    return out;
}

static float grassHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float3 grassShade(float salt, float along) {
    float pick = grassHash(float2(salt, 2.3));
    float3 deep = float3(0.11, 0.30, 0.08);
    float3 mid = float3(0.24, 0.50, 0.14);
    float3 bright = float3(0.38, 0.64, 0.18);
    float3 olive = float3(0.30, 0.42, 0.12);
    float3 body = pick < 0.33 ? deep : (pick < 0.66 ? mid : (pick < 0.88 ? bright : olive));
    body *= mix(0.82, 1.12, grassHash(float2(salt, 8.1)));
    float3 tip = mix(float3(0.50, 0.72, 0.22), float3(0.68, 0.80, 0.30), grassHash(float2(salt, 5.5)));
    return mix(body, tip, smoothstep(0.45, 1.0, along));
}

fragment float4 feudalismGrassFragment(GrassVertexOut in [[stage_in]],
                                       constant SCNSceneBuffer& scn_frame [[buffer(0)]]) {
    // Veće vlati da se na gornjoj plohi vide vrhovi, ne šum.
    const float cell = 0.12;
    const int reach = 2;
    // Kutija u Aboutu gleda gore po Y. Teren drži mapu u XY, visinu u Z.
    float3 nLocal = in.localNormal;
    float2 xz = abs(nLocal.y) > 0.7 ? in.localPos.xz : float2(in.localPos.x, -in.localPos.y);
    float2 origin = floor(xz / cell);

    float micro = grassHash(floor(xz * 41.0));
    float3 ground = mix(float3(0.16, 0.31, 0.10), float3(0.27, 0.44, 0.15), micro);

    float best = 0.0;
    float3 blade = ground;
    float aa = max(fwidth(xz.x), fwidth(xz.y));

    for (int j = -reach; j <= reach; ++j) {
        for (int i = -reach; i <= reach; ++i) {
            float2 cellId = origin + float2(i, j);
            for (int which = 0; which < 2; ++which) {
                float salt = cellId.x * 13.1 + cellId.y * 7.7 + float(which) * 19.0;
                float2 jitter = float2(grassHash(cellId + float(which) * 3.0), grassHash(cellId + float2(4.2, float(which))));
                float2 base = (cellId + jitter) * cell;
                float ang = grassHash(float2(salt, 1.7)) * 6.2831853;
                float bend = (grassHash(float2(salt, 4.4)) - 0.5) * 0.55;
                float2 dir = float2(cos(ang), sin(ang));
                float2 perp = float2(-dir.y, dir.x);
                float len = mix(which == 0 ? 0.11 : 0.07, which == 0 ? 0.22 : 0.14, grassHash(float2(salt, 6.2)));
                float width = mix(0.022, 0.042, grassHash(float2(salt, 9.4)));

                float2 rel = xz - base;
                float along0 = dot(rel, dir);
                float t0 = along0 / len;
                float2 bent = rel - perp * bend * t0 * t0 * len;
                float along = dot(bent, dir);
                float side = abs(dot(bent, perp));
                float t = along / len;
                if (t < -0.02 || t > 1.02) { continue; }

                float taper = 1.0 - smoothstep(0.0, 1.0, saturate(t));
                taper = taper * taper;
                float halfW = width * max(taper, 0.04);
                float cover = 1.0 - smoothstep(0.0, aa * 1.25 + 0.0015, side - halfW);
                if (cover <= best) { continue; }
                best = cover;
                blade = grassShade(salt, saturate(t));
            }
        }
    }

    float3 rgb = mix(ground, blade, best);
    float3 n = normalize(in.worldNormal);
    float3 sun = normalize(float3(0.32, 0.86, 0.28));
    float light = saturate(dot(n, sun));
    float3 ambient = max(scn_frame.ambientLightingColor.rgb, float3(0.42, 0.46, 0.38));
    rgb *= ambient + light * float3(0.72, 0.78, 0.62);
    return float4(saturate(rgb), 1.0);
}
