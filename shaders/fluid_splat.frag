#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, splat: adds a gaussian blob of velocity under the finger.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uPoint;       // [2..3] splat centre, uv
uniform vec2 uForce;       // [4..5] velocity added at the centre, grid texels/s
uniform float uRadius;     // [6] gaussian falloff, uv squared
uniform float uAspect;     // [7] width / height of the grid
uniform vec2 uVelCode;     // [8..9] velocity store: value * x + y

// Total: 10 floats.

uniform sampler2D uTarget;  // sampler 0

out vec4 fragColor;

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	vec2 p = uv - uPoint;
	p.x *= uAspect;
	vec2 splat = exp(-dot(p, p) / uRadius) * uForce;
	vec2 base = (texture(uTarget, uv).xy - uVelCode.y) / uVelCode.x;
	vec2 value = clamp(base + splat, -1000.0, 1000.0);
	fragColor = vec4(value * uVelCode.x + uVelCode.y, 0.0, 1.0);
}
