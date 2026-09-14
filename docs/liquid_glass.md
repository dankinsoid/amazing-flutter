# Liquid glass — design

Design and data flow of `shaders/liquid_glass.frag` and its Dart binding in
`lib/src/liquid_glass/`. Settled decisions it builds on are in
`CONTEXT.md` (1: one scene-wide height field, 2: sum heights before the normal,
3: one fat shader, 5: all maths in `.frag`).

## 1. Scope

One `.frag` runs over the backdrop and draws **every glass surface of the scene in
one pass**: a tab-bar pill, a floating button, a sheet — all are shapes in one
uniform array, unioned into one distance field. There is no per-surface shader
instance and no per-surface material: v1 has one `GlassMaterial` per pass.

Not in this shader:

- **Frost (blur).** The engine blurs the backdrop before it reaches sampler 0 via
  `ImageFilter.compose(outer: shader, inner: blur)`. See §6 for what that implies.
- **Metaball union.** A v2 alternative to `smin` as the union operator over the same
  shape list. Nothing is reserved for it; swapping the operator is a local change in
  `sceneSd`.
- **Material relief** (fluted glass). Has a slot in the height stage, returns 0 in v1.

## 2. Pipeline

Six stages; each boundary is where the nature of the data changes.

| # | Stage | Input | Output | Reads |
|---|---|---|---|---|
| 1 | shape field | `p` (px), `uShapes`, `uSmoothK` | `sd` — signed distance, negative inside | — |
| 2 | height field | `p`, `sd`, `uTouches`, `uWave`, `uEdgeWidth`, `uGlassHeight` | `h` (px); water gradient and envelope `env` (px) | — |
| 3 | normal | static terms at `p ± step` (4 evaluations of stage 1), water gradient analytic | `n` — unit vec3, +z toward the viewer | — |
| 4 | sample | `p`, `n`, `env`, `uThickness`, `uAberration`, `uContentRect`, `uContentStrength` | `backdrop` rgba, `content` rgba (premultiplied) | sampler 0, sampler 1 |
| 5 | light | `n`, `sd`, `uLight`, specular/rim/fresnel knobs | `Light {specular, rim, fresnel}` | — |
| 6 | composite | everything above, `mask` from `fwidth(sd)`, tint/saturation/shadow knobs | `fragColor`, premultiplied | — |

Data flow in `main()`:

```
p = FlutterFragCoord()
sd = sceneSd(p)                       // 1
aa = fwidth(sd)                       // before any branch: derivatives need uniform control flow
sdShadow = sceneSd(p + light.xy · shadowOffset)   // 1, again: only to know which side faces away from the light
floor = (dark ring outside the edge, bright band inside it), both weighted toward the far side
sd > aa  ->  fragColor = (0, 0, 0, shadow)        // early-out, 0 reads: premultiplied alpha darkens the sharp original
mask = coverage(sd, aa)
water = heightWater(p)                // 2, once: (h, dh/dx, dh/dy, envelope) over 32 sources
n = normalAt(p, water.yz)             // 3, 4x heightStatic (sceneSd + profile) + analytic water gradient
backdrop = sampleBackdrop(p, n)       // 4, 1 or 3 reads
content  = sampleContent(p, n, env)   // 4, 0 or 1 read
lt = lighting(n, sd)                  // 5
fragColor = composite(...)            // 6
```

Height is summed before the normal is taken: the glass profile and relief through
`heightStatic`, the water through its analytic gradient. No stage after 3 sees the
terms separately; the only extra output of stage 2 is the water *envelope*, which
scales content displacement so content is pixel-exact at rest.

**Water model.** Each source is a travelling packet: a Gaussian of width
`λ·(1 + age/τ)` around the front `v·age`, `cos` phase so the height is smooth at
the centre, `exp(−age/τ)` decay and `1/√(1 + front/reach)` spreading. The distance
is softened by half a wavelength for the finger's footprint. A stroke is a dense
trail of such sources — one per 0.4 λ of travel — whose rings superpose into a
smooth front (Huygens); `GlassRipples` owns that sampling rule.

## 3. Conventions

- **Units are physical pixels.** Dart multiplies every logical value (positions,
  radii, widths, `k`, `λ`) by the device pixel ratio. `uWave.x` is rad/px, `uWave.y`
  rad/s, `uWave.w` seconds; sources carry `age` in seconds (Dart computes `now − t0`,
  so the shader has no clock and no float-precision drift).
- **Coordinates** come from `FlutterFragCoord()` in the backdrop input's frame;
  `uSize` (engine-filled) is that input's size. Shapes are positioned in the same
  frame. Whether that frame is the whole screen or the filter's clip is verification
  item 2 — the answer decides what Dart subtracts before passing positions.
- **GLES Y flip** is compile-time (`IMPELLER_TARGET_OPENGLES`), applied to
  sampler 0 reads only. The content sampler is our own `ui.Image`; whether it
  needs the flip too is verification item 9.
- **No int/bool uniforms.** Shape kind and mode toggles are floats compared against
  half-way thresholds (`kind < 1.5`), `uAberration < 1e-4` means "single read",
  `uHasContent > 0.5` means "sampler 1 is valid".
- **Arrays are indexed by constants only.** `sceneSd` and `heightWater` unroll their
  loops with `SHAPE(i)` / `TOUCH(i)` macros; `MAX_SHAPES` and `MAX_TOUCHES` are
  compile-time constants. Empty slots: shape kind `0`, touch amplitude `0`.
- **Output is premultiplied** and the outside of the mask is fully transparent.
- `precision highp float` — pixel coordinates on a 3000 px screen do not fit fp16.

## 4. Uniform layout

Declaration order is the `setFloat` index. Scalars first, arrays last, so changing
`MAX_*` shifts nothing before them.

| Index | Name | Type | Floats | Meaning |
|---|---|---|---|---|
| 0 | `uSize` | vec2 | 2 | input size, px — **engine-filled** by `ImageFilter.shader` |
| 2 | `uLight` | vec3 | 3 | direction to the light, +z toward the viewer; shared with the holographic card |
| 5 | `uSmoothK` | float | 1 | `smin` radius, px |
| 6 | `uEdgeWidth` | float | 1 | squircle ramp width from the edge inward, px |
| 7 | `uGlassHeight` | float | 1 | profile amplitude, px — sets the normal's slope independently of the refraction offset |
| 8 | `uThickness` | float | 1 | backdrop refraction offset at unit slope, px |
| 9 | `uAberration` | float | 1 | per-channel offset spread; 0 = single read |
| 10 | `uTint` | vec4 | 4 | rgb, strength |
| 14 | `uSaturation` | float | 1 | 1 = unchanged |
| 15 | `uSpecular` | float | 1 | Blinn-Phong intensity |
| 16 | `uShininess` | float | 1 | Blinn-Phong exponent |
| 17 | `uRim` | float | 1 | light-facing edge highlight intensity |
| 18 | `uRimWidth` | float | 1 | edge band for rim light and inner shadow, px |
| 19 | `uFresnel` | float | 1 | Fresnel strength toward the edge |
| 20 | `uInnerShadow` | float | 1 | inner edge shadow strength |
| 21 | `uShadow` | float | 1 | dark ring outside the edge, strongest away from the light |
| 22 | `uShadowOffset` | float | 1 | ring width, px; also the silhouette shift that defines "away" |
| 23 | `uCaustic` | float | 1 | multiplicative brightening just inside the far edge |
| 24 | `uWaveCaustic` | float | 1 | floor brightening under wave crests, per k²·h, sampled at the refracted point |
| 25 | `uHasContent` | float | 1 | > 0.5: sampler 1 holds the content snapshot |
| 26 | `uContentRect` | vec4 | 4 | x, y, w, h in px — where sampler 1 sits on screen |
| 30 | `uContentStrength` | float | 1 | content displacement per px of water envelope |
| 31 | `uWave` | vec4 | 4 | k (rad/px), ω (rad/s), reach (px), τ (s) — shared by all sources |
| 35 | `uTouches[32]` | vec4[32] | 128 | per source: x, y, age (s), amplitude (px); amplitude 0 = empty |
| 163 | `uShapes[24]` | vec4[24] | 96 | 3 slots per shape, see below |
| — | **total** | | **259** | |
| sampler 0 | `uBackdrop` | sampler2D | | **engine-filled**; already blurred when frost is composed |
| sampler 1 | `uContent` | sampler2D | | content snapshot, premultiplied, `setImageSampler(1, …)` |

GLES flips sampler 0 vertically; the shader corrects it under the compile-time
`IMPELLER_TARGET_OPENGLES` macro, so no uniform is spent on it.

Shape `i` occupies floats `163 + 12·i` … `163 + 12·i + 11`:

| Slot | Components | circle | capsule | rounded box | bent capsule |
|---|---|---|---|---|---|
| 0 | kind, radius, bend, – | 1, r | 2, r | 3, corner r | 4, r, corner rounding |
| 1 | p0.xy, p1.xy | centre | a, b | centre, half-size | a, corner |
| 2 | p2.xy, –, – | | | | b |

Verified offline with this SDK's `impellerc` (3.38.9, `darwin-x64`): the skeleton
compiles for the metal, gles, gles3, vulkan and sksl stages, and every runtime
stage's metadata lists all 23 uniforms in declaration order even though most stub
bodies never read them. Indices are therefore stable while the stubs are filled in.

## 5. Stage functions

```glsl
// 1. shape field
float sdCircle(vec2 p, vec2 c, float r);
float sdCapsule(vec2 p, vec2 a, vec2 b, float r);
float sdRoundedBox(vec2 p, vec2 c, vec2 halfSize, float r);
float sdBentCapsule(vec2 p, vec2 a, vec2 c, vec2 b, float r, float bend);  // reserved kind, stubbed
float smin(float a, float b, float k);
float sdShape(vec2 p, vec4 s0, vec4 s1, vec4 s2);   // dispatch on s0.x
float sceneSd(vec2 p);                              // smin-union of MAX_SHAPES

// 2. height field
float glassProfile(float x);            // (1 - (1 - x)^4)^(1/4), x in [0, 1]
float heightGlass(float sd);            // uGlassHeight * glassProfile(-sd / uEdgeWidth)
vec4  waterRing(vec2 p, vec4 source);   // (height, dh/dx, dh/dy, envelope), analytic gradient
vec4  heightWater(vec2 p);              // sum over MAX_TOUCHES
float heightRelief(vec2 p, float sd);   // v2 slot, 0 in v1
float heightStatic(vec2 p);             // heightGlass + heightRelief — the terms without a closed-form gradient

// 3. normal
vec3 normalAt(vec2 p, vec2 waterGrad);  // central differences on heightStatic, plus the water gradient

// 4. sample
vec2 backdropUv(vec2 p);                            // px -> uv, GLES flip
vec4 sampleBackdrop(vec2 p, vec3 n);                // 1 read, or 3 with aberration
vec4 sampleContent(vec2 p, vec3 n, float waveEnv);  // 0 or 1 read

// 5. light
struct Light { float specular; float rim; float fresnel; };
Light lighting(vec3 n, float sd);       // Blinn-Phong, rim band at sd~0 modulated by n.l, Fresnel

// 6. composite
float coverage(float sd, float aa);     // 1 - smoothstep(-aa, aa, sd)
vec3  adjustColor(vec3 c);              // saturation, then tint
vec4  composite(vec4 backdrop, vec4 content, Light lt, float sd, float mask);
```

Composite order, for phase 3: `adjustColor(backdrop)` → inner shadow (band of
`uRimWidth` inside the edge) → add specular, rim, Fresnel → content srcOver the
glass → multiply by `mask` (premultiplied output).

## 6. Frost lives outside the shader

```dart
ui.ImageFilter.compose(
	outer: ui.ImageFilter.shader(shader),
	inner: ui.ImageFilter.blur(sigmaX: s, sigmaY: s),
)
```

The engine blurs the backdrop first; sampler 0 is the blurred image. Content
(sampler 1) never passes through the blur, so it stays sharp. Consequences:

- **The early-out must not read the backdrop.** Sampler 0 outside the glass is
  blurred too; reading it back would frost the whole screen. `BackdropFilter`
  composites the filter output over the original with `srcOver`, so the shader emits
  premultiplied `(0, 0, 0, shadow)`: alpha darkens the sharp original with zero reads.
  Outside the shadow ring that is `vec4(0)`. Only darkening is expressible this way —
  which is why the caustic lives inside the mask, where the backdrop is sampled and
  can be multiplied. This is verification item 4 and the skeleton is
  the test: with `sceneSd` stubbed to `FAR`, frost composed, the screen must stay sharp.
- **One frost radius per pass.** All surfaces drawn by one `LiquidGlass` share `σ`.
  Different frost per surface means a second `BackdropFilter` (a second pass).
- **The blur costs the whole filter area**, not the glass area. Whether a `ClipRect`
  around the `BackdropFilter` shrinks that area on Impeller is verification item 10.

## 7. Dart binding (sketch)

The binding passes parameters; it holds no effect maths. The one known exception is
noted in §11.

```dart
sealed class GlassShape {}
final class GlassCircle extends GlassShape { Offset center; double radius; }
final class GlassCapsule extends GlassShape { Offset a, b; double radius; }
final class GlassRoundedBox extends GlassShape { Rect rect; double cornerRadius; }
final class GlassBentCapsule extends GlassShape { Offset a, corner, b; double radius, bend; }

final class GlassWave { double k, omega, lambda, tau; }

final class GlassMaterial {
	double smoothK, edgeWidth, height, thickness, aberration;
	Color tint; double tintStrength;
	double saturation, specular, shininess, rimWidth, fresnel, innerShadow;
	double contentStrength;
	double frostSigma;   // consumed by the compose(), never reaches the shader
	GlassWave wave;
}

final class GlassTouch { Offset position; Duration startedAt; double amplitude; }

class LiquidGlass extends StatefulWidget {
	List<GlassShape> shapes;     // <= 8; extra shapes are an assertion failure
	GlassMaterial material;
	List<GlassTouch> touches;    // <= 4; the widget drops the oldest beyond that
	Vector3 light;               // same ValueListenable the holographic card reads
	Widget child;                // the scene the glass refracts
	Widget? content;             // drawn inside the glass via sampler 1
	Rect? contentRect;           // logical px, in the same frame as the shapes
}
```

Widget structure when `ui.ImageFilter.isShaderFilterSupported`:

```
BackdropGroup                       // shares one backdrop capture with other filters on the page
└─ Stack
   ├─ child                          // backdrop
   ├─ BackdropFilter.grouped(filter: compose(blur, shader))
   │    └─ SizedBox.expand()
   └─ _ContentSnapshot(rect, content)   // SnapshotWidget: paints nothing, feeds sampler 1, hit-tests
```

Per frame the state object: writes `uShapes`, `uTouches` (age from a `Ticker` that runs
only while `touches` is non-empty), `uLight`, the material block — all scaled by DPR —
calls `setImageSampler(1, contentImage)` when the snapshot changed, and hands the
shader to `ImageFilter.shader`. Sampler 0 is never set from Dart.

Index constants live in one place, mirrored from §4:

```dart
abstract final class _U {
	static const size = 0, flipY = 2, light = 3, smoothK = 6, edgeWidth = 7, glassHeight = 8;
	static const thickness = 9, aberration = 10, tint = 11, saturation = 15, specular = 16;
	static const shininess = 17, rimWidth = 18, fresnel = 19, innerShadow = 20;
	static const hasContent = 21, contentRect = 22, contentStrength = 26, wave = 27;
	static const touches = 31, touchStride = 4, shapes = 47, shapeStride = 12, total = 143;
}
```

Fallback when `isShaderFilterSupported` is false (Skia, web): `ClipPath` of the plain
union of the shapes (no `smin`, no merging) around `BackdropFilter(blur(frostSigma))`
with a translucent `tint` fill; `content` is painted as an ordinary child at
`contentRect`. Touches are ignored.

## 8. Foundation verification

Confirm in the example app before building on any of it. Ordered by what blocks
what; the skeleton as it stands is the test vehicle for 1–5.

1. **Uniform indices at runtime.** `FragmentShader` created from the skeleton accepts
   `setFloat(142, …)` and rejects `143`; `setImageSampler(1, …)` is accepted. Offline
   `impellerc` reflection says yes (§4); this checks the Dart side agrees.
2. **Coordinate frame inside `BackdropFilter`.** Does `FlutterFragCoord()` start at the
   screen's top-left in physical pixels, or at the filter's clip / widget bounds? Does
   `uSize` equal the screen or the clipped input? Draw a circle at a known logical
   position and measure. This decides what Dart subtracts before passing positions,
   and whether a partly off-screen `LiquidGlass` shifts its frame.
3. **`setImageSampler(1)` together with `ImageFilter.shader`.** The engine fills
   sampler 0 and leaves sampler 1 as set. Also: does mutating the shader's uniforms
   after `ImageFilter.shader(shader)` was constructed take effect, or must a new
   `ImageFilter` be built every frame?
4. **Transparent output leaves the original backdrop.** Skeleton + frost composed →
   the screen stays sharp everywhere. If it does not, the early-out needs a real read
   and frost must be clipped to the shapes on the Dart side (§6).
5. **`ImageFilter.compose(outer: shader, inner: blur)` on 3.38.9.** Sampler 0 is the
   blurred backdrop at the same scale (#170820 is fixed here, per `CONTEXT.md`).
6. **`SnapshotWidget` with a custom `SnapshotPainter`** can hand the content image to
   the shader without painting the child on screen, while the child still hit-tests.
   The image must be exactly `contentRect.size × DPR` pixels, or at-rest content is
   resampled.
7. **Snapshot latency.** Animate the content and compare against a frame counter; if the
   snapshot lags one frame, the widget must schedule the shader update after the
   snapshot, or accept one frame of lag for content only.
8. **`fwidth` in Impeller runtime shaders** returns sensible values at the edge and
   under a scaled `Transform`.
9. **GLES Y flip scope** (Android only): whether sampler 1 reads upside-down too.
   Low priority — iOS and macOS are Metal.
10. **`ClipRect` around the `BackdropFilter`** shrinks the blurred area on Impeller, or
    the whole screen is processed regardless (`CONTEXT.md` says the latter).

## 9. Cost per pixel

| Region | Texture reads | ALU, dominant terms |
|---|---|---|
| outside the mask (`sd > aa`) | 0 | 2 × (8 `sdShape` + 7 `smin`) + `fwidth` — the second for the shifted shadow silhouette |
| inside the mask, base | 1 | 5 × (8 `sdShape` + 7 `smin`) + 32 × `waterRing` (sin, cos, 2 exp, rsqrt) + lighting (2 pow) |
| + aberration | 3 | + 2 uv transforms |
| + content | +1 | + rect test |
| frost (engine blur, before sampler 0) | blur kernel per px over the whole filter area | — |

Rough order: outside ≈ 2×10² ops per px over the whole screen; inside ≈ 1–2×10³ ops
over the glass area. Refraction reads are scattered, so the inside cost is dominated
by cache misses rather than ALU. The 5× on stage 1 comes from the numerical
normal of the glass profile; the water gradient is already analytic. Returning
`vec3(sd, ∇sd)` from stage 1 would cut that to 1× and is the next optimisation if
profiling shows the raster thread ALU-bound. Empty shape and touch slots cost one uniform
compare each.

## 10. Open questions

Found while doing this. None reopens a settled decision.

1. **Water outside the glass.** Decision 1 promises "a ripple crossing the background
   and entering the glass". With the mask defined by `sd` alone, rings are only drawn
   inside shapes. Rendering them on the background means the early-out condition
   becomes `sd > aa && env < ε` and a cheap 1-read refraction branch runs there — the
   height field already supports it; it is a composite-stage question, not a
   height-field one. Or a shape kind "water region" with no glass profile. Decide when
   water UI (build step 4) starts.
2. **Normal step.** `NORMAL_STEP = 1` physical px means the slope estimate changes
   with DPR. A DPR-scaled step (uniform or constant) may be better; decide by eye.
3. **Glass over a transparent backdrop.** `composite` sets alpha = `mask`, treating
   the glass as opaque. Over a transparent region of the backdrop the tint shows at
   full strength; probably fine, may want `backdrop.a` folded in.
4. **`uAberration` is both toggle and magnitude.** The threshold `1e-4` is fine unless
   someone animates it through zero; then the branch flips one frame late at most.
5. **Touch slot policy.** 4 slots. Dropping the oldest is the obvious rule; an
   alternative is dropping the one with the smallest remaining envelope.
6. **Material is per pass.** Two surfaces with different tint need two passes. If
   that turns out common, a per-shape material index into a small material array is
   the next layout change (shifts the arrays' indices).
7. **Frost radius is per pass** (§6). Same trade-off as 6.
8. **Snapshot filtering.** The content sampler must use linear filtering with no mip
   levels; at rest the read lands on texel centres so linear = exact. Verify
   `setImageSampler` defaults.

## 11. Deferred, with the reason

- **Bent capsule content positioning.** Content in v1 is rectangular. Laying content
  along a bent capsule needs the same polyline-with-rounded-corner geometry on the Dart
  side to place widgets — the one known place where maths would be duplicated in Dart.
  Out of scope; when it lands, the Dart path builder and `sdBentCapsule` must agree
  on the corner rounding definition.
- **Metaball union**: swap `smin` in `sceneSd`, nothing else moves.
- **Fluted glass**: fill `heightRelief`; mip-level selection against rib width to
  avoid moiré belongs in stage 4 at that point.
- **Analytic gradient**: §9.
