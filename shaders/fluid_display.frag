#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, display: paints the dye buffer over the host canvas.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Bloom and sunrays are dropped; SHADING is a uniform rather than a #define.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] canvas size, px
uniform vec2 uTexel;       // [2..3] 1 / dye grid size
uniform float uShading;    // [4] 0..1 mix of Dobryakov's fake relief
uniform float uEdgeFade;   // [5] fade band at the canvas border, px

// Total: 6 floats.

uniform sampler2D uDye;  // sampler 0, premultiplied

out vec4 fragColor;

// Hand-filtered so an untouched card stays pixel-identical whatever the
// sampler's filter mode is: at matching resolution every tap lands dead centre.
vec4 bilerp(vec2 uv) {
	vec2 st = uv / uTexel - 0.5;
	vec2 base = floor(st);
	vec2 f = fract(st);
	vec2 lo = 0.5 * uTexel;
	vec2 hi = 1.0 - lo;
	vec4 a = texture(uDye, clamp((base + vec2(0.5, 0.5)) * uTexel, lo, hi));
	vec4 b = texture(uDye, clamp((base + vec2(1.5, 0.5)) * uTexel, lo, hi));
	vec4 c = texture(uDye, clamp((base + vec2(0.5, 1.5)) * uTexel, lo, hi));
	vec4 d = texture(uDye, clamp((base + vec2(1.5, 1.5)) * uTexel, lo, hi));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	vec4 dye = bilerp(uv);

	if (uShading > 0.001) {
		float l = length(texture(uDye, uv - vec2(uTexel.x, 0.0)));
		float r = length(texture(uDye, uv + vec2(uTexel.x, 0.0)));
		float b = length(texture(uDye, uv - vec2(0.0, uTexel.y)));
		float t = length(texture(uDye, uv + vec2(0.0, uTexel.y)));
		vec3 n = normalize(vec3(r - l, t - b, length(uTexel)));
		float diffuse = clamp(dot(n, vec3(0.0, 0.0, 1.0)) + 0.7, 0.7, 1.0);
		dye.rgb *= mix(1.0, diffuse, uShading);
	}

	// Free-slip walls trap the dye inside the canvas; without this it ends as a box.
	vec2 px = FlutterFragCoord().xy;
	vec2 near = min(px, uResolution - px);
	float edge = smoothstep(0.0, max(uEdgeFade, 1e-3), min(near.x, near.y));
	// The dye dies in the field, never by a layer fade; only the wall band is scaled.
	fragColor = dye * edge;
}
