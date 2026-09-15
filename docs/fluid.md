# Fluid — design and spike results

Design and data flow of `shaders/fluid_*.frag`, its Dart binding in
`lib/src/fluid/`, and the multi-pass primitive that runs them. Settled decisions
it builds on are in `CONTEXT.md` (4: transitions freeze snapshots, 5: all maths
in `.frag`).

## Attribution

The solver is a port of
[WebGL-Fluid-Simulation](https://github.com/PavelDoGreat/WebGL-Fluid-Simulation)
by Pavel Dobryakov — **MIT License, Copyright (c) 2017 Pavel Dobryakov**. Every
`.frag` carries the same notice in its header. Bloom and sunrays are not ported.

## 1. Scope

Jos Stam's *Stable Fluids* (GPU Gems 38) on the GPU: splat velocity under the
finger, confine vorticity, project the velocity field divergence-free with a
Jacobi pressure solve, advect. The novelty here is the dye: instead of coloured
ink, it is a **`toImageSync` snapshot of a live widget**, so a card looks solid
until it is touched and then flows, swirls and dissipates.

| Pass | `.frag` | Grid | Reads | Writes |
|---|---|---|---|---|
| splat | `fluid_splat` | sim | velocity | velocity |
| curl | `fluid_curl` | sim | velocity | curl |
| vorticity | `fluid_vorticity` | sim | velocity, curl | velocity |
| divergence | `fluid_divergence` | sim | velocity | divergence |
| pressure × N | `fluid_pressure` | sim | pressure, divergence | pressure |
| gradient subtract | `fluid_gradient` | sim | pressure, velocity | velocity |
| advect velocity | `fluid_advection` | sim | velocity | velocity |
| advect dye | `fluid_advection` | dye | velocity, dye | dye |
| display | `fluid_display` | canvas | dye | the screen |

Passes per frame = `6 + pressureIterations` offscreen, plus one splat per pointer
move and one on-screen draw. At the default 20 iterations that is **26 offscreen
passes per card per frame**.

Dobryakov's separate `clear` pass (which scales the previous pressure field by
`PRESSURE` before the sweeps) is folded into the first Jacobi sweep as the
`uDecay` uniform — algebraically identical, one pass fewer.

## 2. The multi-pass primitive

This is the third shader primitive after *self-contained* and *over a child
snapshot*. `lib/src/fluid/passes.dart` holds it and knows nothing about fluids.

A pass is: set uniforms and `setImageSampler`s on a `FragmentShader` → record a
full-target `drawRect` into a `PictureRecorder` → `Picture.toImageSync(w, h)` →
hand the `ui.Image` to the next pass as a sampler.

Three things this primitive does *not* work like in WebGL:

- **There is no ping-pong pair.** `toImageSync` always allocates a new texture,
  so a "read" target and a "write" target cannot alternate; every pass produces a
  fresh image and the previous one is retired. `Field` is therefore a single slot,
  not a pair. Impeller's own render-target pool is what keeps this from being a
  per-frame allocation storm.
- **Images are freed a frame late.** `toImageSync` rasterises lazily, so
  `PassRunner.recycle()` frees the images retired during the *previous* step, not
  the current one. At sim 128 the working set is a few MB.
- **`BlendMode.src`, not the default `srcOver`.** Field data is not colour; it
  must land in the target byte for byte with no blend against the clear value.

Uniforms are snapshotted when the `drawRect` is recorded, which is what makes the
20 pressure sweeps reusable from one `FragmentShader` instance.

## 3. Storage: RGBA8 packing, and float32

`toImageSync` takes a `TargetPixelFormat`. On this SDK (3.47.4, Impeller/Metal)
`dontCare` gives RGBA8 and **`rgbaFloat32` is available and works**.

Velocity, curl, divergence and pressure are all signed, so on RGBA8 they are
packed affinely into 0..1:

```
store   = value * code.x + code.y
restore = (store - code.y) / code.x
```

with `code = (1 / (2 * range), 128 / 255)` packed, or `(1, 0)` on a float target.
Each field has its own `range` in `FluidConfig` (`velocityRange`, `curlRange`,
`divergenceRange`, `pressureRange`) because curl and divergence are differences of
neighbouring velocities and are an order of magnitude smaller than velocity
itself — giving them the velocity range would throw away five bits.

Two details make the packing usable:

- **The bias is `128/255`, not `0.5`.** A zero field has to be representable
  exactly, or a cleared velocity buffer carries a constant drift. `128/255` is
  the byte 128 on the nose; `0.5` is not a representable byte value.
- **The encoding is affine, so hardware filtering commutes with it.** Bilinear
  interpolation of packed values equals the packed value of the interpolation —
  which a non-linear packing (a hi/lo byte split) would not give.
- **Alpha is not available as a data channel.** Flutter images are
  premultiplied; a field image must keep `a = 1` and use RGB only. That is why a
  16-bit two-channel split cannot hold a 2-component velocity: it needs four
  channels and only three are usable.

**Verdict (measured, see §6).** RGBA8 packing is *stable* — the sim runs, the
pressure solve converges, nothing blows up or dies in a dead zone. But it is
visibly worse: the quantisation noise in the velocity field frays every dye edge
into a ragged, chewed fringe and stirs the dye with noise that is not fluid
motion. Side by side at the same moment, `rgbaFloat32` keeps the card's rounded
corners crisp and rolls a clean vortex spiral where the packed run has grain.
Since float32 targets cost nothing measurable here (§6), **the packing is a
fallback for platforms without float render targets, not the default to ship**.
`FluidConfig.floatFields` switches between them.

## 4. Dye = widget snapshot

The dye reuses `SnapshotHost` / `ChildSnapshot` from `lib/src/snapshot/` — the
same primitive disintegration uses. Capture happens on pan start while the child
is still painted, then the child is hidden and the painter gets a canvas grown by
`spread` on every side.

The dye texture covers **card + `spread` on every side**, so smoke can leave the
card. Its resolution is the snapshot's own device resolution, capped at
`dyeResolution` on the long side (512 by default).

- With `dyeResolution: 0` the dye is at device resolution and a frozen card with
  zero velocity renders within 1 LSB of the live child (measured, §6): `_seedDye`
  draws the snapshot at scale 1 with `FilterQuality.none`, advection with zero
  velocity back-traces to exactly `uv`, and both `bilerp` helpers land on exact
  texel centres, so `floor`/`fract` give the source texel untouched.
- With the 512 cap the seed is resampled and the card is visibly softer the
  moment the effect starts. An untouched card is still literally pixel-identical
  because the effect is not running at all — `SnapshotHost` shows the live
  child — but the first touched frame pops.

Dye is stored premultiplied, which is also the correct space to interpolate in;
dissipation divides all four channels, so the smoke thins without tinting.

**Dissipation applies everywhere, not only where the fluid moves.** Dobryakov's
`DENSITY_DISSIPATION` is global, so the whole card starts fading the instant the
effect begins, even the parts the finger never reached. Faithful to the original,
and worth revisiting if this becomes a product.

## 5. Boundaries, and the y axis

The sim runs in Flutter's y-down frame. Mirroring the world flips the sign of the
curl *and* of the confinement force, so Dobryakov's formulas carry over with no
sign changes at all — the `.frag` files are his, unedited in that respect.

Every neighbour sample is clamped to the texture by hand
(`clamp(uv, 0.5 * texel, 1 - 0.5 * texel)`) rather than trusting the sampler's
tile mode, which Flutter does not expose. Divergence keeps his free-slip walls.

Those walls trap the dye inside the canvas: without help, the effect ends as a
uniformly filled rectangle with a hard edge. `edgeFade` fades the display over a
band at the canvas border, the same trick `uEdgeFade` plays in disintegration.

## 6. Spike measurements

macOS, Apple Silicon, `flutter run --profile -d macos --enable-impeller`, three
cards of 150 x 200 at DPR 2 with `spread` 90 -> a 660 x 760 px canvas each, dye
capped at 512. Means over 120 frames with a synthetic finger stirring all three
cards continuously. Passes are **per card**, so the frame runs three times that.

| Run | passes / frame / card | build ms | raster ms |
|---|---|---|---|
| idle, no effect | 0 | 0.17 | 1.41 - 1.62 |
| sim 128, pressure 20, RGBA8 | 26 | 1.02 | 1.98 |
| sim 128, pressure 8, RGBA8 | 14 | 0.81 | 1.61 |
| sim 128, pressure 4, RGBA8 | 10 | 0.82 | 1.61 |
| sim 64, pressure 8, RGBA8 | 14 | 0.92 | 1.55 |
| sim 128, pressure 40, RGBA8 | 46 | 1.42 | 1.89 |
| sim 128, pressure 20, float32 | 26 | 1.18 | 2.38 |
| sim 128, pressure 8, float32 | 14 | 0.84 | 1.70 |
| sim 256, pressure 20, RGBA8 | 26 | 1.16 | 2.62 |
| sim 256, pressure 20, float32 | 26 | 1.57 | 3.20 |

**Idle is not a small number, it is no work at all.** With no effect running
there is no ticker, no pass, nothing dirty; the demo has to call
`scheduleForcedFrame` just to produce frames to measure, and the 1.4 - 1.6 ms it
reports is the cost of recompositing the demo scene, which the fluid never pays.

Read the table as deltas over that baseline. At the default sim 128 / 20
iterations, 78 offscreen passes per frame cost about **0.4 ms of raster and
0.85 ms of build** for three simultaneous cards. Quadrupling the grid area
(sim 256) costs about 1 ms of raster; float32 targets cost about 0.4 ms more than
RGBA8 at sim 128 and 0.6 ms at sim 256.

Two conclusions:

- **Multi-pass ping-pong fits the budget with room to spare.** The whole thing is
  a fraction of an 8 ms frame at 120 Hz, and the grid is small enough that
  raster time barely moves with the pressure iteration count.
- **The UI thread is the limit, not the GPU.** Build goes from 0.17 ms idle to
  1.42 ms at 138 passes per frame - roughly 9 us per pass of Dart-side uniform
  writing and picture recording, and it scales linearly with passes x cards.
  Three cards at 20 iterations is fine; a list of twenty would not be.

### Does the untouched card survive the round trip?

Measured by freezing the card with a zero-length stroke (no splat, so velocity
stays zero) and comparing the rendered frame against the live child, with
`densityDissipation` set to 0 so the global fade does not confound it:

| dye resolution | max channel diff | pixels off by > 4 |
|---|---|---|
| native (`dyeResolution: 0`) | **2 / 255** | 0 |
| capped at 512 | 167 / 255 | 30 058 |

At native resolution the seed, the identity advection and the display sample all
land on exact texel centres; the residual 1 LSB is the RGBA8 dye round trip, not
a resampling blur. At the 512 cap the card visibly pops the moment it is touched.
For the "solid until touched" illusion, **do not cap the dye**.

Note that with Dobryakov's `DENSITY_DISSIPATION` of 1 the card starts fading the
instant the effect begins even with zero velocity (see section 4), so identity
only holds for the first frames unless the dissipation is gated on local speed.

### What the frames show

- **Untouched**: literally the live child - the effect is not running.
- **0.3 s after a diagonal stroke**: the card still reads as a card, rounded
  corners intact, with a liquid bulge pouring out of the swipe's exit corner and
  the title dragged into a bright filament along the stroke.
- **1.0 s**: the lower half has rolled into a clean vortex spiral; the body is
  still recognisable and the text is legible but smeared.
- **2.5 s**: a ghost. The smoke curl at the bottom is still structured, but the
  card body has faded roughly uniformly rather than flowed away - the global
  dissipation, not the fluid, is what removes it.
- **1.5 s after a second fast horizontal stroke through the dissolving smoke**:
  textbook Kelvin-Helmholtz mushrooms and curls across all three cards. Faint,
  because the dye is already thin by then.

`SPLAT_FORCE` 6000 is Dobryakov's, and his canvas is the whole window. The same
number over a 330 logical px card makes the finger travel about five times more
uv per frame, so the card does not flow, it detonates - at 0.3 s there is no card
left. The captures above use 1200, which is the same effect at his effective
strength. A force normalised per logical pixel rather than per uv would carry
across sizes; that was not in scope for the spike.

### One thing not reproduced

A single run showed the middle of the three cards dissolving far more violently
than its neighbours from identical input. Two subsequent runs at the same
settings produced three byte-identical cards, and it has not reappeared; it was
most likely a hot restart landing mid-stroke. Recorded here because it was seen,
not because it is understood.

## 7. Traps hit while building this

- **A sampler cannot be a function parameter in SkSL.** `vec4 bilerp(sampler2D
  s, ...)` compiles for Impeller and fails the SkSL target, which makes the whole
  `.frag` refuse to load on Skia. Read the sampler directly from the global.
- **Uniform indices are the declaration order**, and each of the eight programs
  has its own block; `_U` in `solver.dart` mirrors all eight.
- `FragmentProgram.fromAsset` paths are
  `packages/amazing_flutter/shaders/<name>.frag`.
