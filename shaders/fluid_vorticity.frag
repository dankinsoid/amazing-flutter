#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// @ai-generated(solo)
//
// Stable Fluids, vorticity confinement: pushes velocity back into its own eddies.
// Ported from WebGL-Fluid-Simulation by Pavel Dobryakov (MIT License,
// Copyright (c) 2017 Pavel Dobryakov),
// https://github.com/PavelDoGreat/WebGL-Fluid-Simulation.
// Packing and pass order: docs/fluid.md.

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uResolution;  // [0..1] target size, px
uniform vec2 uTexel;       // [2..3] 1 / velocity grid size
uniform float uCurl;       // [4] confinement strength
uniform float uDt;         // [5] step, s
uniform vec2 uVelCode;     // [6..7] velocity store: value * x + y
uniform vec2 uCurlCode;    // [8..9] curl store

// Total: 10 floats.

uniform sampler2D uVelocity;   // sampler 0
uniform sampler2D uCurlField;  // sampler 1

out vec4 fragColor;

float curlAt(vec2 uv) {
	vec2 clamped = clamp(uv, 0.5 * uTexel, 1.0 - 0.5 * uTexel);
	return (texture(uCurlField, clamped).x - uCurlCode.y) / uCurlCode.x;
}

void main() {
	vec2 uv = FlutterFragCoord().xy / uResolution;
	float l = curlAt(uv - vec2(uTexel.x, 0.0));
	float r = curlAt(uv + vec2(uTexel.x, 0.0));
	float b = curlAt(uv - vec2(0.0, uTexel.y));
	float t = curlAt(uv + vec2(0.0, uTexel.y));
	float c = curlAt(uv);

	// Gradient of |curl| with the components swapped: the force runs across it.
	vec2 force = 0.5 * vec2(abs(t) - abs(b), abs(r) - abs(l));
	force /= length(force) + 0.0001;
	force *= uCurl * c;
	force.y *= -1.0;

	vec2 velocity = (texture(uVelocity, uv).xy - uVelCode.y) / uVelCode.x;
	velocity += force * uDt;
	velocity = clamp(velocity, -1000.0, 1000.0);
	fragColor = vec4(velocity * uVelCode.x + uVelCode.y, 0.0, 1.0);
}
