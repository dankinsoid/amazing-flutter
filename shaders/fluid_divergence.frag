#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, divergence pass: how much each cell gains or loses per second.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uTexel;       // [2..3] 1 / velocity grid size
uniform vec2 uVelCode;     // [4..5] velocity store: value * x + y
uniform vec2 uDivCode;     // [6..7] divergence store

// Total: 8 floats.

uniform sampler2D uVelocity;  // sampler 0

out vec4 fragColor;

vec2 vel(vec2 uv) {
	vec2 clamped = clamp(uv, 0.5 * uTexel, 1.0 - 0.5 * uTexel);
	return (texture(uVelocity, clamped).xy - uVelCode.y) / uVelCode.x;
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	vec2 lUv = uv - vec2(uTexel.x, 0.0);
	vec2 rUv = uv + vec2(uTexel.x, 0.0);
	vec2 bUv = uv - vec2(0.0, uTexel.y);
	vec2 tUv = uv + vec2(0.0, uTexel.y);

	float l = vel(lUv).x;
	float r = vel(rUv).x;
	float b = vel(bUv).y;
	float t = vel(tUv).y;

	// Free-slip wall: the ghost cell mirrors the centre, so the border cannot leak.
	vec2 c = vel(uv);
	if (lUv.x < 0.0) l = -c.x;
	if (rUv.x > 1.0) r = -c.x;
	if (tUv.y > 1.0) t = -c.y;
	if (bUv.y < 0.0) b = -c.y;

	float div = 0.5 * (r - l + t - b);
	fragColor = vec4(div * uDivCode.x + uDivCode.y, 0.0, 0.0, 1.0);
}
