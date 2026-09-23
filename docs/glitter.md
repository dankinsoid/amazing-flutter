# Glitter — design

Design and data flow of `shaders/glitter.frag` and its Dart binding in
`lib/src/glitter/`. A port of the Metal `GlitterSurface` from ReferenceCam, so
this file is mostly about what the port keeps, what it cannot keep, and why.

## 1. Scope

A flat tone dusted with tiny mirrors. Each flake owns a random tilt and flashes
only while the virtual light lines up with it, so the surface lives off movement
rather than off a clock: hold the phone still and it settles, move it and it
winks. It is a self-contained pass — it paints its own base, samples nothing, and
needs no Impeller, so it is the cheapest primitive in the repo.

The original is `ReferenceCam/Views/Glitter/`: a `CAMetalLayer` at 30–60 fps with
a `CADisplayLink`, driven by `CMMotionManager` gravity.

| The Metal version | Here |
|---|---|
| `CAMetalLayer`, `rgba16Float`, `extendedLinearSRGB` | Flutter's own SDR surface, one `drawRect` |
| flashes spill past white by `currentEDRHeadroom` | they clip at white — see §5 |
| `CADisplayLink` at 30 fps resting, 60 moving | a `Ticker`; Flutter has no frame-rate range |
| render scale pinned to 2.0 | whatever the device pixel ratio is |
| `CMMotionManager` gravity | `sensors_plus` raw accelerometer, negated |

## 2. The pass

One `CustomPaint` over the panel rect. `FlutterFragCoord()` is the painter's own
local logical px, so the flake cell sizes are logical px and a flake is the same
physical size on any device — the same choice the Metal version makes by working
in points.

Nothing is sampled and nothing is captured, so there is no snapshot, no backdrop
and no fallback path. A `child` is painted over the glitter by the framework.

## 3. The light, and why it is absolute

`uLight` is a direction, −1..1 per axis, and it is the *absolute* pose of the
surface, not a delta from a drifting rest pose the way `HoloCard`'s tilt is.
Glitter that flattened out on a held tilt would stop answering the hand, which is
the whole effect.

The accelerometer measures the reaction to gravity and so points the other way:
`x = −event.x / g` is the left-right lean, `z = −event.z / g` the front-back one.
A `+0.35` bias on the z axis centres the light on a hold of ~20° off flat, where
a phone actually sits. One Euro smooths both axes; there is no `DriftFilter`
here, by the paragraph above.

On a desktop the pointer over the panel aims the same light, and with neither
input `restAgitation` pins the agitation part-way up so the surface still lives.

## 4. Two clocks

**`agitation`**, 0..1, is how much the surface is being moved. It is measured off
a heavily smoothed tilt (`_steadying = 0.30`): hand tremor cancels itself out
there, a deliberate turn does not, so the speed of the smoothed signal tells the
two apart. A `_tremorFloor` rejects what is left, and attack/release easing
(~130 ms up, ~220 ms down) keeps it from switching.

**`flicker`** is the clock the per-flake blink phases run on, and it is
*integrated* at a rate of `0.06 + 0.94 · agitation` rather than scaled off the
frame timestamp. Scaling the timestamp directly would jump the phase whenever the
rate changed and wink every flake at once. The floor keeps a resting surface
breathing instead of frozen.

Both wrap at 3600 s; the shader works in float32.

The Metal version also drops its display link to 30 fps at rest, which Flutter
cannot express — `Ticker` runs at whatever the engine schedules. The idle drift
that keeps a resting surface alive (`idleDrift + movingDrift · agitation`) is
kept, because against these narrow specular lobes a dead light reads as a dead
panel.

## 5. EDR, and what is lost

This is the one part of the original that does not port.

The Metal version renders into an `rgba16Float` drawable in
`extendedLinearSRGB`, asks the screen for `currentEDRHeadroom`, and lets the
flash term alone go past 1.0 — on an HDR panel a flake is genuinely brighter than
SDR white, which is what makes real glitter read as *specular* rather than as
white paint.

Flutter has no equivalent, and not for want of a flag: as of 3.47.4 `dart:ui`
contains no HDR, EDR or headroom API at all. `ColorSpace.extendedSRGB` and
`displayP3` are **gamut**, not brightness — wider colours under the same SDR
white point. So the flash clips:

```glsl
fragColor = vec4(clamp(base + grain * texture + flash, 0.0, 1.0), 1.0);
```

Trading the lost brightness for area was tried — growing a clipped flake instead
of overdriving it — and rejected: glitter is small by nature, and a flake that
grows stops reading as glitter. The port clips honestly and the difference is
visible next to the iOS app on an HDR display.

The only way to get the real thing in a Flutter app is a platform view owning its
own `CAMetalLayer` with `wantsExtendedDynamicRangeContent`, which is the Swift
code unchanged and not a Flutter shader at all.

## 6. Uniform table

Declaration order *is* the `setFloat` index; `_U` in `glitter_surface.dart`
mirrors it.

| Index | Uniform | Meaning |
|---|---|---|
| 0–2 | `uBase` | base tone, sRGB as painted |
| 3–4 | `uLight` | virtual light tilt, −1..1 per axis |
| 5 | `uFlicker` | flicker clock, s |
| 6 | `uFlakeScale` | flake cell size multiplier, 1 = ~2 logical px |
| 7 | `uDensity` | multiplies the fraction of cells holding a flake |
| 8 | `uGain` | flash brightness |
| 9 | `uRainbow` | iridescence, 0 = warm white flakes only |
| 10 | `uGrain` | micro-grain over the base |
| 11 | `uSeed` | shifts every hash |

12 floats, no samplers. What stays hardcoded in the shader is the two-layer
geometry — cell sizes 2.1 and 3.6, densities 0.65 and 0.22, specular exponents
220 and 320 — because those shape the effect rather than dress it, and the
multipliers above already reach everything a caller wants to move.

## 7. The flake

Per cell, from one `hash32` of the cell id:

- **A mirror.** `normal = normalize(vec3((r.xy·2−1)·0.75, 1))`, and the flash is
  `pow(max(dot(normal, light), 0), sharpness)` with an exponent of 220 or 320 —
  a lobe so narrow that the smallest movement sweeps the highlight off one flake
  and onto the next. That narrowness *is* the effect; a wide lobe reads as a
  sheen.
- **A blink.** A per-flake phase on the flicker clock with a narrow duty cycle:
  real flakes wink in and out rather than breathe.
- **A glint.** A broader, weaker lobe (`facing^22`) on its *own* phase and tempo,
  scaled by squared base luminance. It is what makes the glitter read at rest on
  light tones; sharing the specular phase would collapse both layers into one
  synchronized pulse.
- **A dot mask.** The flash is confined to a small dot placed off-centre in its
  cell, so the grid never reads as a grid.
- **A hue.** Each flake owns a hue offset and the hue slides with the light
  angle, so tilting sweeps rainbow across the surface. Roughly half the flakes
  stay warm white, or the surface reads as candy.

The base also gets micro-grain, faded out below 0.15 and above 0.95 luminance:
the grain is additive, so on pure black it would lift the tone to grey and on
pure white its negative half would dust it with grey specks.

## 8. Open

- **Not benchmarked yet** against `BackdropFilter.blur` (decision 7). Two hash
  calls and two `pow`s per pixel over a full-bleed panel is the cost to measure.
- **No LOD.** The Metal version renders at a fixed 2.0 scale because flakes are
  high-frequency noise that survives undersampling; here a 3× device pixel ratio
  pays full price for detail below what the eye resolves.
- **Verified on macOS/Impeller only.** The sensor path has no platform there, so
  the light comes from the pointer; the gravity mapping in §3 is derived, not
  measured on a device.
