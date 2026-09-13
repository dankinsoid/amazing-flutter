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
#define MAX_TOUCHES 32
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

const float PI = 3.14159265;

// ---- Uniforms. Declaration order is the setFloat index. ----

// [0] engine: input size in px, filled by ImageFilter.shader.
uniform vec2 uSize;

// [2] frame
uniform vec3 uLight;    // [2..4] direction to the light, +z toward the viewer

// [5] field
uniform float uSmoothK;      // [5] smin radius, px
uniform float uEdgeWidth;    // [6] squircle ramp width from the edge inward, px
uniform float uGlassHeight;  // [7] profile amplitude, px; sets the normal slope

// [8] material
uniform float uThickness;    // [8] refraction offset at unit slope, px
uniform float uAberration;   // [9] per-channel offset spread; 0 = single read
uniform vec4 uTint;          // [10..13] rgb, strength
uniform float uSaturation;   // [14] 1 = unchanged
uniform float uSpecular;     // [15] Blinn-Phong intensity
uniform float uShininess;    // [16] Blinn-Phong exponent
uniform float uRimWidth;     // [17] edge band for rim and inner shadow, px
uniform float uFresnel;      // [18]
uniform float uInnerShadow;  // [19]

// [20] content
uniform float uHasContent;       // [20] > 0.5: sampler 1 holds the content snapshot
uniform vec4 uContentRect;       // [21..24] x, y, w, h in px; where sampler 1 sits on screen
uniform float uContentStrength;  // [25] content displacement per px of water envelope

// [26] water, shared by all touches: k rad/px, omega rad/s, reach px, tau s
uniform vec4 uWave;

// [30] ripple sources: x, y, age s, amplitude px; amplitude 0 = empty slot.
// A stroke is a dense trail of these (Huygens); spacing must stay under half a wavelength.
uniform vec4 uTouches[MAX_TOUCHES];

// [158] shapes, SHAPE_STRIDE slots each; kind 0 = empty slot
uniform vec4 uShapes[MAX_SHAPES * SHAPE_STRIDE];

// Total: 254 floats.

uniform sampler2D uBackdrop;  // sampler 0, engine-filled; already blurred when frost is composed
uniform sampler2D uContent;   // sampler 1, content snapshot, premultiplied

out vec4 fragColor;

// ---- 1. Shape field ----

float sdCircle(vec2 p, vec2 c, float r) {
	return length(p - c) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
	return sdSegment(p, a, b) - r;
}

float sdRoundedBox(vec2 p, vec2 c, vec2 halfSize, float r) {
	vec2 q = abs(p - c) - halfSize + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

// Capsule swept along a -> c -> b, corner at c rounded by `bend`.
// The path is two segments joined by a tangent arc, so plain min is the exact distance.
float sdBentCapsule(vec2 p, vec2 a, vec2 c, vec2 b, float r, float bend) {
	vec2 u1 = normalize(c - a);
	vec2 u2 = normalize(b - c);
	float turn = cross2(u1, u2);
	float cosT = clamp(dot(u1, u2), -1.0, 1.0);
	if (bend <= 0.0 || abs(turn) < 1e-4) {
		return min(sdSegment(p, a, c), sdSegment(p, c, b)) - r;
	}
	// Tangent length from the corner; capped so the arc fits both legs.
	float t = bend * sqrt((1.0 - cosT) / (1.0 + cosT));
	float tMax = min(length(c - a), length(b - c));
	if (t > tMax) {
		bend *= tMax / t;
		t = tMax;
	}
	vec2 t1 = c - u1 * t;
	vec2 t2 = c + u2 * t;
	vec2 n1 = vec2(-u1.y, u1.x) * sign(turn);
	vec2 cen = t1 + n1 * bend;
	float d = min(sdSegment(p, a, t1), sdSegment(p, t2, b));
	vec2 v = p - cen;
	vec2 e1 = t1 - cen, e2 = t2 - cen;
	bool inWedge = cross2(e1, v) * sign(turn) >= 0.0 && cross2(v, e2) * sign(turn) >= 0.0;
	if (inWedge) d = min(d, abs(length(v) - bend));
	return d - r;
}

float smin(float a, float b, float k) {
	if (k <= 0.0) return min(a, b);
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
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
	float y = 1.0 - x;
	float y2 = y * y;
	return sqrt(sqrt(1.0 - y2 * y2));
}

float heightGlass(float sd) {
	float x = clamp(-sd / max(uEdgeWidth, 1e-3), 0.0, 1.0);
	return uGlassHeight * glassProfile(x);
}

// One source: (height, d/dx, d/dy, envelope). A travelling packet: the crest
// sits at the front and the source calms behind it. The gradient is analytic so
// the trail costs one evaluation per source, not five.
vec4 waterRing(vec2 p, vec4 t) {
	if (t.w <= 0.0) return vec4(0.0);
	float k = uWave.x, omega = uWave.y, reach = uWave.z, tau = uWave.w;
	float wavelength = 2.0 * PI / k;
	vec2 pc = p - t.xy;
	// The finger has a footprint: soften r so the height is smooth at the source.
	float s = 0.5 * wavelength;
	float q = sqrt(dot(pc, pc) + s * s);
	float r = q - s;
	float age = t.z;
	float front = (omega / k) * age;
	float width = wavelength * (1.0 + age / tau);
	float d = (r - front) / width;
	float env = t.w * exp(-d * d) * exp(-age / tau) * inversesqrt(1.0 + front / reach);
	float ph = k * (r - front);
	float c = cos(ph), sn = sin(ph);
	float dhdr = env * (-2.0 * d / width * c - k * sn);
	return vec4(env * c, dhdr * pc / q, env);
}

#define TOUCH(i) w += waterRing(p, uTouches[i])

vec4 heightWater(vec2 p) {
	vec4 w = vec4(0.0);
	TOUCH(0);  TOUCH(1);  TOUCH(2);  TOUCH(3);
	TOUCH(4);  TOUCH(5);  TOUCH(6);  TOUCH(7);
	TOUCH(8);  TOUCH(9);  TOUCH(10); TOUCH(11);
	TOUCH(12); TOUCH(13); TOUCH(14); TOUCH(15);
	TOUCH(16); TOUCH(17); TOUCH(18); TOUCH(19);
	TOUCH(20); TOUCH(21); TOUCH(22); TOUCH(23);
	TOUCH(24); TOUCH(25); TOUCH(26); TOUCH(27);
	TOUCH(28); TOUCH(29); TOUCH(30); TOUCH(31);
	return w;
}

// v2 slot: material relief (fluted glass). Zero in v1.
float heightRelief(vec2 p, float sd) {
	return 0.0;
}

// The terms without an analytic gradient.
float heightStatic(vec2 p) {
	float sd = sceneSd(p);
	return heightGlass(sd) + heightRelief(p, sd);
}

// ---- 3. Normal ----

// Gradient of the summed height: static terms by central differences, water analytic.
vec3 normalAt(vec2 p, vec2 waterGrad) {
	vec2 dx = vec2(NORMAL_STEP, 0.0);
	vec2 dy = vec2(0.0, NORMAL_STEP);
	float gx = (heightStatic(p + dx) - heightStatic(p - dx)) / (2.0 * NORMAL_STEP);
	float gy = (heightStatic(p + dy) - heightStatic(p - dy)) / (2.0 * NORMAL_STEP);
	return normalize(vec3(-(gx + waterGrad.x), -(gy + waterGrad.y), 1.0));
}

// ---- 4. Sample ----

vec2 backdropUv(vec2 p) {
	vec2 uv = p / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
	uv.y = 1.0 - uv.y;
#endif
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
	vec3 l = normalize(uLight);
	vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
	float band = 1.0 - smoothstep(0.0, uRimWidth, -sd);
	Light lt;
	lt.specular = uSpecular * pow(max(dot(n, h), 0.0), uShininess);
	lt.rim = uSpecular * band * max(dot(n, l), 0.0);
	lt.fresnel = uFresnel * pow(1.0 - max(n.z, 0.0), 5.0);
	return lt;
}

// ---- 6. Composite ----

float coverage(float sd, float aa) {
	return 1.0 - smoothstep(-aa, aa, sd);
}

vec3 adjustColor(vec3 c) {
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(luma), c, uSaturation);
	return mix(c, uTint.rgb, uTint.a);
}

vec4 composite(vec4 backdrop, vec4 content, Light lt, float sd, float mask) {
	vec3 glass = adjustColor(backdrop.rgb);
	float band = 1.0 - smoothstep(0.0, uRimWidth, -sd);
	glass *= 1.0 - uInnerShadow * band;
	glass += vec3(lt.fresnel + lt.specular + lt.rim);
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
	vec4 water = heightWater(p);
	vec3 n = normalAt(p, water.yz);
	float waveEnv = water.w;
	vec4 backdrop = sampleBackdrop(p, n);
	vec4 content = sampleContent(p, n, waveEnv);
	Light lt = lighting(n, sd);
	fragColor = composite(backdrop, content, lt, sd, mask);
}
