# Project context

Start here. `README.md` is the research — *what we found out*. This file is
*what we decided and what to do next*.

## What this repo is

A demo proving Flutter can deliver GPU animation at the level people associate
with native iOS, WebGL showcases, and game UI — not the level people associate
with Flutter. The point is not a gallery of effects; it is that the framework is
flexible enough to build a coherent physical-feeling surface out of raw shaders.

The survey found a near-empty niche: the community's main shader showcase
([fluttershaders.com](https://fluttershaders.com/)) has 9 shaders, 7 of them
post-process filters over an image. Glass, materials, and composed height fields
are not covered anywhere. 2D rubber-band and modal-membrane shaders do not exist
as packages.

## Decisions already made

These were argued through and settled. Reopen them only with a concrete reason —
each one has a rationale in `README.md`.

1. **One height field, in screen coordinates, shared across the scene.**
   Not per-panel. This is what makes "ripples inside a glass pill" and "a ripple
   crossing the background and entering the glass" the same code with different
   parameters. Getting this wrong means a rewrite later, not a refactor.

2. **Compose before taking the normal.** Glass profile and water rings sum into
   one height value, *then* the normal is derived. Layering two finished effects
   gives "glass with water under it"; summing heights gives liquid glass, and the
   specular rim rides the wave for free.

3. **One fat shader with branches, not a stack of thin ones.** Flutter cannot
   merge two `FragmentProgram`s into a single pass, so every stacked layer costs
   a full extra pass and backdrop capture. Only passes that genuinely change
   resolution (the mip pyramid) stay separate.

4. **Transitions freeze snapshots.** `AnimatedSampler` rebuilds its texture every
   frame, so a "live" widget mid-transition guarantees a jump rather than
   preventing one. Capture A and B, then animate between them.

5. **All maths lives in `.frag`; the Dart binding only passes parameters.**
   Keeps each shader detachable as a single file — for reuse, for testing, and
   for a possible contribution back to fluttershaders.com.

6. **Repo split.** Shaders and materials live here (Dart, so they stay portable).
   Staggered spring scroll stays in `flutter-cljd`, because it wedges between the
   layout's target position and the painted position — it belongs inside that
   collection engine and cannot be extracted.

7. **Benchmark every shader against the native blur.** At the end, each effect
   gets a raster-thread measurement in `--profile` next to a plain
   `BackdropFilter.blur` of the same area on the same device — the one GPU effect
   everybody already ships everywhere, so "X× a blur" is a cost readers can feel.
   Numbers without that baseline are not comparable across devices.

## Build order

Each step exists to unblock the next, not because it is the prettiest.

**1. Foundation — three shader primitives.**

| Primitive | Mechanism | Used by |
|---|---|---|
| self-contained | plain `FragmentShader` | holographic, aurora, metaballs |
| over a child snapshot | `toImageSync` / sampler | fold, page curl, genie, disintegration |
| over the backdrop | `ImageFilter.shader` + `BackdropGroup` | glass, progressive blur, water |
| multi-pass ping-pong | `toImageSync` chain, `lib/src/fluid/passes.dart` | fluid, any iterative solve |

The backdrop primitive is Impeller-only and needs a fallback path — guard with
`ui.ImageFilter.isShaderFilterSupported`. On GLES the Y axis is flipped and the
shader must invert it.

The multi-pass primitive is `PassRunner` + `Field`, and it knows nothing about
fluids: set uniforms, record a full-target `drawRect`, `toImageSync`, feed the
image to the next pass. It has no ping-pong *pair* — every pass allocates its own
target and the old one is retired a frame late, because `toImageSync` rasterises
lazily. Anything iterative (a Poisson solve, a mip pyramid, a blur chain) belongs
on it. Details and its cost model: `docs/fluid.md` §8.

**2. Holographic card.** Self-contained, zero infrastructure, best
wow-to-effort ratio in the whole survey — and the only effect that *requires* a
phone in hand, since you cannot fake accelerometer response with a screenshot.
Use it to shake down the pipeline before touching backdrop machinery.

The hard part is sensor handling, not the shader: filter with One Euro
(adaptive — smooths at rest, stays responsive in motion), take the gravity vector
separately from linear acceleration (otherwise walking shakes the card), and run
the angle through a spring so the card trails the tilt with slight inertia. Glass
specular later reuses the same light vector.

**3. Tab bar — progressive blur + glass pill.** First real use of the backdrop
primitive, and it doubles as the skeleton of water UI. Naive `blur + alpha mask`
does not work: it cross-fades sharp against blurred and leaves ghosting. A real
varying radius is required.

**4. Water UI.** Glass + water + metaballs in the shared height field. `smin` is
needed here anyway — without it two shapes intersect with a visible crease, so
neither merging nor the collapse-into-a-pill morph works. Shader design and
uniform layout: `docs/liquid_glass.md`, skeleton in `shaders/liquid_glass.frag`.

**5. Fold.** The iPhone Duo target. Progress is driven by gesture, settled with a
spring — never a fixed duration.

After that, in rough order: fluted glass (one height function on working glass —
proves the architecture), liquid metal (reflect a matcap instead of refracting),
rubber-band pull, disintegration (one shader, three modes: Thanos / smoke /
blow-away), genie, god rays behind live text input, caustics.

**Dissolving a widget: fluid is the flagship, erode is the cheap fallback.**
Both were built and compared. `DisintegrationMode.erode` is one pass over one
snapshot and destroys a widget convincingly for the price of a filter; the GPU
Stable Fluids scene is 26 passes and actually *flows* — the card is pixel-solid
until it is touched, the dye rolls into Kelvin-Helmholtz curls, and a second
stroke stirs what the first one left. Use erode where the budget is a single
pass or the platform has no float render targets; use fluid where the effect is
the point. They share the snapshot primitive and nothing else.

**Done out of order: fluid, and with it the multi-pass primitive.**
`lib/src/fluid/` is the fourth row of the table above. `FluidScene` owns one
Stable Fluids domain over its whole subtree — **decision 1 again: one field, in
screen coordinates, shared** — and each `Fluid` child stamps its `toImageSync`
snapshot into that shared dye at its own screen rect when a finger lands on it.
A per-card domain was tried first and was wrong for exactly the reason decision 1
predicts: the card-sized walls read as a visible rectangle, smoke could not drift
past a neighbour, and the pass count multiplied by the number of cards. Design,
units, and the measurements: `docs/fluid.md`.

**Done out of order: disintegration, and with it the snapshot primitive.**
`lib/src/snapshot/` is now the second row of the table above: `SnapshotHost` wraps
a child in a `RepaintBoundary`, freezes it with `toImageSync` on gesture start —
before the child is hidden, since the boundary must have painted — and hands a
`ChildSnapshotPainter` a canvas grown by a `spread` margin so an effect can throw
pixels past the child. It knows nothing about disintegration, so fold, genie and
page curl should build on it rather than re-capture. The effect itself is
`shaders/disintegration.frag` plus `lib/src/disintegration/`; design, uniform
table and the inverse-mapping trap that shapes it are in `docs/disintegration.md`.

## Environment

- Local toolchain: **Flutter 3.47.4 stable**, Dart 3.13.3, macOS arm64 (upgraded from 3.38.9 on 2026-09-14 for #170820).
- `ImageFilter.shader` and `isShaderFilterSupported` are present in this SDK
  (verified in `sky_engine/lib/ui/painting.dart`) — no upgrade needed to start.
- [#170820](https://github.com/flutter/flutter/issues/170820) (blur + shader in one
  `BackdropFilter`): on 3.38 the runtime shader ran at the blur's downsampled
  resolution, so shapes in full-res px landed off-texture and the output was
  blocky. Fixed by #177687 (master 2025-10-30); **verified working on 3.47.4**.
- `ImageFilter.shader` requires **every sampler except the first to be bound**
  (engine `ValidateImageFilter`). 3.38 built the error message and never threw it;
  3.47 throws. Bind a 1×1 blank image to unused samplers.
- `macos/Runner/Info.plist` has `FLTEnableImpeller`; `flutter run` still needs
  `--enable-impeller` on 3.47 for the desktop target.
- **Screenshots come from inside the app** (`example/lib/snap.dart`): a root
  `RepaintBoundary` → `toImage` → PNG, with a `scheduleForcedFrame()` pump, because
  an occluded macOS window gets no frames and `screencapture` returns a stale
  composite. The sandbox only allows writes under the app container.
- **macOS runs Skia by default in 3.38.** `flutter run` passes
  `enable-impeller=false` unless given `--enable-impeller`; the example sets
  `FLTEnableImpeller` in `macos/Runner/Info.plist` so the app itself defaults to
  Impeller. On Skia `ImageFilter.shader` is unsupported and `fwidth()` does not
  even compile to SkSL — guard the `FragmentProgram` load, not just the filter.
- Target platforms: iOS and macOS first (Impeller/Metal). Web runs Skia, so the
  backdrop primitive will not work there — plan the fallback, don't plan the demo
  around it.

## Traps worth knowing before you hit them

- **`drawVertices` + custom fragment shader do not mix.** Interpolated UVs never
  reach a runtime shader ([#173835](https://github.com/flutter/flutter/issues/173835));
  only `ImageShader` sees them. Use one or the other, never a hybrid.
- **Uniform arrays are indexed by constants only**, and Impeller's uniform buffer
  is small. Unroll loops for the common small cases; for many shapes, pass data
  through a texture instead.
- **Cost is texture reads, not screen area.** A 1–3 read shader is fine
  full-screen; anything sampling a blur is tens of reads with poor cache locality
  and belongs in a small region. Blur at half resolution costs a quarter.
- **`BackdropFilter` processes the whole screen** regardless of how small the
  panel is. Group multiple glass surfaces with `BackdropGroup`.
- **`drawVertices` has no lighting.** Compute normals on the CPU from neighbouring
  grid nodes and bake shading into vertex colors, or cloth reads as a flat rag.

## Reference implementations worth reading

- [`riveo_page_curl`](https://github.com/Rahiche/riveo_page_curl) — proof that an
  analytic fold works as a single fragment shader over a snapshot.
- [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass) —
  correct SDFs and a cached geometry pass; read it for the maths, note that its
  blur is a separately clipped layer, which is where its edge seams come from.
- [`flutter_tearable_cloth`](https://github.com/hamed-rezaee/flutter_tearable_cloth) —
  usable Verlet physics (MIT); rendering draws lines, so the mesh-texturing part
  is still to be written.
- [gl-transitions](https://github.com/gl-transitions/gl-transitions) — `crosswarp`,
  `WaterDrop`, `Dreamy` port almost verbatim.

## Interactive catalogue

All 41 surveyed effects with live demo links, filters by category and by pixel
access cost:
<https://claude.ai/code/artifact/3ade0560-03c9-4a9b-9466-a7c2c5e1617a>
