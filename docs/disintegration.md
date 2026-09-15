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
| erode | 3 | the touch trail: drag along the stroke, vortex pairs, curl noise | the accumulated erosion, then FBM for the leftovers |

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
fold, genie and page curl.

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
| 27 | `uErodeRadius` | hole radius under a fresh stroke point |
| 28 | `uErodeGrowth` | radius the hole gains per second |
| 29 | `uErodeDrag` | pull along the stroke where it bites hardest |
| 30 | `uErodeSwirl` | curl-noise eddies inside the eaten band |
| 31 | `uErodeVortex` | counter-rotating pair dragged behind each point |
| 32–159 | `uTrail[32]` | x, y in canvas px, age s, strength; strength 0 = empty slot |
| 160–287 | `uTrailDir[32]` | unit stroke direction in xy; zw unused |

288 floats, plus sampler 0 = the snapshot. Every knob is a field of
`DisintegrationConfig`; nothing is hardcoded in Dart.

The trail is two parallel arrays rather than one packed array: position, age and
strength fill a `vec4` exactly, and the direction needs two more floats. Speed is
not carried — the drag follows the erosion weight and the age, so nothing reads it.
Only erode uploads the trail block; the other modes never enter the loop.

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

## 6. The erode trail

`ErodeTrail` emits one point per `trailSpacing` of travel and interpolates the
timestamps across the segment, so a fast stroke lands as a spread of ages rather
than one. It is a sibling of `GlassRipples`, not a reuse: that emitter's spacing,
lifetime and amplitude all come from `GlassWave`, and pulling them apart would
change the ripples API for no gain.

The newest 32 points win. The oldest `fadeCount` taper their strength to 0 before
eviction, because erosion only ever grows: dropping a point outright would *heal*
the widget where the finger had already eaten through.

Each point contributes a soft disc `exp(-r²/R(age)²)`, `R = uErodeRadius +
uErodeGrowth · age`, and three velocity terms weighted by that same disc: the drag
along `uTrailDir`, a counter-rotating vortex pair whose sense flips across the
stroke (`clamp(dot(v, perp(dir)) / R, -1, 1)`, so it is smooth on the axis), and —
outside the loop — curl noise. The curl is the rotated gradient of a value-noise
potential, `(∂n/∂y, −∂n/∂x)` by forward differences, so it is divergence-free and
the smear rolls into eddies instead of drifting. Two scales: `uNoiseScale`, and a
quarter of it whose weight grows with the local age, so old smoke turns in big
lobes. The potential is sampled at a point advected by `uErodeDrag · age`, so the
eddies keep moving while the trail ages rather than sitting frozen on screen.

The local age is the erosion-weighted mean of the point ages — the loop already
sums the weights, so it costs one more accumulator and gives every pixel a "how
long ago did the finger pass here".

## 7. Cost per pixel

| Mode | Texture reads | Noise |
|---|---|---|
| shards | 1 | 4 `valueNoise` (16 `hash12`): 2 for the scatter, 2 for the lattice warp; plus 1 `hash32` |
| smoke | 3 | 5 `valueNoise` (20 `hash12`): 2 for the scatter, 3-octave FBM for the mask |
| blow-away | 1 | as shards |
| erode | 3 | 9 `valueNoise` (36 `hash12`): 6 for the two curl scales, 3-octave FBM for the mask; plus 32 trail points, each an `exp` behind a three-sigma reject |

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
finger destroys directly, not through a progress bar — and a ticker keeps the
controller notifying while the trail ages, since a still finger emits no points but
its hole must keep widening. Release dismisses whenever the stroke travelled more
than a quarter of `dismissDistance`: any real stroke destroys the widget. A shorter
scratch springs back and clears the trail, so the widget heals rather than keeping
holes it never earned.

## 9. Not in this shader

- **Per-shard depth or lighting.** Shards are flat snapshot fragments; there is no
  normal to light them with.
- **Reassembly.** Springing back re-shows the live child rather than reversing the
  field, so a card that restores is interactive again immediately.
- **Text-aware cells.** Cells are a warped lattice; they do not follow glyph edges.
- **A second buffer.** Erode advects noise in one pass; there is no ping-pong
  texture, so the smoke cannot remember what it did last frame. Everything it shows
  is a function of the trail and the clock.
