#version 460 core
#include <flutter/runtime_effect.glsl>

// Canvas coordinates in px overflow fp16.
precision highp float;

// @ai-generated(solo)
//
// Disintegration: a child snapshot dissolved along a swipe, in three modes.
// Stages: flow field -> inverse map -> per-cell transform -> mask -> sample.
// Design and uniform table: docs/disintegration.md.

// No int uniforms exist: the mode is a float compared against half-way thresholds.
const float MODE_SHARDS = 0.0;
const float MODE_SMOKE = 1.0;
const float MODE_BLOW = 2.0;

// ---- Uniforms. Declaration order is the setFloat index. ----

// [0] geometry, canvas px
uniform vec2 uSize;       // [0..1] painter canvas, child rect plus the spread margin
uniform vec4 uChildRect;  // [2..5] x, y, w, h: where the snapshot sits in the canvas

// [6] drive
uniform float uProgress;  // [6] 0 = intact, 1 = gone
uniform float uMode;      // [7] 0 shards, 1 smoke, 2 blow-away
uniform vec2 uDirection;  // [8..9] unit swipe direction
uniform vec2 uOrigin;     // [10..11] finger position, canvas px
uniform float uSeed;      // [12] shifts every hash

// [13] field
uniform float uCellSize;    // [13] shard cell edge, px
uniform float uDrift;       // [14] smooth displacement at full departure, px
uniform float uLift;        // [15] upward bias added to the drift, px
uniform float uJitter;      // [16] per-shard displacement on top of the drift, px; sub-cell, see docs §5
uniform float uSpin;        // [17] per-shard rotation at full departure, rad
uniform float uShrink;      // [18] shard size lost at full departure, 0..1
uniform float uNoiseScale;  // [19] 1 / noise feature size, 1/px
uniform float uTurbulence;  // [20] noise-driven displacement, px
uniform float uRadial;      // [21] blow-away: radial vs swipe direction, 0..1

// [22] mask
uniform float uSoftness;  // [22] dissolve edge width, in progress units
uniform float uSweep;     // [23] 0 = dissolves everywhere at once, 1 = strictly front to back
uniform float uBlur;      // [24] smoke blur radius at full departure, px; 0 = single read
uniform float uFade;      // [25] alpha exponent while departing
uniform float uEdgeFade;  // [26] fade band at the canvas border, px

// Total: 27 floats.

uniform sampler2D uSnapshot;  // sampler 0, frozen child, premultiplied

out vec4 fragColor;

bool isMode(float mode) {
	return abs(uMode - mode) < 0.5;
}

// ---- Hash and noise ----

// Hoskins hashes: no sin(), stable across drivers.
float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 hash32(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yxz + 33.33);
	return fract((q.xxy + q.yzz) * q.zyx);
}

float valueNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = valueNoise(p) * 0.5;
	v += valueNoise(p * 2.03) * 0.3;
	v += valueNoise(p * 4.07) * 0.2;
	// Summed octaves cluster around 0.5; stretch or the mask has no contrast.
	return clamp((v - 0.5) * 2.2 + 0.5, 0.0, 1.0);
}

vec2 noise2(vec2 p) {
	return vec2(valueNoise(p), valueNoise(p + 19.7)) - 0.5;
}

// ---- 1. Flow field ----

// How late this pixel leaves, 0 at the edge that goes first.
float leadOrder(vec2 p) {
	if (isMode(MODE_BLOW)) {
		// Half the diagonal: a finger in the middle must still reach 1 at the corners.
		return clamp(length(p - uOrigin) / max(0.5 * length(uChildRect.zw), 1.0), 0.0, 1.0);
	}
	vec2 c = uChildRect.xy + 0.5 * uChildRect.zw;
	float reach = 0.5 * (abs(uDirection.x) * uChildRect.z + abs(uDirection.y) * uChildRect.w);
	return clamp(0.5 - dot(p - c, uDirection) / (2.0 * max(reach, 1.0)), 0.0, 1.0);
}

// Unit direction the material leaves along; blow-away flows out of the finger.
vec2 flowDir(vec2 p) {
	if (!isMode(MODE_BLOW)) return uDirection;
	vec2 away = p - uOrigin;
	vec2 d = mix(uDirection, away / max(length(away), 1.0), uRadial);
	float l = length(d);
	return l > 1e-4 ? d / l : uDirection;
}

// Smooth in p, so a moved cell's footprint moves with it; a hash term here would not invert.
vec2 flow(vec2 p, float t) {
	vec2 d = flowDir(p) * (uDrift * t * t);
	d.y -= uLift * t * t;  // canvas y grows downward
	d += noise2(p * uNoiseScale) * (uTurbulence * t * t);
	return d;
}

// ---- 2. Cells ----

vec2 cellOf(vec2 q) {
	vec2 g = (q - uChildRect.xy) / max(uCellSize, 1.0);
	// Warp the lattice, or the shards read as a chessboard.
	g += noise2(g * 0.7) * 0.8;
	return floor(g);
}

// ---- 3. Mask ----

// Order 0..1 is when a cell goes; squeezing it by the edge width clears every cell by progress 1.
float departure(float order, float progress, float softness) {
	float threshold = order * (1.0 - softness);
	return smoothstep(threshold, threshold + softness, progress);
}

// ---- 4. Sample ----

vec4 sampleChild(vec2 q) {
	vec2 uv = (q - uChildRect.xy) / uChildRect.zw;
	vec2 c = clamp(uv, 0.0, 1.0);
	// Branchless bounds test: keeping texture() out of a branch keeps the read uniform.
	float outside = abs(uv.x - c.x) + abs(uv.y - c.y);
	return texture(uSnapshot, c) * (1.0 - step(1e-5, outside));
}

// Three taps on a triangle: enough to read as motion blur, cheap enough to keep.
vec4 sampleSmeared(vec2 q, float amount) {
	if (uBlur < 0.01) return sampleChild(q);
	float r = uBlur * amount;
	vec2 a = vec2(0.0, -1.0) * r;
	vec2 b = vec2(0.866, 0.5) * r;
	vec2 c = vec2(-0.866, 0.5) * r;
	return (sampleChild(q + a) + sampleChild(q + b) + sampleChild(q + c)) / 3.0;
}

// The painter clips at the canvas edge; a hard cut there reads as a bug.
float edgeFade(vec2 p) {
	vec2 m = min(p, uSize - p);
	return clamp(min(m.x, m.y) / max(uEdgeFade, 1e-3), 0.0, 1.0);
}

void main() {
	vec2 p = FlutterFragCoord().xy;
	float softness = clamp(uSoftness, 1e-3, 0.9);
	// Smooth local time: the sweep front, without the per-cell term that cannot be inverted.
	float t = clamp(uProgress - leadOrder(p) * uSweep, 0.0, 1.0);
	vec2 q0 = p - flow(p, t);
	// Order at the source, or a shard that flew ahead is masked by where it landed.
	float lead = leadOrder(q0);

	float gone;
	vec2 q = q0;
	if (isMode(MODE_SMOKE)) {
		gone = departure(mix(fbm(q0 * uNoiseScale), lead, uSweep), uProgress, softness);
	} else {
		vec2 id = cellOf(q0);
		vec3 h = hash32(id + uSeed);
		gone = departure(mix(h.x, lead, uSweep), uProgress, softness);
		vec2 centre = uChildRect.xy + (id + 0.5) * uCellSize;
		vec2 dir = flowDir(centre);
		vec2 perp = vec2(-dir.y, dir.x);
		vec2 offset = (dir * (0.5 + h.z) + perp * (h.y - 0.5) * 1.5) * (uJitter * gone * gone);
		float angle = (h.y - 0.5) * 2.0 * uSpin * gone;
		float scale = max(1.0 - uShrink * gone, 0.05);
		vec2 v = (q0 - offset) - centre;
		// Inverse map: rotating the sample by -angle spins the shard by +angle.
		q = centre + mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * v / scale;
	}

	vec4 colour = isMode(MODE_SMOKE) ? sampleSmeared(q, gone) : sampleChild(q);
	fragColor = colour * (pow(1.0 - gone, max(uFade, 0.01)) * edgeFade(p));
}
