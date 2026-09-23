#version 460 core
#include <flutter/runtime_effect.glsl>

// Flake grids run to thousands of cells; ids overflow fp16.
precision highp float;

// @ai-generated(solo)
//
// Glitter: a flat base tone dusted with tiny mirrors. Each flake owns a random
// tilt and flashes only while the virtual light lines up with it, so the surface
// lives off movement rather than off a clock. Design and uniform table:
// docs/glitter.md.

const float TAU = 6.28318530718;

// ---- Uniforms. Declaration order is the setFloat index. ----

uniform vec3 uBase;         // [0..2] base tone, sRGB as painted
uniform vec2 uLight;        // [3..4] virtual light tilt, -1..1 per axis
uniform float uFlicker;     // [5] flicker clock, s; stalls when the device rests
uniform float uFlakeScale;  // [6] flake cell size multiplier, 1 = the reference dust
uniform float uDensity;     // [7] fraction of cells holding a flake, multiplier
uniform float uGain;        // [8] flash brightness multiplier
uniform float uRainbow;     // [9] iridescence, 0 = warm white flakes only
uniform float uGrain;       // [10] micro-grain over the base
uniform float uSeed;        // [11] shifts every hash

// Total: 12 floats.

out vec4 fragColor;

// Dave Hoskins-style hashes; cheap and stable across GPUs.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// One layer of flakes on a square grid. Each flake is a tiny mirror with a random
// tilt, so it flashes only while the light direction lines up with it.
vec3 sparkles(vec2 position, float cellSize, float density, vec3 light, float sharpness, float gain, float baseLum) {
	vec2 p = position / cellSize;
	vec2 id = floor(p) + uSeed;
	vec3 r = hash32(id);
	if (r.z > density) return vec3(0.0);

	vec3 normal = normalize(vec3((r.xy * 2.0 - 1.0) * 0.75, 1.0));
	float facing = max(dot(normal, light), 0.0);
	float spec = pow(facing, sharpness);

	// Real flakes wink in and out rather than breathe; a fast, per-flake phase
	// with a narrow duty cycle reads as flicker instead of a pulse.
	float phase = hash12(id + 7.31);
	float blink = fract(uFlicker * 1.7 + phase);
	float twinkle = 0.25 + 0.75 * smoothstep(0.55, 0.0, blink);

	// Between flashes a broader, weaker lobe keeps many flakes a touch brighter
	// than the base — never darker. Scaled by squared base luminance: this is
	// what makes the glitter read at rest on light tones, while dark tones
	// already read through the flashes alone.
	//
	// It winks on its own phase and tempo: sharing the specular twinkle would
	// collapse both layers into one synchronized pulse.
	float glintBlink = fract(uFlicker * 1.1 + hash12(id + 19.7));
	float glintTwinkle = 0.30 + 0.70 * smoothstep(0.70, 0.0, glintBlink);
	// Wide enough to catch flakes the specular lobe misses, tight enough that
	// tilting still moves it.
	float glint = pow(facing, 22.0) * 0.85 * baseLum * baseLum * glintTwinkle;

	float intensity = spec * twinkle * gain;

	// Confine the flash to a small dot placed off-center in its cell,
	// so the layout never reads as a grid.
	vec3 jitter = hash32(id + 3.7);
	vec2 f = fract(p) - 0.5 - (jitter.xy - 0.5) * 0.45;
	float dotMask = smoothstep(0.38, 0.08, length(f));

	// Iridescence: each flake owns a hue offset, and the hue slides with the
	// light angle, so tilting sweeps rainbow colors across the surface.
	float hue = fract(jitter.z + uLight.x * 1.6 + uLight.y * 1.2 + spec * 0.2);
	vec3 rainbow = 0.5 + 0.5 * cos(TAU * (hue + vec3(0.0, 0.33, 0.67)));
	// Roughly half the flakes stay warm white so the rainbow reads as a wash, not candy.
	float strength = uRainbow * 0.75 * smoothstep(0.35, 0.9, fract(jitter.z * 13.7));
	vec3 tint = mix(vec3(1.0, 0.97, 0.93), rainbow, strength);

	return tint * ((intensity + glint) * dotMask);
}

void main() {
	vec2 position = FlutterFragCoord().xy;

	vec3 base = uBase;
	vec3 light = normalize(vec3(uLight, 1.35));

	// Micro-grain so the base doesn't read as flat plastic.
	float grain = (hash12(position * 3.1 + uSeed) - 0.5) * 0.05 * uGrain;

	float baseLum = dot(base, vec3(0.299, 0.587, 0.114));
	// Two flake scales: fine dust plus sparser, brighter flashes on top. Narrow
	// lobes: a flake catches the light only in a small angular window, so the
	// smallest movement sweeps the highlight off it and onto the next.
	vec3 flash = sparkles(position, 2.1 * uFlakeScale, 0.65 * uDensity, light, 220.0, 1.35 * uGain, baseLum)
		+ sparkles(position + 61.7, 3.6 * uFlakeScale, 0.22 * uDensity, light, 320.0, 2.3 * uGain, baseLum);

	// Grain is additive, so on a pure black base it would lift it to gray, and its
	// negative half would dust a pure white base with gray specks; fade it out at
	// both extremes and let the flashes carry the look.
	float texture = smoothstep(0.02, 0.15, baseLum) * (1.0 - smoothstep(0.95, 1.0, baseLum));

	// Flutter composites in SDR with no headroom API, so a flash clips at white
	// instead of spilling past it the way the Metal original's EDR drawable does.
	fragColor = vec4(clamp(base + grain * texture + flash, 0.0, 1.0), 1.0);
}
