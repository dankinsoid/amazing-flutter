# Materials — design

Design of `shaders/material.frag`, its Dart binding in `lib/src/material/`, and
the mesh path in `lib/src/cloth/`. Settled decisions it builds on are in
`CONTEXT.md` (3: one fat shader, 5: all maths in `.frag`) and it reuses the
snapshot primitive documented in `docs/disintegration.md` §2.

## 1. Scope

A widget's surface answers a finger the way a material would: rubber stretches
and springs back, a membrane rings, paper folds and crumples, cloth drapes and
tears. Page curl is a fold with a particular mapping, not a separate feature.

Five techniques, one shader and one mesh:

| Technique | Class | Where it lives |
|---|---|---|
| rubber-band pull, jelly | A | `material.frag`, `uMode = 0` |
| membrane / drum | A | `material.frag`, `uMode = 1` |
| fold, page curl, tear-off | A | `material.frag`, `uMode = 2` |
| crumple, progress-driven | A | `material.frag`, `uMode = 3` |
| cloth | C | `lib/src/cloth/`, no shader |

## 2. The classification, and where the line actually falls

The class decides the implementation, so it is decided first, per technique:

- **A. Analytic.** The deformation is `f(p, params)`. One fragment pass over a
  widget snapshot. Dynamics — spring-back, wobble, ring-down — are 3–5 scalars a
  CPU spring animates. That is state, but it is per *effect*, not per texel.
- **B. Per-texel state.** Ping-pong render targets. `lib/src/fluid/passes.dart`
  already provides this, so it is a cost decision, not a missing primitive.
- **C. Per-vertex state.** CPU simulation plus `drawVertices`.

Two of these placements are not obvious and are the reason this section exists.

**A membrane is class A, not B.** The tempting implementation is a wave equation
on a ping-pong pair — which is correct, costs two targets and a pass per frame,
and has to handle edge reflections explicitly. Modal synthesis gives the same
bounded vibrating surface in closed form: the modes of a rectangle already satisfy
the clamped boundary, so **reflections are true by construction** and there is
nothing to integrate. State collapses to elapsed time plus the last few strikes.

**Crumple splits.** Progress-driven crumpling — a gesture or an animation running
0→1, reversible — is a function of progress and is class A. Crumpling that
*accumulates*, where each pass of the finger adds folds that stay, has a fold map
that is genuine state: class B, and deferred (§10).

Prefer A. B and C are for effects that provably cannot be written as a function of
coordinate, and only cloth clears that bar today.

## 3. The pass, and why it is not the glass pass

This is the **over a child snapshot** primitive: a plain `FragmentShader` painted
by a `CustomPainter` through `SnapshotHost`, sampler 0 holding a `toImageSync`
copy of the child. Not a backdrop filter, so it runs on Skia too — no `fwidth`,
and `FlutterFragCoord()` for the pixel position.

A rubber surface contributes height, takes a normal and lights it, exactly as
glass and water do, which invites folding it into `liquid_glass.frag` as another
`KIND_`. It is not folded in, for three reasons:

1. **Different primitive.** Glass is a backdrop pass over the scene; a material
   deforms *its own* content. A rubber card has no backdrop to refract.
2. **Different field.** Glass composes up to eight SDFs with `smin`, and a
   composed field has no analytic gradient — which is why it takes its normal by
   central difference. Every material branch here has a closed-form gradient
   (§5), and giving it up would cost five field evaluations per pixel instead of
   one. For the membrane that is the difference between cheap and unaffordable.
3. **Cost.** `liquid_glass.frag` is already 290 floats of uniforms.

The consequence is honest duplication: the Blinn-Phong block is copied, not
shared. `#include` would break the rule that every `.frag` stays detachable as a
single file. Keep the copy textually identical to the glass one, so that a
surface that must be *both* rubber and glass can later be lifted into the glass
pass as a shape kind without the light changing.

## 4. Coordinates and conventions

Same as disintegration, and for the same reasons:

- `FlutterFragCoord()` is in the painter's **local logical px**; every px uniform
  is passed in logical px, origin at the painter's top-left.
- The painter's canvas is the child grown by `spread` on every side. A pull
  throws content past the child's bounds, so `spread` is not optional here;
  `SpreadHitTest` keeps the margin touchable.
- `uChildRect` is where the snapshot sits inside that canvas. Source UVs outside
  `[0, 1]` return transparent, fading over the last `uEdgeFade` px.
- The snapshot is captured at `devicePixelRatio`, which never reaches the shader.

## 5. The common structure

Every branch answers the same question and the tail is shared:

```glsl
// Per branch: how the surface is deformed at p, and what shape it has there.
struct Surface {
	vec2 displacement;  // px, in-plane; the warp applied to the source lookup
	float height;       // px, out-of-plane
	vec2 gradient;      // d(height)/d(p), px per px
};
```

```
Surface s = surfaceAt(p);          // the branch
vec2 q = p - s.displacement;       // inverse map, §6
vec4 src = sampleChild(q);
vec3 n = normalize(vec3(-s.gradient, 1.0));
fragColor = light(src, n) * edgeFade(p);
```

Two branches drive it from opposite ends. **Pull is in-plane**: the displacement
is primary and the height is derived from it (`height = |displacement| *
uPullHeight`), purely so the stretched region catches a specular. **Membrane,
fold and crumple are out-of-plane**: the height is primary and the in-plane
displacement is derived from the gradient, `displacement = -gradient *
uThickness` — the same relation the glass pass uses to displace content under the
water envelope.

**Every branch returns its own gradient analytically. There is no central
difference in this shader.** Three separate reasons, any one of which is
sufficient:

- For the pull falloffs the derivative is one line, so a central difference would
  cost four extra field evaluations to reproduce a value already in hand.
- For the membrane the gradient falls out of the same modal loop as the height
  (`d/dx sin(nπx) = nπ cos(nπx)`), so it is nearly free — while a central
  difference would mean five 64-term sums per pixel.
- For crumple it would be **wrong**. The normal must be constant inside a Voronoi
  cell and *discontinuous* across the edge — that discontinuity is what reads as
  paper rather than cloth. A central difference smooths the slope exactly across
  the fold lines, which are the only interesting places in the field.

## 6. Rubber-band pull

Inverse warp: for output pixel `p`, read the source at `p - D(p)`. As in
disintegration §5 the shader maps backwards, but here the field is smooth and
single-valued, so there is none of that shader's two-step trouble.

```
D(p) = pull * falloff(|p - grab| / R)
```

| `uFalloff` | Falloff | Derivative | Reads as |
|---|---|---|---|
| 0 | `(1 - d)²`, clamped | `-2(1 - d)/R` | rubber — finite support, steep at the grab point |
| 1 | `exp(-d²)` | `-2d·exp(-d²)/R` | soft membrane, jelly |

Finite support is the reason rubber gets the polynomial: the deformation ends at
`R` exactly, so the surface outside is provably untouched and the effect does not
quietly smear the whole card.

**Resistance.** The pull saturates, so dragging further gives less, on the iOS
formula `x' = (1 − 1/(0.55·x/d + 1))·d`. Applied in Dart on the spring's
extension, not in the shader — it is per effect, not per pixel.

**Release.** The jelly wobble is a decaying sinusoid on the amplitude,
`pull₀·e^(−λt)·cos(ωt)`, again in Dart. `ElasticBody` already runs a spring to the
finger and coasts under friction on release; the wobble is a second mode on top of
its existing `deform`, and `ShapeDeform` is already exactly the parameter set this
branch needs (`grab`, `pull`, `pullRadius`, `stretch`). The Dart side of this
branch is a new consumer of existing physics, not new physics.

**Stretch** is the area-preserving domain compression `elasticWarp` already does
in the glass shader: compress along the motion axis by `1 + |stretch|`, expand
across by the same factor. Copied, for the reason in §3.

Precedent worth knowing: Android 12's overscroll stretch (AOSP HWUI
`StretchEffect`) is a production analytic stretch shader; Flutter's own overscroll
is a scale fake ([flutter#82906](https://github.com/flutter/flutter/issues/82906)).
No 2D grab-and-pull exists as a Flutter package.

## 7. Membrane

```
h(x, y, t) = Σ_nm A_nm · sin(nπx) · sin(mπy) · cos(ω_nm·t) · e^(−γt)
ω_nm = cπ√(n² + m²)
```

with `x, y` normalised over the child rect. A strike at `(x₀, y₀)` sets
`A_nm ∝ sin(nπx₀)·sin(mπy₀)` — the mode is excited in proportion to how much it
moves where it was hit, which is why a strike at the centre rings the fundamental
and a strike at an edge does not.

Each strike carries its own time origin, so the two sums do not factor: the
amplitude envelope `e^(−γt_s)` and the phase `cos(ω_nm·t_s)` both depend on the
strike. It is a genuine nested sum, `MODES × STRIKES` terms.

**4×4 modes and 4 strikes.** 64 terms, each two sines, a cosine and an
exponential, and the gradient rides along in the same loop for two more cosines.
Going to 6×6 triples that for detail nobody sees on a widget-sized surface.

**Only the strike index needs unrolling.** The trap is that Impeller indexes
*uniform arrays* by constants only; `n` and `m` index nothing, they are arguments
to `sin`. So the mode loop is a plain `for` with constant bounds and only the
strike loop goes through the `STRIKE(i)` macro, the same way `TOUCH(i)` is written
in `liquid_glass.frag`.

**Strike slots** are `vec4(x, y, age, amplitude)`, amplitude 0 = empty, oldest
evicted — the layout and the eviction rule from `GlassRipples`. Unlike ripples,
strikes are discrete events, so there is no trail spacing to respect.

A cheaper variant without reflections, for a surface where the boundary is not
visible: travelling rings `h = Σ A·cos(k·dᵢ − ωt)·e^(−a·dᵢ)·e^(−b·t)` — which is
what the glass pass already does for water. If the membrane ends up used only for
small taps on large surfaces, that is the same effect for a fifth of the cost.

## 8. Fold, page curl, tear

Analytic, and the mapping is geometric rather than a falloff. Page curl is a
conical deformation (iBooks): the pinch angle selects cone, cylinder or inverted
cone; the normal is the derivative of that mapping; the shadow under the curl is a
function of distance to the fold line. A fold along an arbitrary line splits the
domain and rotates one half — still analytic, still one branch.

Origami is a composition of folds. The maths stays analytic and piecewise, but the
piece count grows 2ⁿ and the real difficulty is layering order and shadows, not
deformation. Not in scope.

Tear-off: the tear line is a noise curve or a Voronoi edge, evaluated from a seed.
A static parameter, not state.

`riveo_page_curl` is the proof this works as a single fragment shader over a
snapshot; read it before writing this branch.

## 9. Crumple

Progress-driven only (§2). Fold lines come from **Voronoi cell edges**: the height
is piecewise flat, the normal constant inside a cell and discontinuous across the
edge. Mixing FBM in instead gives a smooth drape — which is cloth, not paper. That
substitution is the classic mistake in this effect, and it is a one-character
change away at all times.

Per cell: a hashed plane through the cell centre, tilt growing with progress. The
displacement is the gradient of that plane, constant within the cell, so the
gradient is exact and free.

## 10. Uniform table

Declaration order *is* the `setFloat` index; `_U` in the binding mirrors it.

| Index | Uniform | Meaning |
|---|---|---|
| 0–1 | `uSize` | painter canvas in px, child plus the spread margin |
| 2–5 | `uChildRect` | x, y, w, h: where the snapshot sits in the canvas |
| 6 | `uMode` | 0 pull, 1 membrane, 2 fold, 3 crumple |
| 7 | `uEdgeFade` | fade band at the canvas border, px |
| 8–10 | `uLight` | direction to the light, +z toward the viewer |
| 11 | `uSpecular` | Blinn-Phong intensity |
| 12 | `uShininess` | Blinn-Phong exponent |
| 13 | `uShade` | how much the normal darkens the sampled content |
| 14 | `uThickness` | in-plane displacement per unit of height slope, px |
| 15–16 | `uGrab` | finger position, canvas px |
| 17–18 | `uPull` | displacement at the grab point, px |
| 19 | `uPullRadius` | falloff radius `R`, px |
| 20 | `uFalloff` | 0 rubber `(1-d)²`, 1 jelly `exp(-d²)` |
| 21–22 | `uStretch` | area-preserving domain compression along the motion axis |
| 23 | `uPullHeight` | height per px of displacement; what makes the pull catch light |
| 24 | `uModes` | modes per axis, ≤ `MAX_MODES`, compared as a float |
| 25 | `uWaveSpeed` | `c` in `ω_nm = cπ√(n²+m²)` |
| 26 | `uDamping` | `γ`, ring-down rate |
| 27–42 | `uStrikes[4]` | x, y in canvas px, age s, amplitude px; amplitude 0 = empty |

43 floats, plus sampler 0 = the snapshot. Fold and crumple append their blocks at
the end when they are written.

**Uniforms cannot be declared ahead of the branch that uses them.** An unused
uniform is stripped by the compiler and every index after it shifts — the trap
noted in `docs/disintegration.md` §4. So this table grows one branch at a time,
and a reserved-but-unreferenced block is not an option.

## 11. Cloth — the mesh path

Class C, and nothing about it is shared with §5. Mass-spring with Verlet
integration and positional constraints, ~3 iterations for drape, 5–8 for stiff. A
30×30 grid is around 150k flops per frame, trivial for Dart at 60 fps; 80×60 is
proven to run. `flutter_tearable_cloth` (MIT) has all of this — points,
constraints, tearing, pointer interaction — and renders it as lines and points
through a `CustomPainter`. **No widget is textured onto the mesh anywhere; that
half is the work.** Take the physics, write the rendering.

Four constraints shape the rendering:

- **`drawVertices` has no lighting.** Compute normals on the CPU from neighbouring
  grid nodes by cross product and bake the shading into per-vertex colours with
  `BlendMode.modulate`. Without it, drapery reads as a flat coloured rag: folds
  show as texture distortion and never as shading.
- **`drawVertices` cannot be combined with a custom fragment shader.**
  Interpolated UVs never reach a runtime shader
  ([flutter#173835](https://github.com/flutter/flutter/issues/173835)); only
  `ImageShader` sees them. Mesh or shader, never a hybrid. This is what puts cloth
  outside `material.frag` for good, not merely for now.
- **`textureCoordinates` are in image px** under an identity-matrix `ImageShader`,
  not 0..1. The snapshot's device pixel ratio has to be accounted for — and this
  is the one place in the project where the DPR reaches the drawing code.
- **Use an indexed mesh**, sharing vertices through `indices`; duplicated
  positions show seams along interior edges.

`drawVertices` on Impeller was broken on iOS
([flutter#127486](https://github.com/flutter/flutter/issues/127486)); closed and
fixed.

## 12. Build order

1. **Rubber-band pull.** `material.frag` with the common tail and `uMode = 0`,
   driven by `ElasticBody`. The smallest thing that proves snapshot → warp →
   gradient → specular end to end, and a free niche.
2. **Membrane.** Same shader, `uMode = 1`. Proves the out-of-plane direction of
   §5 and the analytic gradient claim, and it is the other free niche.
3. **Fold and page curl.** `uMode = 2`. Closes `CONTEXT.md` build step 5, which
   this document subsumes.
4. **Crumple.** `uMode = 3`.
5. **Cloth.** Independent of 1–4; can be built in parallel by someone else.

## 13. Deferred, with the reason

- **Irreversible crumple.** The accumulated fold map is per-texel state, class B.
  `PassRunner` would carry it, but the effect has to earn a ping-pong pair first.
- **Origami.** Analytic but 2ⁿ pieces, and the hard part is layering and shadows.
- **Rubber that is also glass.** Possible by lifting the pull branch into
  `liquid_glass.frag` as a shape kind — which is why the light block stays a
  verbatim copy (§3). Not until something needs it.
- **Cloth against the height field.** Cloth is a mesh and contributes no height,
  so it cannot participate in the shared field of decision 1. Tearing a cloth over
  liquid glass would need the mesh's normals resampled into a texture the glass
  pass reads. Out of scope.

## 14. Open questions

1. **Does the pull need the snapshot frozen?** `SnapshotWidget` reuses its raster
   when only the painter notifies (`CONTEXT.md`, step 2), so a live child could be
   pulled without a gesture-time capture — at the cost of the raster not tracking
   the child's own repaints. Decide when the first demo has live content in it.
2. **`uThickness` sign.** Content under a raised membrane can be displaced toward
   or away from the crest; refraction says one thing and a pressed-from-behind
   surface says the other. Pick by eye.
3. **Strike eviction policy.** Oldest-out is the obvious rule; smallest-remaining-
   envelope is the alternative, same open question as `docs/liquid_glass.md` §11.5.
4. **Where the light vector comes from.** Holo derives one from device tilt
   already. A material on the same screen should agree with it rather than
   carrying its own constant.
