# Disintegration — design

Design and data flow of `shaders/disintegration.frag`, its Dart binding in
`lib/src/disintegration/`, and the snapshot primitive in `lib/src/snapshot/`.
Settled decisions it builds on are in `CONTEXT.md` (3: one fat shader,
4: transitions freeze snapshots, 5: all maths in `.frag`).

## 1. Scope

A widget dissolves on a swipe, in four modes from one `.frag`:

| Mode | `uMode` | Field | Threshold |
|---|---|---|---|
| shards | 0 | swipe direction plus a noise scatter | per-cell hash, swept along the swipe |
| smoke | 1 | the same field, wider and blurrier | FBM, soft edge |
| blow-away | 2 | radial out of the finger, blended with the swipe | distance from the finger |
| erode | 3 | the touch trail: outward drift, vortex pairs, curl noise | local disturbance × local age, no threshold |

This is the **over a child snapshot** primitive of the build order: a plain
`FragmentShader` painted by a `CustomPainter`, sampler 0 holding a `toImageSync`
copy of the child. It is not a backdrop filter, so it also runs on Skia — hence
no `fwidth`, and `FlutterFragCoord()` for the pixel position.

## 2. The snapshot primitive

`SnapshotHost` wraps the child in a `RepaintBoundary` and hands a `ChildSnapshot`
the means to freeze it. Three constraints shape it:

- **Capture before hiding.** `toImageSync` throws on a boundary that has never
  painted, so the gesture captures on pan *start*, while the child is still
  painted, and the host hides the child only once the image exists.
- **The effect draws outside the child.** Particles fly away, so the painter gets
  a canvas grown by `spread` on every side (`Stack` + `Positioned` with negative
  insets and `Clip.none`). `ChildSnapshotPainter.childRect` is where the child
  sits inside that canvas; the shader returns transparent for source UVs outside
  `[0, 1]`, and fades over the last `uEdgeFade` px so the canvas edge is not a cut.
- **The snapshot lags one frame.** The captured image is the child's last painted
  frame. A child animating at the moment of capture is caught one frame behind;
  acceptable, and noted on `ChildSnapshot.capture`.

The primitive knows nothing about disintegration and is the intended base for
fold, genie and page curl. `SpreadHitTest` ships with it: a box is hit only inside
its own size, so an effect that paints into the margin needs its own hit test to
stay touchable there.

## 3. Coordinates

`FlutterFragCoord()` is the vertex position of the drawn rect in the **canvas'
local logical px** (engine: `runtime_effect.vert` writes `_fragCoord = position`,
and the entity transform lives in the MVP). So every px uniform is passed in
logical px, unscaled by the device pixel ratio, and the origin is the painter's
own top-left. The snapshot is captured at `devicePixelRatio`, which never reaches
the shader: it is sampled by normalised UV.

## 4. Uniform table

Declaration order *is* the `setFloat` index; `_U` in `disintegrate.dart` mirrors it.

| Index | Uniform | Meaning |
|---|---|---|
| 0–1 | `uSize` | painter canvas in px, child plus the spread margin |
| 2–5 | `uChildRect` | x, y, w, h: where the snapshot sits in the canvas |
| 6 | `uProgress` | 0 intact, 1 gone |
| 7 | `uMode` | 0 shards, 1 smoke, 2 blow-away |
| 8–9 | `uDirection` | unit swipe direction |
| 10–11 | `uOrigin` | finger position, canvas px |
| 12 | `uSeed` | shifts every hash |
| 13 | `uCellSize` | shard cell edge before the lattice is warped |
| 14 | `uDrift` | smooth displacement at full departure |
| 15 | `uLift` | upward bias added to the drift |
| 16 | `uJitter` | per-shard displacement on top of the drift; sub-cell, see §5 |
| 17 | `uSpin` | per-shard rotation at full departure, rad |
| 18 | `uShrink` | shard size lost at full departure |
| 19 | `uNoiseScale` | 1 / noise feature size |
| 20 | `uTurbulence` | noise-driven displacement; what scatters the pieces |
| 21 | `uRadial` | blow-away: radial vs swipe direction in the flow |
| 22 | `uSoftness` | dissolve edge width, in progress units |
| 23 | `uSweep` | 0 dissolves everywhere at once, 1 strictly front to back |
| 24 | `uBlur` | smoke smear radius; 0 keeps a single read |
| 25 | `uFade` | alpha exponent while departing |
| 26 | `uEdgeFade` | fade band at the canvas border |
| 27 | `uErodeRadius` | disturbance radius under a fresh stroke point |
| 28 | `uErodeSpread` | radius the front gains per second |
| 29 | `uErodeExpand` | outward drift away from each point |
| 30 | `uErodeSwirl` | curl-noise eddies |
| 31 | `uErodeVortex` | swirl around the finger |
| 32 | `uErodePush` | px of shove per px/s of stroke speed |
| 33 | `uErodeLifetime` | disturbance-seconds over which the smoke thins to nothing |
| 34–161 | `uTrail[32]` | x, y in canvas px, age s, strength; strength 0 = empty slot |
| 162–289 | `uTrailDir[32]` | unit stroke direction in xy, stroke speed px/s in z; w unused |

290 floats, plus sampler 0 = the snapshot. Every knob is a field of
`DisintegrationConfig`; nothing is hardcoded in Dart.

The trail is two parallel arrays rather than one packed array: position, age and
strength fill a `vec4` exactly, and the direction needs two more floats — the spare
`z` carries the stroke speed that drives the push. Only erode uploads the trail
block; the other modes never enter the loop.

`uSize` is used by `edgeFade` rather than left dangling: an unused uniform can be
stripped by the compiler, which would shift every index after it.

## 5. Inverse mapping — the one real decision

A fragment shader maps backwards: for output pixel `p` it must find the source
pixel `q`. A per-shard offset cannot be looked up at `p`, because which shard
covers `p` depends on `q`, which is what we are solving for.

Two steps:

1. A **smooth** field `d(p)` — direction × progress² × the sweep falloff, a noise
   scatter, and radial flow from `uOrigin` for blow-away. `q0 = p − d(p)`.
2. Hash the **cell of `q0`** for the per-shard jitter, rotation, shrink and
   dissolve threshold, then `q = q0 − jitter`, rotated and scaled about the cell
   centre.

Two consequences are worth knowing before touching the field.

**Only the smooth field moves a shard.** Step 2 displaces what a pixel *samples*,
not where the shard *appears*: the set of pixels that resolve to a given cell is
fixed by `d(p)` alone, so a large per-cell offset makes a stationary shard show
its neighbour's pixels rather than flying. The scatter that makes the pieces
separate therefore lives in `d(p)` as `uTurbulence` — smooth in `p`, so footprints
travel with it — and `uJitter` stays under a cell, where it only roughens the
edges. Real per-particle flight needs per-particle geometry, which this pass
deliberately does not have.

**The mask is read at the source.** `leadOrder` is evaluated at `q0`, not at `p`.
Read at `p`, a shard that flew ahead of the front lands in already-dissolved
territory and is erased on arrival, so the debris field never appears.

Ordering is one lattice trick: the dissolve order is
`mix(cellHash, leadOrder, uSweep)`, where `leadOrder` is 0 at the edge that goes
first — projection along `uDirection` for shards and smoke, distance from the
finger for blow-away. `uSweep` alone turns "dissolves at random" into "dissolves
front to back". `departure` squeezes that order into `[0, 1 − uSoftness]` so
progress maps to the dissolved fraction about linearly and every cell still
clears exactly at 1.

Erode is the exception that proves the rule: its mask reads the erosion at `p`, the
output pixel, not at the source. The hole is where the finger passed *on screen*,
not a property of the material being sampled, so a single evaluation is correct —
and the content pulled in from outside the hole is exactly the smear.

Sampling the smoke mask needed one more correction: summed value-noise octaves
cluster around 0.5, which gives a mask with no contrast and a card that fades
rather than dissolves. `fbm` stretches the result by 2.2 about its mean.

## 6. Erode: one cloud, disturbed

The card is treated as a cloud that was holding the shape of a widget. The touch
breaks it: nothing else does. There is no hole, no threshold, no sweep and no
direction — `uProgress` and `uDirection` are not part of the field at all.

`ErodeTrail` emits one point per `trailSpacing` of travel and interpolates the
timestamps across the segment, so a fast stroke lands as a spread of ages rather
than one. It is a sibling of `GlassRipples`, not a reuse: that emitter's spacing,
lifetime and amplitude all come from `GlassWave`, and pulling them apart would
change the ripples API for no gain. The newest 32 points win; the oldest
`fadeCount` taper before eviction.

Each point carries a soft disc `exp(-r²/R(age)²)`. The **front** is the largest of
those discs, not their sum — stroke length must not deepen the disturbance — and
`R = uErodeRadius + uErodeSpread · age` grows **linearly**. A `sqrt(age)` front is
the physical answer and was tried first; over the 0.3–2 s window that matters it
only grows by 1.8×, while a card whose far corners are ~120 px from the stroke
needs about 3× between "corners still crisp" and "eddies everywhere". Linear gives
that range; the slowing-down that sqrt was for is supplied by the thinning instead.

Two accumulators come out of the same loop beside the front: the **stir time**,
`max(weight · age)` over the points, and the **fresh weight**, the influence of
points the finger only just laid down. Stir time only ever rises — a young point
contributes `w · 0` — which is what keeps a second touch from making faded smoke
solid again. Every response is built from those:

- **displacement** = curl noise at two scales (the coarse one weighted by stir time,
  the potential advected so the eddies keep turning) plus a radial drift away from
  each point — curl is divergence-free and would never spread the cloud on its own —
  plus the vortex pair around the finger and a **push** along the stroke,
  `direction × speed × uErodePush`, so a fast swipe sweeps the smoke and a slow one
  only swirls it. Push and vortex are normalised by the *fresh* weight, not the
  total: a long-dead trail must not drown the stroke happening right now, and the
  push is not gated by stir time, or the first moment of a stir would do nothing;
- **blur** = stir time, through the same three-tap `sampleSmeared`;
- **alpha** = `1 − smoothstep(0, 1, stir / uErodeLifetime)`, modulated by a
  low-contrast FBM so the cloud frays rather than fading flat. The smoke thins as it
  spreads; nothing is ever cut out, and a new touch only ever moves it.

A pixel starts moving the instant the front reaches it — the response is
`front · (0.15 + age / lifetime)`, not `front · age`, or the first moments of a
touch would do nothing at all.

`uProgress` survives in this mode only as a global thinning multiplier that
guarantees termination: on release the controller springs it to 1 with a spring
soft enough to take about `erodeLifetime` (`DisintegrationController.springFor`),
so the leftovers are gone even where the trail never reached.

**Stirring.** A pan that lands while the smoke is still dissipating appends to the
existing trail instead of restarting: `beginDrag` keeps the progress it has, the
ramp stops while the finger is down, and the release springs on from there. Since
the trail never empties in that state, such a stroke always ends in a dismissal —
the widget is already dying, stirring only decides how it looks on the way out.

The pointer has to reach the widget at all, which takes two things: the gesture
detector is `HitTestBehavior.opaque`, because the child is hidden while the effect
plays and would otherwise let every pointer through, and `SpreadHitTest` widens the
hit area by a quarter of the spread so smoke that drifted off the child is still
grabbable. Two caveats live with that: a parent laid out tightly around the child
(a `Wrap`, a list tile) clips the margin away, since an ancestor that fails its own
bounds check never calls down; and in a dense row a dissolving card's margin can
claim a pointer meant for its neighbour, which is why the margin is a quarter of
the spread rather than all of it.

## 7. Cost per pixel

| Mode | Texture reads | Noise |
|---|---|---|
| shards | 1 | 4 `valueNoise` (16 `hash12`): 2 for the scatter, 2 for the lattice warp; plus 1 `hash32` |
| smoke | 3 | 5 `valueNoise` (20 `hash12`): 2 for the scatter, 3-octave FBM for the mask |
| blow-away | 1 | as shards |
| erode | 3 | 9 `valueNoise` (36 `hash12`): 6 for the two curl scales, 3-octave FBM for the alpha grain; plus 32 trail points, each two `exp` behind a three-sigma reject |

No loops, no derivatives, no dependent texture chains: the extra reads in smoke are
fixed offsets from the first. The painter covers the card plus its spread margin,
not the screen, so even the smoke path stays far below the 8 ms raster budget.

Texture reads sit outside every branch: `sampleChild` masks out-of-bounds UVs
arithmetically rather than branching, so `texture()`'s implicit LOD is never taken
in divergent control flow.

## 8. Gesture and settling

`DisintegrationController` owns progress, direction, origin and mode.
Pan start captures the snapshot and the origin; pan update sets direction from the
accumulated delta and `progress = distance / dismissDistance`; pan release hands
the signed velocity along the swipe to a `SpringSimulation` toward 1 (fling or
past 0.6) or back to 0 — never a fixed duration, per `CONTEXT.md` step 5.
`play(direction:)` runs the same settle without a finger, and `freeze(progress)`
parks it anywhere for screenshots.

Erode reverses that. The pan feeds the trail and leaves `progress` at 0 — the
finger disturbs the cloud directly, not through a progress bar — and a ticker keeps
the controller notifying while the trail ages, since a still finger emits no points
but its disturbance must keep spreading. Release dismisses whenever the stroke
travelled more than a quarter of `dismissDistance`: any real stroke breaks the
widget. A shorter scratch springs back and clears the trail, so the widget heals
rather than keeping a disturbance it never earned.

## 9. Not in this shader

- **Per-shard depth or lighting.** Shards are flat snapshot fragments; there is no
  normal to light them with.
- **Reassembly.** Springing back re-shows the live child rather than reversing the
  field, so a card that restores is interactive again immediately.
- **Text-aware cells.** Cells are a warped lattice; they do not follow glyph edges.
  At `cellSize` 1 the lattice *is* the pixel grid — the warp fades out below 6 px,
  where it would only make cells non-square — and shards become pixel dust.
- **A second buffer.** Erode advects noise in one pass; there is no ping-pong
  texture, so the smoke cannot remember what it did last frame. Everything it shows
  is a function of the trail and the clock.
