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

## Build order

Each step exists to unblock the next, not because it is the prettiest.

**1. Foundation — three shader primitives.**

| Primitive | Mechanism | Used by |
|---|---|---|
| self-contained | plain `FragmentShader` | holographic, aurora, metaballs |
| over a child snapshot | `toImageSync` / sampler | fold, page curl, genie, disintegration |
| over the backdrop | `ImageFilter.shader` + `BackdropGroup` | glass, progressive blur, water |

The third is Impeller-only and needs a fallback path — guard with
`ui.ImageFilter.isShaderFilterSupported`. On GLES the Y axis is flipped and the
shader must invert it.

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

## Environment

- Local toolchain at time of writing: **Flutter 3.38.9 stable**, Dart 3.11.5, macOS arm64.
- `ImageFilter.shader` and `isShaderFilterSupported` are present in this SDK
  (verified in `sky_engine/lib/ui/painting.dart`) — no upgrade needed to start.
- [#170820](https://github.com/flutter/flutter/issues/170820) (blur + shader in one
  `BackdropFilter`): the runtime shader runs at the blur's downsampled resolution,
  so `FlutterFragCoord`/`uSize` shrink, shapes in full-res px land off-texture and
  the output is blocky. **Reproduced on 3.38.9.** The fix (#177687) merged to
  master 2025-10-30, after the 3.38 branch cut — needs a newer stable, or frost
  must be done inside the shader.
- `README.md` was written against 3.47 release notes, so anything it describes as
  new may need a version check before use.
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
