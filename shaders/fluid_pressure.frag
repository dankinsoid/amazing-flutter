#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, pressure pass: one Jacobi sweep of the Poisson solve.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uTexel;       // [2..3] 1 / pressure grid size
uniform float uDecay;      // [4] carry-over of the previous field; 1 after the first sweep
uniform vec2 uPressCode;   // [5..6] pressure store: value * x + y
uniform vec2 uDivCode;     // [7..8] divergence store

// Total: 9 floats.

uniform sampler2D uPressure;    // sampler 0
uniform sampler2D uDivergence;  // sampler 1

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
	float div = (texture(uDivergence, uv).x - uDivCode.y) / uDivCode.x;
	// Dobryakov's separate clear pass, folded into the first sweep: one pass fewer.
	float pressure = ((l + r + b + t) * uDecay - div) * 0.25;
	fragColor = vec4(pressure * uPressCode.x + uPressCode.y, 0.0, 0.0, 1.0);
}
