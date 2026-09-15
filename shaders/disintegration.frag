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
const float MODE_ERODE = 3.0;

#define MAX_TRAIL 32

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

// [27] erode: what the finger destroys as it passes
uniform float uErodeRadius;    // [27] disturbance radius under a fresh stroke point, px
uniform float uErodeSpread;    // [28] radius the front gains per second, px/s
uniform float uErodeExpand;    // [29] outward drift away from each point, px
uniform float uErodeSwirl;     // [30] curl-noise eddies, px
uniform float uErodeVortex;    // [31] swirl around the finger, px
uniform float uErodeLifetime;  // [32] disturbance-seconds over which the smoke thins to nothing

// [33] stroke points: x, y in canvas px, age s, strength; strength 0 = empty slot.
uniform vec4 uTrail[MAX_TRAIL];
// [161] unit stroke direction at that point in xy; zw unused.
uniform vec4 uTrailDir[MAX_TRAIL];

// Total: 289 floats.

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

// Rotated gradient of a noise potential: divergence-free, so the smear rolls instead of drifting.
vec2 curl(vec2 p, float scale) {
	const float h = 0.35;  // finite-difference step, in noise units
	vec2 c = p * scale;
	float n0 = valueNoise(c);
	float nx = valueNoise(c + vec2(h, 0.0));
	float ny = valueNoise(c + vec2(0.0, h));
	// Halved so the field is roughly unit length and the knob reads in px.
	return vec2(ny - n0, n0 - nx) * (0.5 / h);
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

// ---- 2. Trail ----

struct Trail {
	float touched;  // 0 undisturbed, 1 inside the front
	float weight;   // summed influence, for the weighted means
	vec2 expand;    // outward drift, px
	vec2 spin;      // swirl around the finger, px
	float age;      // seconds since the finger passed here
};

Trail trailPoint(vec2 p, vec4 t, vec4 dir) {
	Trail s;
	s.touched = 0.0;
	s.weight = 0.0;
	s.expand = vec2(0.0);
	s.spin = vec2(0.0);
	s.age = 0.0;
	if (t.w <= 0.0) return s;
	// The front must cross a whole widget between "corners still crisp" and "all eddies",
	// and sqrt(age) has nowhere near that range over a second: grow it linearly.
	float radius = max(uErodeRadius + uErodeSpread * max(t.z, 0.0), 1.0);
	vec2 v = p - t.xy;
	float k = dot(v, v) / (radius * radius);
	if (k > 9.0) return s;  // past three sigma the point cannot matter
	float w = t.w * exp(-k);
	vec2 away = v * inversesqrt(dot(v, v) + 1.0);
	vec2 side = vec2(-dir.y, dir.x);
	// The sense flips across the stroke: a finger leaves two counter-rotating eddies.
	float across = clamp(dot(v, side) / radius, -1.0, 1.0);
	vec2 tangent = vec2(-v.y, v.x) * inversesqrt(dot(v, v) + 1.0);
	s.touched = w;
	s.weight = w;
	s.expand = away * (w * (1.0 + t.z));
	// Strongest under the finger and fading once it has left.
	s.spin = tangent * (across * w * exp(-t.z / max(uErodeLifetime, 0.05)));
	s.age = w * t.z;
	return s;
}

// Impeller indexes uniform arrays by constants only; the loop is unrolled by macro.
#define TRAIL(i) { \
	Trail s = trailPoint(p, uTrail[i], uTrailDir[i]); \
	acc.touched = max(acc.touched, s.touched); acc.weight += s.weight; \
	acc.expand += s.expand; acc.spin += s.spin; acc.age += s.age; \
}

Trail trailField(vec2 p) {
	Trail acc;
	acc.touched = 0.0;
	acc.weight = 0.0;
	acc.expand = vec2(0.0);
	acc.spin = vec2(0.0);
	acc.age = 0.0;
	TRAIL(0);  TRAIL(1);  TRAIL(2);  TRAIL(3);
	TRAIL(4);  TRAIL(5);  TRAIL(6);  TRAIL(7);
	TRAIL(8);  TRAIL(9);  TRAIL(10); TRAIL(11);
	TRAIL(12); TRAIL(13); TRAIL(14); TRAIL(15);
	TRAIL(16); TRAIL(17); TRAIL(18); TRAIL(19);
	TRAIL(20); TRAIL(21); TRAIL(22); TRAIL(23);
	TRAIL(24); TRAIL(25); TRAIL(26); TRAIL(27);
	TRAIL(28); TRAIL(29); TRAIL(30); TRAIL(31);
	// Weighted means, or a long stroke would push every pixel 32 times as hard.
	// The front is the nearest point's reach, not the sum: stroke length must not deepen it.
	float total = max(acc.weight, 1e-4);
	acc.age /= total;
	acc.touched = clamp(acc.touched, 0.0, 1.0);
	acc.expand *= uErodeExpand * acc.touched / total;
	acc.spin *= uErodeVortex * acc.touched / total;
	return acc;
}

// ---- 3. Cells ----

vec2 cellOf(vec2 q) {
	// A quarter of a logical px is finer than any display: the floor is the pixel grid.
	vec2 g = (q - uChildRect.xy) / max(uCellSize, 0.25);
	// Warp the lattice, or the shards read as a chessboard; pointless once cells are pixels.
	g += noise2(g * 0.7) * (0.8 * smoothstep(2.0, 6.0, uCellSize));
	return floor(g);
}

// ---- 4. Mask ----

// Order 0..1 is when a cell goes; squeezing it by the edge width clears every cell by progress 1.
float departure(float order, float progress, float softness) {
	float threshold = order * (1.0 - softness);
	return smoothstep(threshold, threshold + softness, progress);
}

// ---- 5. Sample ----

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

// ---- 6. Per-pixel result ----

struct Grain {
	vec2 q;      // where to read the snapshot
	float gone;  // 0 intact, 1 destroyed
	float smear; // how hard to blur the read
};

// The card is one cloud held in the shape of a widget; the touch stirs it loose.
Grain erodeGrain(vec2 p) {
	Trail tr = trailField(p);
	float t = tr.age / max(uErodeLifetime, 0.05);
	// A pixel comes loose the moment the front reaches it, and keeps loosening with time.
	float loose = tr.touched * (0.15 + t);
	// The eddy pattern turns over rather than sitting frozen on screen.
	vec2 advected = p + tr.expand * tr.age;
	// Coarse lobes grow in as the smoke ages; the fine octave carries the detail.
	vec2 swirl = curl(advected, uNoiseScale) + curl(advected, uNoiseScale * 0.25) * clamp(tr.age, 0.0, 2.0);
	vec2 d = (tr.expand + tr.spin) * (0.15 + t) + swirl * (uErodeSwirl * loose);
	Grain g;
	g.q = p - d;
	float spent = tr.touched * t;
	// Low-contrast grain so the cloud frays as it thins; never a threshold hole.
	spent *= 0.6 + 0.8 * fbm(g.q * uNoiseScale);
	// uProgress only guarantees termination: it thins whatever is left.
	g.gone = max(smoothstep(0.0, 1.0, spent), uProgress);
	g.smear = clamp(tr.touched * t, 0.0, 1.0);
	return g;
}

Grain dissolveGrain(vec2 p, float softness) {
	// Smooth local time: the sweep front, without the per-cell term that cannot be inverted.
	float t = clamp(uProgress - leadOrder(p) * uSweep, 0.0, 1.0);
	vec2 q0 = p - flow(p, t);
	// Order at the source, or a shard that flew ahead is masked by where it landed.
	float lead = leadOrder(q0);

	Grain g;
	g.q = q0;
	if (isMode(MODE_SMOKE)) {
		g.gone = departure(mix(fbm(q0 * uNoiseScale), lead, uSweep), uProgress, softness);
		g.smear = g.gone;
		return g;
	}
	vec2 id = cellOf(q0);
	vec3 h = hash32(id + uSeed);
	g.gone = departure(mix(h.x, lead, uSweep), uProgress, softness);
	g.smear = 0.0;
	vec2 centre = uChildRect.xy + (id + 0.5) * uCellSize;
	vec2 dir = flowDir(centre);
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 offset = (dir * (0.5 + h.z) + perp * (h.y - 0.5) * 1.5) * (uJitter * g.gone * g.gone);
	float angle = (h.y - 0.5) * 2.0 * uSpin * g.gone;
	float scale = max(1.0 - uShrink * g.gone, 0.05);
	vec2 v = (q0 - offset) - centre;
	// Inverse map: rotating the sample by -angle spins the shard by +angle.
	g.q = centre + mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * v / scale;
	return g;
}

void main() {
	vec2 p = FlutterFragCoord().xy;
	float softness = clamp(uSoftness, 1e-3, 0.9);
	// The other modes must not pay for the 32-point loop: branch, do not select.
	Grain g;
	if (isMode(MODE_ERODE)) {
		g = erodeGrain(p);
	} else {
		g = dissolveGrain(p, softness);
	}
	vec4 colour = sampleSmeared(g.q, g.smear);
	fragColor = colour * (pow(1.0 - g.gone, max(uFade, 0.01)) * edgeFade(p));
}
