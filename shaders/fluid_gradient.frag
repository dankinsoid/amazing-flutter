#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, gradient subtract: takes the pressure gradient out of velocity.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uTexel;       // [2..3] 1 / velocity grid size
uniform vec2 uVelCode;     // [4..5] velocity store: value * x + y
uniform vec2 uPressCode;   // [6..7] pressure store

// Total: 8 floats.

uniform sampler2D uPressure;  // sampler 0
uniform sampler2D uVelocity;  // sampler 1

out vec4 fragColor;

float pressureAt(vec2 uv) {
	vec2 clamped = clamp(uv, 0.5 * uTexel, 1.0 - 0.5 * uTexel);
	return (texture(uPressure, clamped).x - uPressCode.y) / uPressCode.x;
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	float l = pressureAt(uv - vec2(uTexel.x, 0.0));
	float r = pressureAt(uv + vec2(uTexel.x, 0.0));
	float b = pressureAt(uv - vec2(0.0, uTexel.y));
	float t = pressureAt(uv + vec2(0.0, uTexel.y));
	vec2 velocity = (texture(uVelocity, uv).xy - uVelCode.y) / uVelCode.x;
	velocity -= vec2(r - l, t - b);
	fragColor = vec4(velocity * uVelCode.x + uVelCode.y, 0.0, 1.0);
}
