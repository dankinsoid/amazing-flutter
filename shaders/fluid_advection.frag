#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, advection: semi-Lagrangian back-trace with exponential decay.
// Runs twice per step — once over velocity, once over the dye.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;    // [0..1] target size, px
uniform vec2 uTexel;         // [2..3] 1 / velocity grid size
uniform vec2 uSourceTexel;   // [4..5] 1 / advected grid size
uniform float uDt;           // [6] step, s
uniform float uDissipation;  // [7] decay per second
uniform float uVector;       // [8] 1 advects packed velocity, 0 advects premultiplied dye
uniform vec2 uVelCode;       // [9..10] velocity store: value * x + y
uniform vec2 uSourceCode;    // [11..12] advected field store; identity for the dye
uniform float uSpeedRef;     // [13] speed of full decay, grid texels/s; 0 decays everywhere

// Total: 14 floats.

uniform sampler2D uVelocity;  // sampler 0
uniform sampler2D uSource;    // sampler 1

out vec4 fragColor;

// Filtering is done by hand: Flutter does not expose the sampler's filter mode,
// and an exact texel-centre tap is what keeps an untouched card pixel-identical.
// A sampler cannot be a function parameter in SkSL, so uSource is read directly.
vec4 bilerpSource(vec2 uv) {
	vec2 st = uv / uSourceTexel - 0.5;
	vec2 base = floor(st);
	vec2 f = fract(st);
	vec2 lo = 0.5 * uSourceTexel;
	vec2 hi = 1.0 - lo;
	vec4 a = texture(uSource, clamp((base + vec2(0.5, 0.5)) * uSourceTexel, lo, hi));
	vec4 b = texture(uSource, clamp((base + vec2(1.5, 0.5)) * uSourceTexel, lo, hi));
	vec4 c = texture(uSource, clamp((base + vec2(0.5, 1.5)) * uSourceTexel, lo, hi));
	vec4 d = texture(uSource, clamp((base + vec2(1.5, 1.5)) * uSourceTexel, lo, hi));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	vec2 velocity = (texture(uVelocity, uv).xy - uVelCode.y) / uVelCode.x;
	vec2 coord = uv - uDt * velocity * uTexel;
	vec4 source = bilerpSource(coord);
	// Dye fades where it flows, not where it sits: untouched pixels must stay solid.
	float local = uSpeedRef > 0.0 ? smoothstep(0.0, uSpeedRef, length(velocity)) : 1.0;
	float decay = 1.0 + uDissipation * uDt * local;

	if (uVector > 0.5) {
		vec2 value = (source.xy - uSourceCode.y) / uSourceCode.x / decay;
		fragColor = vec4(value * uSourceCode.x + uSourceCode.y, 0.0, 1.0);
		return;
	}
	// Premultiplied dye: dividing all four channels thins the smoke without tinting it.
	fragColor = source / decay;
}
