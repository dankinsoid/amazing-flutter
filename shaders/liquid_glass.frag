#version 460 core
#include <flutter/runtime_effect.glsl>

// Screen-space pixel coordinates overflow fp16.
precision highp float;

// @ai-generated(guided)
//
// Liquid glass: every glass surface of the scene in one backdrop pass.
// Stages: shape field -> height field -> normal -> sample -> light -> composite.
// Design and uniform table: docs/liquid_glass.md.

#define MAX_SHAPES 8
#define MAX_TOUCHES 4
// vec4 slots per shape: (kind, radius, bend, -), (p0.xy, p1.xy), (p2.xy, -, -).
#define SHAPE_STRIDE 3

// No int uniforms exist: kinds are floats compared against half-way thresholds.
const float KIND_NONE = 0.0;
const float KIND_CIRCLE = 1.0;
const float KIND_CAPSULE = 2.0;
const float KIND_ROUNDED_BOX = 3.0;
const float KIND_BENT_CAPSULE = 4.0;

// Distance of an empty slot: far enough that smin ignores it.
const float FAR = 1e5;

// Central-difference step for the normal, px.
const float NORMAL_STEP = 1.0;

// ---- Uniforms. Declaration order is the setFloat index. ----

// [0] engine: input size in px, filled by ImageFilter.shader.
uniform vec2 uSize;

// [2] frame
uniform float uFlipY;   // [2] 1.0 on GLES: sampler 0 is upside-down
uniform vec3 uLight;    // [3..5] direction to the light, +z toward the viewer

// [6] field
uniform float uSmoothK;      // [6] smin radius, px
uniform float uEdgeWidth;    // [7] squircle ramp width from the edge inward, px
uniform float uGlassHeight;  // [8] profile amplitude, px; sets the normal slope

// [9] material
uniform float uThickness;    // [9] refraction offset at unit slope, px
uniform float uAberration;   // [10] per-channel offset spread; 0 = single read
uniform vec4 uTint;          // [11..14] rgb, strength
uniform float uSaturation;   // [15] 1 = unchanged
uniform float uSpecular;     // [16] Blinn-Phong intensity
uniform float uShininess;    // [17] Blinn-Phong exponent
uniform float uRimWidth;     // [18] edge band for rim and inner shadow, px
uniform float uFresnel;      // [19]
uniform float uInnerShadow;  // [20]

// [21] content
uniform float uHasContent;       // [21] > 0.5: sampler 1 holds the content snapshot
uniform vec4 uContentRect;       // [22..25] x, y, w, h in px; where sampler 1 sits on screen
uniform float uContentStrength;  // [26] content displacement per px of water envelope

// [27] water, shared by all touches: k rad/px, omega rad/s, lambda px, tau s
uniform vec4 uWave;

// [31] touches: x, y, age s, amplitude px; amplitude 0 = empty slot
uniform vec4 uTouches[MAX_TOUCHES];

// [47] shapes, SHAPE_STRIDE slots each; kind 0 = empty slot
uniform vec4 uShapes[MAX_SHAPES * SHAPE_STRIDE];

// Total: 143 floats.

uniform sampler2D uBackdrop;  // sampler 0, engine-filled; already blurred when frost is composed
uniform sampler2D uContent;   // sampler 1, content snapshot, premultiplied

out vec4 fragColor;

// ---- 1. Shape field ----

float sdCircle(vec2 p, vec2 c, float r) {
	return FAR;
}

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
	return FAR;
}

float sdRoundedBox(vec2 p, vec2 c, vec2 halfSize, float r) {
	return FAR;
}

// Capsule swept along a -> c -> b, corner at c rounded by `bend`.
float sdBentCapsule(vec2 p, vec2 a, vec2 c, vec2 b, float r, float bend) {
	return FAR;
}

float smin(float a, float b, float k) {
	return min(a, b);
}

float sdShape(vec2 p, vec4 s0, vec4 s1, vec4 s2) {
	float kind = s0.x;
	if (kind < 0.5) return FAR;
	if (kind < 1.5) return sdCircle(p, s1.xy, s0.y);
	if (kind < 2.5) return sdCapsule(p, s1.xy, s1.zw, s0.y);
	if (kind < 3.5) return sdRoundedBox(p, s1.xy, s1.zw, s0.y);
	return sdBentCapsule(p, s1.xy, s1.zw, s2.xy, s0.y, s0.z);
}

// Impeller indexes uniform arrays by constants only; the loop is unrolled by macro.
#define SHAPE(i) smin(d, sdShape(p, \
	uShapes[(i) * SHAPE_STRIDE], \
	uShapes[(i) * SHAPE_STRIDE + 1], \
	uShapes[(i) * SHAPE_STRIDE + 2]), uSmoothK)

float sceneSd(vec2 p) {
	float d = FAR;
	d = SHAPE(0);
	d = SHAPE(1);
	d = SHAPE(2);
	d = SHAPE(3);
	d = SHAPE(4);
	d = SHAPE(5);
	d = SHAPE(6);
	d = SHAPE(7);
	return d;
}

// ---- 2. Height field ----

// Apple's glass profile, x in [0, 1]: (1 - (1 - x)^4)^(1/4).
float glassProfile(float x) {
	return 0.0;
}

float heightGlass(float sd) {
	return 0.0;
}

// One ring: .x height, .y envelope (amplitude without the oscillation).
vec2 waterRing(vec2 p, vec4 touch) {
	return vec2(0.0);
}

#define TOUCH(i) w += waterRing(p, uTouches[i])

vec2 heightWater(vec2 p) {
	vec2 w = vec2(0.0);
	TOUCH(0);
	TOUCH(1);
	TOUCH(2);
	TOUCH(3);
	return w;
}

// v2 slot: material relief (fluted glass). Zero in v1.
float heightRelief(vec2 p, float sd) {
	return 0.0;
}

// All terms sum here, before the normal is taken.
float height(vec2 p) {
	float sd = sceneSd(p);
	return heightGlass(sd) + heightWater(p).x + heightRelief(p, sd);
}

// ---- 3. Normal ----

vec3 normalAt(vec2 p) {
	vec2 dx = vec2(NORMAL_STEP, 0.0);
	vec2 dy = vec2(0.0, NORMAL_STEP);
	float gx = height(p + dx) - height(p - dx);
	float gy = height(p + dy) - height(p - dy);
	return normalize(vec3(-gx, -gy, 2.0 * NORMAL_STEP));
}

// ---- 4. Sample ----

vec2 backdropUv(vec2 p) {
	vec2 uv = p / uSize;
	uv.y = mix(uv.y, 1.0 - uv.y, uFlipY);
	return uv;
}

vec4 sampleBackdrop(vec2 p, vec3 n) {
	vec2 offset = n.xy * uThickness;
	if (uAberration < 1e-4) {
		return texture(uBackdrop, backdropUv(p + offset));
	}
	vec4 r = texture(uBackdrop, backdropUv(p + offset * (1.0 - uAberration)));
	vec4 g = texture(uBackdrop, backdropUv(p + offset));
	vec4 b = texture(uBackdrop, backdropUv(p + offset * (1.0 + uAberration)));
	return vec4(r.r, g.g, b.b, g.a);
}

// At rest the envelope is 0, so content is read at its own texel centres.
vec4 sampleContent(vec2 p, vec3 n, float waveEnv) {
	if (uHasContent < 0.5) return vec4(0.0);
	vec2 q = p + n.xy * uContentStrength * waveEnv;
	vec2 uv = (q - uContentRect.xy) / uContentRect.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(0.0);
	return texture(uContent, uv);
}

// ---- 5. Light ----

struct Light {
	float specular;
	float rim;
	float fresnel;
};

Light lighting(vec3 n, float sd) {
	Light l;
	l.specular = 0.0;
	l.rim = 0.0;
	l.fresnel = 0.0;
	return l;
}

// ---- 6. Composite ----

float coverage(float sd, float aa) {
	return 1.0 - smoothstep(-aa, aa, sd);
}

vec3 adjustColor(vec3 c) {
	return c;
}

vec4 composite(vec4 backdrop, vec4 content, Light lt, float sd, float mask) {
	vec3 glass = adjustColor(backdrop.rgb);
	vec3 c = content.rgb + glass * (1.0 - content.a);
	return vec4(c, 1.0) * mask;
}

void main() {
	vec2 p = FlutterFragCoord().xy;
	float sd = sceneSd(p);
	// Derivatives are undefined in divergent control flow: take them before the branch.
	float aa = fwidth(sd);
	if (sd > aa) {
		// Transparent, not a backdrop read: with frost composed, sampler 0 is
		// already blurred; srcOver leaves the sharp original in place.
		fragColor = vec4(0.0);
		return;
	}
	float mask = coverage(sd, aa);
	float waveEnv = heightWater(p).y;
	vec3 n = normalAt(p);
	vec4 backdrop = sampleBackdrop(p, n);
	vec4 content = sampleContent(p, n, waveEnv);
	Light lt = lighting(n, sd);
	fragColor = composite(backdrop, content, lt, sd, mask);
}
