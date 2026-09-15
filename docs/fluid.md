# Fluid — design and measurements

Design and data flow of `shaders/fluid_*.frag`, its Dart binding in
`lib/src/fluid/`, and the multi-pass primitive that runs them. Settled decisions
it builds on are in `CONTEXT.md` (1: one field in screen coordinates, 4:
transitions freeze snapshots, 5: all maths in `.frag`).

## Attribution

The solver is a port of
[WebGL-Fluid-Simulation](https://github.com/PavelDoGreat/WebGL-Fluid-Simulation)
by Pavel Dobryakov — **MIT License, Copyright (c) 2017 Pavel Dobryakov**. Every
`.frag` carries the same notice in its header. Bloom and sunrays are not ported.

## 1. Scope, and the one domain

Jos Stam's *Stable Fluids* (GPU Gems 38) on the GPU: splat velocity under the
finger, confine vorticity, project the velocity field divergence-free with a
Jacobi pressure solve, advect. The novelty here is the dye: instead of coloured
ink, it is a **`toImageSync` snapshot of a live widget**, so a card looks solid
until it is touched and then flows, swirls and dissipates.

**There is one simulation domain per scene, not per card.** `FluidScene` owns the
whole field, in its own coordinates; a `Fluid` child stamps its snapshot into the
dye at its screen rect and hides itself. This is decision 1 of `CONTEXT.md`
applied to the fluid, and it is not a detail:

- A per-card domain is a **visible rectangle**. Free-slip walls at the card's
  own border plus a margin mean the smoke piles up against a box the size of the
  card, and the eye reads the box before it reads the fluid.
- Smoke from one card can now drift across the screen and past its neighbours,
  and a stroke between two cards stirs both. There is one velocity field, so
  there is one flow.
- **Cost stops scaling with the number of cards.** The pass count is a property
  of the scene; ten cards cost the same as one. The per-card spike paid
  26 passes *per card per frame*, and the UI thread was the ceiling.

| Pass | `.frag` | Grid | Reads | Writes |
|---|---|---|---|---|
| stamp | — (canvas) | dye | dye, snapshot | dye |
| splat | `fluid_splat` | sim | velocity | velocity |
| curl | `fluid_curl` | sim | velocity | curl |
| vorticity | `fluid_vorticity` | sim | velocity, curl | velocity |
| divergence | `fluid_divergence` | sim | velocity | divergence |
| pressure × N | `fluid_pressure` | sim | pressure, divergence | pressure |
| gradient subtract | `fluid_gradient` | sim | pressure, velocity | velocity |
| advect velocity | `fluid_advection` | sim | velocity | velocity |
| advect dye | `fluid_advection` | dye | velocity, dye | dye |
| display | `fluid_display` | scene | dye | the screen |

Passes per frame = `6 + pressureIterations` offscreen, plus one splat per pointer
move, one per stamp, and one on-screen draw. At the default 20 iterations that is
**26 offscreen passes per frame for the whole scene**.

Dobryakov's separate `clear` pass (which scales the previous pressure field by
`PRESSURE` before the sweeps) is folded into the first Jacobi sweep as the
`uDecay` uniform — algebraically identical, one pass fewer.

## 2. Units: force and radius per logical pixel

Dobryakov's `SPLAT_FORCE` multiplies a delta measured in **uv**, so the same
number means a different push on every canvas size; the spike had to hand-pick
1200 for a 330 px card where his own value is 6000. Both splat knobs are now in
screen units:

```
splatForce   1/s          flow speed gained per px of finger travel
splatRadius  logical px   radius where the velocity blob falls to 1/e
```

The conversion is one scale, because the sim grid is proportional to the scene
and its texels are square in px:

```
dv[texels/s] = splatForce * delta[px] * simH / sceneHeight[px]
```

Read `splatForce` as the reciprocal of a time constant: at 10, dragging at a
constant speed for 0.1 s brings the fluid under the finger up to the finger's own
speed. That is frame-rate independent (the total over a stroke is
`splatForce × path length`), DPR independent, and identical on a 150 px card and
a 1000 px one. Dobryakov's aspect correction for round splats falls out — with
the delta in texels there is no anisotropy left to correct.

The spike's 1200-per-uv over its 330 × 380 canvas at sim 128 works out to 9.4;
the default is **10**.

## 3. Local dissipation: the card is solid until it flows

Dobryakov's `DENSITY_DISSIPATION` is global, so the whole card starts fading the
instant the effect begins, even the parts the finger never reached. The card
does not flow away, it *washes out* — which is the one thing a widget-as-dye must
not do, because the widget is supposed to look untouched until it is touched.

The dye decay is therefore gated on the local flow speed, in the advection pass:

```glsl
float local = uSpeedRef > 0.0 ? smoothstep(0.0, uSpeedRef, length(velocity)) : 1.0;
float decay = 1.0 + uDissipation * uDt * local;
```

`uSpeedRef` is `dissipationSpeed` (logical px/s) in grid texels/s; the velocity
advection pass passes 0 and keeps Dobryakov's plain global decay.

Why `smoothstep` from zero and not a linear ramp: the pressure solve is a global
Poisson solve, so a splat in one corner induces a small velocity *everywhere* in
the domain. `smoothstep(0, r, v)` is quadratic near zero, so a flow at a tenth of
the reference loses 2.8 % of its dye per second instead of 10 % — the difference
between "the far corner is solid" and "the far corner is visibly greying".

**A separate advected `disturbed` scalar was not needed.** The alternative design
— splat a scalar under the finger, advect it with the dye, decay the dye by it —
buys the ability to keep fading dye that has *stopped* moving. The frames say the
fluid does not stop: `velocityDissipation` 0.2/s leaves 55 % of the velocity after
three seconds, and vorticity confinement keeps feeding the eddies, so flowed dye
keeps flowing for the whole lifetime and keeps thinning. A second scalar field
would cost an advection pass and a texture for a case the default config never
reaches. It is the right answer for a much longer lifetime, and nothing else in
the design has to change to add it.

Termination does not lean on dissipation at all. The scene runs for `lifetime`
seconds after the last finger lifts, and the display pass multiplies by an
`opacity` that ramps to zero over the final `fadeOut` seconds. The clock does not
run while a finger is down, so **the global fade can never start mid-stroke**.

## 4. Lifetime, stirring, and taps

The scene's clock is a settle clock, not a countdown from the first touch:

- It **pauses** while any pointer is down or a scripted stroke is running, and
  resumes on release. Stirring never runs out under your finger.
- A **new stamp restarts it**. Dye that has just entered the field gets a full
  lifetime; stirring dye that is already there does not buy more.
- A pointer landing on a card that is already dye only **stirs** — the stamp
  happens once, on the down that hides the child.

A tap is not free: `Fluid` stamps on pointer down, so even a tap turns the card
into dye and starts the lifetime, with almost no velocity in the field — the card
sits still and then fades out over `fadeOut`. There is deliberately **no spring-back**.
Disintegration can heal a scratch because its progress is a scalar it can drive
back to zero; a fluid has no such handle — the dye has already been composited
into a shared field and mixed with whatever else is in it, and there is nothing
to run backwards. If a tap must not destroy a card, gate it in the app: pass
`enabled: false` and call `controller.stamp()` from a real drag recognizer.

## 5. Storage: RGBA8 packing, and float32

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

**Verdict (measured, §7).** RGBA8 packing is *stable* — the sim runs, the
pressure solve converges, nothing blows up or dies in a dead zone. But it is
visibly worse: the quantisation noise in the velocity field frays every dye edge
into a ragged, chewed fringe and stirs the dye with noise that is not fluid
motion. Since float32 targets are cheap at the scene's sim size, **`floatFields`
defaults to 1** and the packing is the fallback for platforms without float
render targets. The dye itself is always RGBA8 — it is colour, not a field.

## 6. Dye = widget snapshots, stamped

A `Fluid` child wraps its subtree in a `RepaintBoundary`, and on pointer down
(or `controller.stamp()` / `controller.play()`) it calls `toImageSync`, hands the
image to the scene, and hides itself behind a `Visibility`. The scene composites
it into the dye texture at the child's rect with a plain canvas draw, and retires
the image through the `PassRunner` — `toImageSync` rasterises lazily, so the
child must not free it.

The dye covers the whole scene at the scene's device resolution. Three things
keep the stamp exact:

- the stamp rect is snapped to whole **device** pixels,
- at dye scale 1 the draw is `FilterQuality.none`,
- advection with zero velocity back-traces to exactly `uv`, and both `bilerp`
  helpers land on exact texel centres, so `floor`/`fract` return the source texel
  untouched.

Measured: a stamped card with zero velocity is **byte-identical** to the live
child over the whole 1600 × 1200 frame — max channel difference 0 (§7). With a
`dyeResolution` cap the seed is resampled and the card visibly softens the moment
it is stamped, which is why the default cap is 0.

Dye is stored premultiplied, which is also the correct space to interpolate in;
dissipation divides all four channels, so the smoke thins without tinting.

`Fluid` does not reuse `SnapshotHost` from `lib/src/snapshot/`: that primitive
hands a painter a canvas over one child, and here there is no per-child painter —
the scene paints one dye layer for everybody.

## 7. Boundaries, and the y axis

The sim runs in Flutter's y-down frame. Mirroring the world flips the sign of the
curl *and* of the confinement force, so Dobryakov's formulas carry over with no
sign changes at all — the `.frag` files are his, unedited in that respect.

Every neighbour sample is clamped to the texture by hand
(`clamp(uv, 0.5 * texel, 1 - 0.5 * texel)`) rather than trusting the sampler's
tile mode, which Flutter does not expose. Divergence keeps his free-slip walls.

Those walls are now the **screen edges**, which is the whole point of §1: dye
piling against them reads as dye running off the screen, not as a box around a
card. `edgeFade` still fades the display over a band at the scene border so the
pile has no hard line.

## 8. The multi-pass primitive

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
  the current one. That is why the live-image count sits at roughly two frames of
  passes, and why it is *flat*, not growing (§9).
- **`BlendMode.src`, not the default `srcOver`.** Field data is not colour; it
  must land in the target byte for byte with no blend against the clear value.

Uniforms are snapshotted when the `drawRect` is recorded, which is what makes the
20 pressure sweeps reusable from one `FragmentShader` instance.

## 9. Measurements

macOS, Apple Silicon, `flutter run --profile -d macos --enable-impeller`, an
800 × 600 window at DPR 2 — a 1600 × 1200 scene — with three 150 × 200 cards
stamped and a synthetic finger stirring continuously. Means over 120 frames.
Passes are for the **whole scene**, not per card.

| Run | passes / frame | build ms | raster ms |
|---|---|---|---|
| idle, no dye | 0 | 0.06 | 0.47 |
| **sim 256, pressure 20, dye native, float32** (default) | 26 | **0.91** | **2.42** |
| sim 256, pressure 8, dye native, float32 | 14 | 0.62 | 2.00 |
| sim 128, pressure 20, dye native, float32 | 26 | 0.80 | 1.54 |
| sim 256, pressure 20, dye native, rgba8 | 26 | 0.71 | 1.35 |
| sim 256, pressure 20, dye capped at 1024, float32 | 26 | 0.87 | 1.94 |
| sim 384, pressure 20, dye native, float32 | 26 | 1.03 | 3.42 |
| idle again | 0 | 0.08 | 0.59 |

**Idle is not a small number, it is no work at all.** With no dye there is no
ticker, no pass, not one `ui.Image`; the demo has to call `scheduleForcedFrame`
just to produce frames to measure, and the 0.5 ms it reports is the cost of
recompositing the demo scene, which the fluid never pays. Read the table as
deltas over that row.

The default costs about **2 ms of raster and 0.85 ms of build** — a quarter of an
8 ms frame at 120 Hz, for the whole scene however many cards are in it. What the
rows say:

- **The dye pass is the expensive one, not the solve.** Dropping the pressure
  sweeps from 20 to 8 removes 12 of 26 passes and saves 0.4 ms; dropping the sim
  grid from 256 to 128 (a quarter of the texels in every sim pass) saves 0.9 ms;
  capping the dye at 1024 saves 0.5 ms on its own. The dye is 1600 × 1200 and the
  sim is 256 × 192, so one dye advection moves more bytes than all 26 sim passes.
- **float32 costs about 1.1 ms of raster over RGBA8** at sim 256 — four times the
  bandwidth in every sim pass. It buys clean vortex spirals instead of a
  quantisation fringe, and at 2.4 ms total it is affordable; on a platform without
  float render targets, `floatFields: 0` is a working fallback, not a downgrade to
  something broken.
- **sim 384 is where it starts to hurt** — 3.4 ms of raster for detail the dye
  cannot show much of anyway. 256 is the knee.
- **The UI thread is no longer the ceiling.** The spike paid 26 passes *per card*
  and 1.18 ms of build for three cards at sim 128; one scene pays 0.91 ms at sim
  256 over a full-screen dye, and adding cards does not move it.

The working set is roughly two frames of pass targets: the census prints
**58 live `ui.Image`s, flat**, for as long as the scene runs (§8 explains why they
are freed a frame late) — about 40 MB of sim targets plus three full-screen dye
images. Idle it is 0.

### Resource hygiene

`example/lib/fluid_demo.dart` has a `_debugCensus` hook that counts every
`ui.Image` in the process through `ui.Image.onCreate` / `onDispose` and prints it
once a second alongside the solver's own count. Over a 37-second run with a stamp,
a stroke and a frozen clock:

```
fluid census: ui.Image live=1  solver=0  passes=0  status=idle       <- before the stamp
fluid census: ui.Image live=58 solver=57 passes=26 status=settling   <- and 35 more lines, all 58
```

Flat, not growing: 57 solver images (two frames of pass targets plus the five
live fields) and one belonging to the app. The three card snapshots are gone —
they are retired through the `PassRunner` after the stamp composites them, which
is also why `Fluid` must not dispose them itself. **Idle is one image and zero
passes**: no dye, no ticker, nothing scheduled. When the lifetime expires the
scene frees every buffer, stops the ticker, and drops the painter from the tree;
the 4.3 s frame below is byte-identical to the untouched one.

### Does a stamped card survive the round trip?

| dye resolution | max channel diff | pixels off by > 4 |
|---|---|---|
| native (`dyeResolution: 0`) | **0 / 255** | 0 |

Measured by stamping every card with no pointer motion at all, freezing the
settle clock, and comparing the rendered frame against the same frame before the
stamp. The two PNGs are byte-identical, MD5 and all. The spike's 2/255 residual
is gone because the dye no longer carries the card through a resample.

### What the frames show

Captured from inside the app (`example/lib/snap.dart`) with synthetic strokes
dispatched as real `PointerDownEvent`/`PointerMoveEvent`/`PointerUpEvent` through
`WidgetsBinding.instance.handlePointerEvent`, so the hit test and the widget tree
see an ordinary finger. Three 150 × 200 cards, one diagonal stroke per card from
card-local (18, 24) to (132, 176) over 0.25 s starting at t = 0.8 s.

- **Untouched** — the live cards; the effect is not running, no ticker, no pass.
- **0.3 s after the stroke** — the cards still read as cards: rounded corners
  intact, titles legible, the three body rules still crisp. A liquid bulge pours
  out of the swipe's exit corner and the title is dragged into a bright filament
  along the stroke. The left and bottom thirds of each card are at full strength.
- **1.0 s** — each card has rolled a clean vortex below itself, well outside its
  own footprint, and the card bodies are still saturated. Median brightness inside
  the original card rect is 191 / 177 / 214 against 214 / 199 / 251 for the live
  card: down 11–15 %, all of it displacement rather than fade.
- **2.5 s** — the plumes have thinned and spread across the lower half of the
  scene, one card's dye reaching into its neighbour's column. The card cores are
  still there. The global `fadeOut` has begun by this point (opacity ≈ 0.75), so
  part of the dimming is the ending, not the fluid.
- **1.5 s after a second fast stroke through the flow** — textbook
  Kelvin-Helmholtz mushrooms and shear curls, and the colours have **mixed**:
  magenta runs into the cyan region, cyan under the orange, the yellow carried to
  the right-hand screen edge. The second stroke's pointer lands on a card that is
  already dye and only stirs — no second stamp.
- **A stroke starting on the left card and dragged across its neighbour** — the
  magenta dye is pulled *over* the still-live "Swirl" card, which stays a crisp
  widget underneath. Only the card the pointer went down on is stamped. This is
  the frame a per-card domain cannot produce at all.
- **A stroke through empty background** — stirs whatever dye is in the field and
  stamps nothing; no card appears, the live cards stay live.
- **4.3 s (after `lifetime`)** — the effect has ended, the buffers are freed and
  the cards are back, byte-identical to the untouched frame.

No rectangle is visible in any frame. The only straight edges in the dye are the
cards' own borders while they are still recognisable, and the screen edge, where
`edgeFade` softens the pile-up.

**Honest gaps.** Everything here is a still frame; motion smoothness was not
captured, only the per-frame raster and build times in §9. No iOS device run —
all numbers and frames are macOS/Metal. The `--profile` table was taken with an
occluded window driven by `scheduleForcedFrame`, which is how the harness gets
frames at all; the absolute numbers therefore include the demo's own
recompositing, which is why the idle row is quoted as the baseline to subtract.
The frames also show a faint crunchy fringe on fast-moving dye edges — the dye
grid is six times finer than the velocity grid, so sub-grid detail is stretched
into filaments rather than resolved. It reads as smoke texture at these speeds,
but it is an artefact, not physics.

### Sim-grid safety

The spike recorded one run in which the middle of three cards dissolved far more
violently than its neighbours from identical input, and never reproduced it.
**Tried again three times and it did not recur.** With `_debugIdenticalCards`
the three cards get the same content over a flat backdrop, and the same scripted
stroke runs on all three:

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| mean brightness, card 0 / 1 / 2 | 73.0 / 73.0 / 72.7 | 72.1 / 72.1 / 72.3 | 73.0 / 72.9 / 73.4 |

No card runs away — the three agree to better than 0.5 % of mean brightness in
every run. Note that with one shared domain the cards are no longer in identical
conditions and are *not* expected to be identical: each sits at a different
distance from the scene walls and has different neighbours, which is why cards 1
and 2 agree most closely (mean pixel difference 9) and cards 0 and 2 least
(mean 19–21). That is the pressure solve doing its job, not divergence.

Run to run, the untouched frames are byte-identical (max channel difference 0),
while the frames one second into the flow differ by a mean of 2.4–2.9 / 255. The
sim is not bit-reproducible across runs and cannot be: the step is driven by real
frame times and the synthetic pointer by a wall-clock timer, so the splat
sequence differs slightly every run. The structure does not.

## 10. Public API

```dart
FluidScene(                       // one domain; owns solver, buffers, ticker
  config: FluidConfig.smoke,      // or .ink, .honey, or const FluidConfig()
  controller: sceneController,    // optional: clock, freeze, telemetry
  child: ...,                     // everything that can flow, plus the background
)

Fluid(                            // a source of dye inside that scene
  controller: cardController,     // optional: stamp(), play(direction/origin)
  onDismissed: () => ...,         // the scene's dye is gone, the child is live again
  enabled: true,                  // false: only the controller can stamp it
  child: card,
)
```

`FluidSceneController` carries the clock (`settled`, `opacity`, `freeze`,
`resume`, `reset`), the pointer funnel (`down`/`moveTo`/`up`), scripted strokes
(`stroke`), and telemetry (`passes`, `liveImages`). `FluidController` is the
per-child handle: `stamp()`, `play()`, and a `status` of idle / flowing /
dismissed.

Unlike `Disintegrate`, the config lives on the scene rather than the child: there
is one solver, so there is one set of knobs. Grid-size knobs (`simResolution`,
`dyeResolution`, `floatFields`) are read when the field is allocated; changing
one restarts the scene rather than corrupting the buffers.

## 11. Traps hit while building this

- **A sampler cannot be a function parameter in SkSL.** `vec4 bilerp(sampler2D
  s, ...)` compiles for Impeller and fails the SkSL target, which makes the whole
  `.frag` refuse to load on Skia. Read the sampler directly from the global.
- **Uniform indices are the declaration order**, and each of the eight programs
  has its own block; `_U` in `solver.dart` mirrors all eight.
- `FragmentProgram.fromAsset` paths are
  `packages/amazing_flutter/shaders/<name>.frag`.
- **The scene stirs through a `Listener`, not the gesture arena.** That is what
  lets a stroke start on a card, leave it, and keep stirring, and it means the
  scene never competes for a gesture. The cost is that a drag which *is* a
  gesture — a scroll inside the scene — also stirs. A scene wrapped around a
  scrollable needs `enabled: false` and an app-driven controller.
