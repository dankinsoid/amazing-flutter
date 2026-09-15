#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, curl pass: vorticity of the velocity field, one scalar per cell.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uTexel;       // [2..3] 1 / velocity grid size
uniform vec2 uVelCode;     // [4..5] velocity store: value * x + y
uniform vec2 uCurlCode;    // [6..7] curl store

// Total: 8 floats.

uniform sampler2D uVelocity;  // sampler 0

out vec4 fragColor;

vec2 vel(vec2 uv) {
	vec2 clamped = clamp(uv, 0.5 * uTexel, 1.0 - 0.5 * uTexel);
	return (texture(uVelocity, clamped).xy - uVelCode.y) / uVelCode.x;
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	// The sim runs in Flutter's y-down frame; mirroring flips the curl and the
	// confinement force together, so Dobryakov's formulas carry over unchanged.
	float l = vel(uv - vec2(uTexel.x, 0.0)).y;
	float r = vel(uv + vec2(uTexel.x, 0.0)).y;
	float b = vel(uv - vec2(0.0, uTexel.y)).x;
	float t = vel(uv + vec2(0.0, uTexel.y)).x;
	float curl = 0.5 * (r - l - t + b);
	fragColor = vec4(curl * uCurlCode.x + uCurlCode.y, 0.0, 0.0, 1.0);
}
