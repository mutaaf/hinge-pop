#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The aurora behind every screen. Pure maths with no textures, and time is passed in, so a paused field
// shows a stable still frame. The output is premultiplied light, laid over the arena art.

static inline float wave(float2 p, float t, float speed, float freq, float phase) {
  return sin(p.x * freq + t * speed + phase + 1.6 * sin(p.x * freq * 0.37 - t * speed * 0.61 + phase));
}

[[ stitchable ]] half4 auroraLight(float2 pos, half4 color, float2 size, float t,
                                   half4 c1, half4 c2, half4 c3, float strength, float heat) {
  float2 uv = pos / max(size, float2(1.0));
  float aspect = size.x / max(size.y, 1.0);
  float2 p = float2(uv.x * aspect, uv.y);
  half3 col = half3(0);

  // Three hanging curtains. Each one is a wavy band with fine vertical rays, fading downward.
  const float heights[3] = { 0.24, 0.5, 0.78 };
  const half3 tints[3] = { c1.rgb, c2.rgb, c3.rgb };
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float center = heights[i] + 0.07 * wave(p, t, 0.17 + fi * 0.03, 2.2 + fi * 0.7, fi * 2.1);
    float d = p.y - center;
    float below = d > 0.0 ? exp(-d * d * 26.0) : exp(-d * d * 150.0);
    float rays = 0.6 + 0.4 * sin(p.x * (34.0 + fi * 13.0) + 1.8 * wave(p, t, 0.31, 3.4, fi) + t * 0.22);
    col += tints[i] * half(below * rays);
  }

  // As the overload meter fills, the whole sky warms toward red.
  half3 hot = half3(1.0, 0.24, 0.32);
  col = mix(col, hot * dot(col, half3(0.5)) * 1.5, half(clamp(heat, 0.0, 1.0) * 0.8));

  // A little grain, so soft gradients never band.
  float n = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
  col = max(col + half((n - 0.5) * 0.018), half3(0));
  col *= half(strength);
  float alpha = clamp(float(max(col.r, max(col.g, col.b))), 0.0, 1.0);
  return half4(col, half(alpha));
}
