#version 460 core
#include <flutter/runtime_effect.glsl>

// Card coordinates in px overflow fp16.
precision highp float;

// @ai-generated(solo)
//
// Holographic card: a foil, a glare and a grain over the card's own snapshot.
// Stages: rounded-rect clip -> mask -> surface normal from tilt -> specular lobe
// -> foil phase -> sparkles -> blend. Design and uniform table: docs/holo.md.

// No int uniforms exist: pattern and mask are floats compared against half-way thresholds.
const float PATTERN_CLASSIC = 0.0;
const float PATTERN_REVERSE = 1.0;
const float PATTERN_GALAXY = 2.0;

const float MASK_CARD = 0.0;
const float MASK_LUMA = 1.0;
const float MASK_ALPHA = 2.0;

const float TAU = 6.28318530718;

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec2 uSize;              // [0..1] card in logical px
uniform vec2 uTilt;              // [2..3] -1..1; +x = right edge toward the viewer, +y = bottom edge toward it
uniform vec2 uPointer;           // [4..5] -1..1 across the card, 0 = centre
uniform float uPointerStrength;  // [6] 0 = no pointer: foil and glare are gone, like --card-opacity
uniform float uPattern;          // [7] 0 classic, 1 reverse, 2 galaxy
uniform float uMask;             // [8] 0 whole card, 1 child luminance, 2 child alpha
uniform float uFoil;             // [9] rainbow strength
uniform float uGlare;            // [10] white blob strength
uniform float uGrain;            // [11] how far the foil is broken up, 0..1
uniform float uBandScale;        // [12] rainbow bands across the card
uniform float uRadius;           // [13] corner radius, logical px
uniform float uSeed;             // [14] shifts every hash and the band phase

// Total: 15 floats.

uniform sampler2D uCard;  // sampler 0, the card's own content, premultiplied

out vec4 fragColor;

// The lobe geometry is fixed: these shape the effect, they are not a user knob.
const float TILT_ANGLE = 0.50;    // rad of surface tilt at |uTilt| = 1
const float LIGHT_HEIGHT = 0.75;  // light above the card, in half-card units
const float VIEW_DIST = 2.40;     // viewer above the card, in half-card units
const float SHININESS = 14.0;

bool isPattern(float pattern) {
	return abs(uPattern - pattern) < 0.5;
}

bool isMask(float mask) {
	return abs(uMask - mask) < 0.5;
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
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Summed octaves cluster around 0.5; stretch about the mean or the cloud has no contrast.
float fbm(vec2 p) {
	float v = 0.5 * valueNoise(p) + 0.25 * valueNoise(p * 2.03) + 0.125 * valueNoise(p * 4.07);
	return clamp((v / 0.875 - 0.5) * 2.0 + 0.5, 0.0, 1.0);
}

// ---- Colour ----

// Inigo Quilez cosine palette, tuned to the sunpillar ramp of the reference.
vec3 palette(float t) {
	return 0.5 + 0.5 * cos(TAU * (t + vec3(0.00, 0.33, 0.67)));
}

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 contrast(vec3 c, float amount) {
	return clamp((c - 0.5) * amount + 0.5, 0.0, 1.0);
}

vec3 saturate(vec3 c, float amount) {
	return clamp(mix(vec3(luminance(c)), c, amount), 0.0, 1.0);
}

// ---- Blends, on straight alpha ----

vec3 screenBlend(vec3 b, vec3 s) {
	return b + s - b * s;
}

// Dodge alone crushes bright art to white; the screen half keeps a gradient there.
vec3 foilBlend(vec3 b, vec3 s) {
	vec3 dodge = min(vec3(1.0), b / max(vec3(1.0) - min(s, vec3(0.92)), vec3(0.08)));
	return mix(screenBlend(b, s), dodge, 0.55);
}

vec3 overlayBlend(vec3 b, vec3 s) {
	vec3 low = 2.0 * b * s;
	vec3 high = 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
	return mix(low, high, step(vec3(0.5), b));
}

// ---- Geometry ----

float sdRoundBox(vec2 p, vec2 half_, float r) {
	vec2 q = abs(p) - half_ + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// One glinting cell per `cellPx` square: a hashed dot that lights when the tilt
// phase sweeps past it, so tilting changes *which* sparkles are on.
float sparkle(vec2 frag, float cellPx, float density, float phase, float seed) {
	vec2 cell = frag / cellPx;
	vec2 id = floor(cell) + seed;
	vec3 h = hash32(id);
	vec2 centre = vec2(h.x, h.y) * 0.7 + 0.15;
	float r = length(fract(cell) - centre) * 2.2;
	float dot_ = exp(-r * r * 7.0);
	float glint = cos(h.z * TAU * 6.0 + phase);
	return dot_ * smoothstep(0.80, 1.0, glint) * step(hash12(id * 1.37), density);
}

void main() {
	vec2 frag = FlutterFragCoord();
	vec2 uv = frag / uSize;
	vec2 p = uv * 2.0 - 1.0;
	float aspect = uSize.x / uSize.y;
	vec2 wide = vec2(aspect, 1.0);

	vec2 half_ = uSize * 0.5;
	float radius = clamp(uRadius, 0.0, min(half_.x, half_.y));
	float cover = clamp(0.5 - sdRoundBox(frag - half_, half_, radius), 0.0, 1.0);

	vec4 src = texture(uCard, uv);
	float alpha = src.a;
	vec3 base = alpha > 0.001 ? src.rgb / alpha : vec3(0.0);

	// The foil follows the art: bright areas take it, dark ink keeps almost none.
	float mask = 1.0;
	if (isMask(MASK_LUMA)) mask = mix(0.12, 1.0, smoothstep(0.03, 0.80, luminance(base)));
	else if (isMask(MASK_ALPHA)) mask = alpha;

	// Tilting the right edge toward the viewer swings the surface normal to the left.
	vec3 n = normalize(vec3(-uTilt * TILT_ANGLE, 1.0));
	vec3 toLight = vec3((uPointer - p) * wide, LIGHT_HEIGHT);
	vec3 toEye = vec3(-p * wide, VIEW_DIST);
	vec3 h = normalize(normalize(toLight) + normalize(toEye));
	float nh = max(dot(n, h), 0.0);
	// A broad lobe carries the sheet, the tight one is where it "faces the light".
	float light = 0.22 + 0.55 * nh * nh + 1.15 * pow(nh, SHININESS);

	float fromCentre = clamp(length(uPointer), 0.0, 1.0);
	float tiltAmount = clamp(length(uTilt), 0.0, 1.0);

	// The rainbow sweeps because the tilt shifts the phase, as --background-position does on the site.
	float band = dot(p * wide, normalize(vec2(0.94, 0.34))) * uBandScale
		+ dot(uTilt, vec2(1.60, 1.10))
		+ tiltAmount * 0.55
		+ uSeed * 0.37;

	float glint = dot(uTilt, vec2(5.3, 3.7)) + uSeed;

	vec3 foil;
	if (isPattern(PATTERN_REVERSE)) {
		// Thin repeating lines, the etched look, with the foil grain glittering between them.
		float ridge = pow(1.0 - abs(fract(band * 2.0) * 2.0 - 1.0), 5.0);
		foil = palette(band * 0.45 + 0.10) * (0.30 + 1.50 * ridge);
		foil += vec3(1.0, 0.96, 0.88) * sparkle(frag, 5.0, 0.55, glint * 1.6, uSeed) * 1.4;
		foil = saturate(contrast(foil, 1.55), 1.10);
	} else if (isPattern(PATTERN_GALAXY)) {
		// Cosmos: a dark plasma the colour rides on, dense stars glinting in and out.
		float cloud = fbm(uv * vec2(3.2 * aspect, 3.2) + uSeed * 7.0);
		foil = palette(band * 0.55 + cloud * 0.40) * (0.18 + 1.05 * smoothstep(0.30, 0.85, cloud));
		foil += vec3(1.0) * sparkle(frag, 7.0, 0.85, glint * 2.1, uSeed + 11.0) * 1.9;
		foil += vec3(0.75, 0.85, 1.0) * sparkle(frag, 17.0, 0.40, glint * 1.3 + 2.0, uSeed + 23.0) * 1.3;
		foil = saturate(contrast(foil, 1.35), 1.25);
	} else {
		// Classic: wide diagonal bands over a fine grating, the 110deg rainbow of the site.
		float grating = 0.5 + 0.5 * cos(dot(frag, vec2(0.0, 1.0)) * 1.05);
		foil = palette(band) * mix(0.82, 1.18, grating);
		foil = saturate(contrast(foil, 1.85), 0.85);
	}

	// Grain breaks the sheet up; it belongs to the foil, so a card at rest stays clean.
	float grain = mix(1.0, 0.55 + 0.90 * hash12(floor(frag * 1.5) + uSeed * 31.0), uGrain);

	float amount = clamp(uPointerStrength, 0.0, 1.0);
	float foilAmount = uFoil * mask * amount * grain * light * (0.75 + 0.45 * fromCentre);

	vec3 col = foilBlend(base, clamp(foil * foilAmount, 0.0, 1.0));

	// Overlay glare: above 0.5 it lifts, below it sinks, so the card darkens away from the pointer.
	float blob = smoothstep(1.35, 0.02, length((p - uPointer) * wide));
	vec3 glareCol = vec3(mix(0.20, 0.97, blob));
	col = mix(col, overlayBlend(col, glareCol), uGlare * amount);

	float outAlpha = alpha * cover;
	fragColor = vec4(clamp(col, 0.0, 1.0) * outAlpha, outAlpha);
}
