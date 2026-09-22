# Holo — design

Design and data flow of `shaders/holo.frag` and its Dart binding in
`lib/src/holo/`. Settled decisions it builds on are in `CONTEXT.md`
(3: one fat shader with branches, 5: all maths in `.frag`).

## 1. Scope

A card with a holographic foil: a rainbow that sweeps as the card tilts, a glare
that follows the pointer, and sparkles that glint in and out with the angle. It
is build-order item 2 — self-contained, zero infrastructure, and the shakedown
run for the snapshot pipeline before the backdrop machinery.

The reference is [poke-holo](https://poke-holo.simey.me/) and its source
[pokemon-cards-css](https://github.com/simeydotme/pokemon-cards-css) (MIT). No
code or asset was copied; what was taken is the recipe, and it is worth naming
because the port is not one-to-one:

| The site | Here |
|---|---|
| 3 stacked DOM layers (`__shine`, `:before`, `:after`, `__glare`) with CSS blend modes | one fragment shader, blends done arithmetically |
| authored foil and mask `.webp` per card | a cosine palette and a hash, no assets |
| `background-position` bound to the pointer | a phase term `dot(uTilt, k)` |
| a grain texture multiplied in | per-cell sparkles that glint with the tilt |
| a foil mask painted per card | the child's own luminance |

The site cannot do the last two: a CSS gradient has no notion of a surface
normal, so its "foil" moves but never *faces the light*, and its grain is a fixed
texture that cannot change which grains are lit.

## 2. The pass

One pass over the card rect. Sampler 0 is the card's own content; the shader
outputs the final premultiplied pixel, including the rounded-corner clip — so the
child needs no `ClipRRect` and the card costs one `saveLayer` less.

**`SnapshotWidget` + `SnapshotPainter` supply the sampler.** Verified in
`flutter/lib/src/widgets/snapshot_widget.dart` on 3.47.4:

- **The raster is reused when only the painter notifies.** `SnapshotPainter`
  is a `ChangeNotifier`; `RenderSnapshotWidget.attach` wires it to
  `markNeedsPaint`, and `paint()` re-enters with `_childRaster != null` and goes
  straight to `paintSnapshot`. Every pointer move therefore costs one fragment
  pass and no re-rasterisation. This is exactly the property the effect needs.
- **The raster is *not* regenerated when the child repaints.** `_childRaster` is
  cleared only by `SnapshotController.clear()`, by `allowSnapshotting` flipping,
  by `detach`/`dispose`, by an empty size, and by `autoresize` seeing a new size.
  A child that repaints marks this render object dirty, `paint()` runs again, and
  the **stale** raster is served. The framework says as much on
  `SnapshotPainter.shouldRepaint`: "Changing the delegate will not cause the
  child image retained by the `SnapshotWidget` to be updated."

So `SnapshotWidget` is the right primitive here and `lib/src/snapshot/`
(`SnapshotHost`) is not needed: that one exists to freeze a child *on a gesture*
and hide it, which is the disintegration problem, not this one. The cost is that
a card with live content inside it shows the frame it had when it was captured.
`HoloCard` clears the snapshot when `widget.child` changes identity and passes
`autoresize: true`; anything finer (a ticking countdown on the card) needs a
`SnapshotController.clear()` on the caller's clock, and that hook is not exposed
yet — see §9.

`SnapshotMode.permissive` is used rather than `normal`: a platform view inside
the card degrades to a plain child instead of throwing.

## 3. Coordinates and conventions

`FlutterFragCoord()` is the painter's own local logical px, so `uSize`,
`uRadius` and the sparkle cell sizes are all logical px, unscaled by the device
pixel ratio. The snapshot is captured at `devicePixelRatio` and sampled by
normalised UV, so the ratio never reaches the shader.

Two conventions, both **verified by measuring the rendered card**:

- **`uTilt`**, −1..1 per axis. `+x` = the **right** edge toward the viewer,
  `+y` = the **bottom** edge toward the viewer (screen y is down). Measured at
  `tilt = (0.6, −0.4)` the right edge of the card renders 504 px tall against 415
  on the left; at `(−0.8, 0.5)` it inverts to 338 against 526.
- **`uPointer`**, −1..1 across the card, `(0, 0)` at the centre. The reference
  leans the card *into* the cursor — `rotate.x = −(centerX / 3.5)` fed to
  `rotateY`, and CSS `rotateY(+)` pushes the right edge away — so the edge under
  the pointer comes forward and `tilt = pointer`, not its mirror.

The Dart side matches with `setEntry(3, 2, +perspective)`, `rotateY(+tilt.dx·θ)`,
`rotateX(−tilt.dy·θ)`. Note that the sign of the perspective entry flips the
meaning of both rotations: CSS `perspective(600px)` is a **negative** (3, 2),
Flutter's idiomatic `setEntry(3, 2, 0.001)` is positive, so the Flutter rotations
come out opposite in sign to the CSS ones for the same visual result.

## 4. Uniform table

Declaration order *is* the `setFloat` index; `_U` in `holo_card.dart` mirrors it.

| Index | Uniform | Meaning |
|---|---|---|
| 0–1 | `uSize` | card in logical px |
| 2–3 | `uTilt` | −1..1; +x = right edge toward the viewer, +y = bottom edge toward it |
| 4–5 | `uPointer` | −1..1 across the card, 0 = centre |
| 6 | `uPointerStrength` | 0 = no pointer; foil and glare are gone, the site's `--card-opacity` |
| 7 | `uPattern` | 0 classic, 1 reverse, 2 galaxy |
| 8 | `uMask` | 0 whole card, 1 child luminance, 2 child alpha |
| 9 | `uFoil` | rainbow strength |
| 10 | `uGlare` | white blob strength |
| 11 | `uGrain` | how far the foil is broken up, 0..1 |
| 12 | `uBandScale` | rainbow bands across the card |
| 13 | `uRadius` | corner radius, logical px |
| 14 | `uSeed` | shifts every hash and the band phase |

15 floats, plus sampler 0 = the card. Every knob is a field of `HoloConfig`;
nothing is hardcoded in Dart. What is hardcoded *in the shader* is the lobe
geometry (`TILT_ANGLE`, `LIGHT_HEIGHT`, `VIEW_DIST`, `SHININESS`) and the band
direction: those shape the effect rather than dress it, and exposing them would
have turned a 15-float block into a 25-float one for knobs nobody turns.

## 5. The foil, and why it is not a gradient

Five terms, in order.

**The surface normal.** `n = normalize(vec3(−uTilt · TILT_ANGLE, 1))`. Tilting
the right edge toward the viewer swings the normal to the left; that one line is
what the CSS layers have no equivalent for.

**The specular lobe.** A point light sits `LIGHT_HEIGHT` above the pointer and
the eye `VIEW_DIST` above the card, both in half-card units, so the half vector
`h` varies *across* the card and not just with the tilt. The foil brightness is
`0.22 + 0.55·(n·h)² + 1.15·(n·h)^14` — a broad lobe to carry the sheet and a
tight one for the place that actually faces the light. Without the wide term the
card is black outside a dot; without the tight one it is a flat wash. Classic and
reverse split the same `n·h` into a broad weight (`0.20 + 0.55·(n·h)²`) for the
substrate and a tight one (`(n·h)^14`) for the ornament laid over it — one
normal, two reflectances, never a second lobe computed for the ornament alone.

**The phase.** `band = dot(p, dir)·uBandScale + dot(uTilt, (4.8, 3.3)) +
|uTilt|·0.55 + uSeed·0.37`. The second term is the sweep — the site's
`background-position` bound to the pointer, here bound to the tilt, scaled to
match the site's 400%-background move (factors 2.6/3.5 of the pointer) so a
tilt rolls the spectrum through several periods rather than nudging it within
one. The third is the thin-film term: interference colour depends on the
*angle* through the film, which is isotropic, so the hue shifts with tilt
magnitude on top of the directional sweep. Colour comes from an Inigo Quilez
cosine palette, then a contrast and saturation curve standing in for the CSS
`filter:` chain.

**The rainbow gate.** `farthestGate(p, uPointer, wide, 0.6, 4.0)` reproduces the
site's `radial-gradient(farthest-corner circle at pointer, ...)` under
`mix-blend-mode: luminosity` and `brightness(.6) contrast(4)`: 1 at the pointer,
0 at the card corner farthest from it, then squashed through a brightness and
contrast curve so it collapses to a spot. It multiplies straight into
`foilAmount`, so the rainbow lives near the light and the rest of the card
stays dark — without it classic and reverse read as stripes over the whole
surface, since their phase term alone has no notion of *where* the light is.

**The sparkles.** One hashed dot per cell: `cos(h·2π·6 + phase(tilt))` through a
`smoothstep(0.80, 1.0)` gate, so a cell is lit only while the tilt phase sweeps
past its own hash. Tilting changes *which* sparkles are on, which is the thing a
static grain texture can only fake.

Patterns differ only in how those five combine:

| `uPattern` | Look | Extra |
|---|---|---|
| 0 classic | rainbow substrate under a fine bar-grating ornament, `pow(cos, 8)` gated | — |
| 1 reverse | duller substrate, etched ridges as the ornament, `pow(triangle, 5)` gated | 5 px sparkle grid, warm |
| 2 galaxy | palette riding a 3-octave FBM cloud | two sparkle grids, 7 px and 17 px |

Classic and reverse both `mix(substrateColor, ornamentColor, gateMask)`: the
substrate uses the broad reflectance and stays visible (if dull) everywhere,
the ornament uses the tight one and only shows its own colour where the mask
(`bars` or `ridge`) says the foil or the engraving actually is. Galaxy already
had two reflectances — `palette()` multiplied by `fbm` — so it is unchanged.

## 6. Blending

The card arrives premultiplied; everything below runs on straight alpha and the
result is re-multiplied at the end.

- **Foil** — `mix(screen, colorDodge, 0.55)`. Pure colour dodge is what the site
  uses (`mix-blend-mode: color-dodge`), and it is right in spirit: the foil shows
  on light art and almost not at all on dark ink. It also crushes anything
  already bright to flat white, which is what the site's
  `brightness(.85) contrast(2.75)` is there to hold back. Half a screen blend
  does the same job in one expression and keeps a gradient in the highlights.
- **Glare** — an overlay of `farthestGate(p, uPointer, wide, 0.6, 3.0)`, the
  same farthest-corner gate the rainbow uses, over a 0.20 floor: a compact,
  high-contrast circular highlight at the pointer, not a wash across the card,
  matching the site's `brightness(.6) contrast(3)` on its glare radial.
- **Grain** — multiplied into the foil only, never into the card, so a card at
  rest is clean.

The **mask** defaults to the child's luminance (`mix(0.12, 1.0, smoothstep(0.03,
0.80, lum))`), which is the assetless stand-in for the site's painted foil mask:
the foil follows the art and leaves the text panel alone. `HoloMask.card` skips
it — used by nothing in the presets since it makes the text unreadable under the
galaxy pattern, which is how the floor of 0.12 got chosen.

## 7. Drivers

`HoloController` owns `tilt`, `pointer` and `pointerStrength` and springs all
three toward a target. It has two modes: **aimed**, pulled by whatever input is
active on the stiff `followSpring`, and **resting**, pulled by the `restTilt` /
`restPointer` / `restStrength` fields on the soft `returnSpring`. `release()`
only switches the mode, so the rest target is read live every tick — which is
what lets a released card spring back to a sensor tilt that is still moving.

The spring is integrated per tick from a `SpringDescription` rather than run as a
`SpringSimulation`: a simulation fixes its end value at construction and the
target here changes on every pointer move. The ticker stops as soon as all five
axes are within 1e-3 of the target with a velocity below 1e-3.

**`PointerHoloDriver`** is the mapping, not a subscription: `MouseRegion.onHover`
on desktop and `Listener` drags on touch, both built into `HoloCard`, normalise
the local position to −1..1 and aim there. Exit or up calls `release()`.

**`SensorHoloDriver`** subscribes to `accelerometerEventStream` at
`SensorInterval.gameInterval` (50 Hz; the UI interval is 15 Hz and reads as a card
that steps rather than moves) and turns raw gravity into a tilt in three stages:

1. **One Euro** per axis (`minCutoff` 1 Hz, `beta` 0.05) — steady when the phone
   is still, no lag when it moves. A fixed low-pass has to pick one or the other.
2. **A drifting rest pose**, a second exponential filter with τ = 3 s, subtracted
   from the filtered signal. This is what makes the card flat however the phone
   is held: it reacts to *changes* in attitude, and a walk settles out in a few
   seconds instead of shaking the card.
3. **Scale** by `1 / (g · sin(sensorRange))`, so ±20° of change maps to ±1, then
   clamp.

Axis signs follow the sensors_plus (Android/W3C) frame: `+x` with the right edge
raised, `+y` with the top raised. `uTilt.y` is screen-down, so the y term is
negated. **This is derived, not measured** — see §9.

`SensorHoloDriver.isSupported` is `kIsWeb || android || iOS`; sensors_plus 7.1.0
declares plugins for those three only, so on macOS, Windows and Linux the driver
never subscribes and the card simply never gets a sensor tilt. A stream error
(permission denied on web, a device with no accelerometer) cancels the
subscription instead of propagating.

Pointer and sensors are independent opt-ins on `HoloCard` and every combination
works. When both are on, the sensor writes the rest pose on every sample but only
aims while no finger is down and no release is settling — so the finger wins while
it is down, the soft spring wins for the length of the return, and the sensor
takes over after.

## 8. The tilt is optional, and it is Dart

`config.maxAngle == 0` leaves the card flat and only the foil reacts; the demo
ships one card of each kind. When it is non-zero the rotation is a plain
`Transform` with a perspective entry — a matrix on the layer, the same cost class
as a `CATransform3D`, **not** an extra GPU pass and not something the shader
does. The foil reads the same `uTilt` either way, so the two are genuinely
separable.

## 9. Measurements, and what is still open

`flutter run --profile` on macOS (M-series, Impeller/Metal), three 210×292 cards,
120 frames per phase, `_debugProfile` in `example/lib/holo_demo.dart`:

| Phase | Build | Raster |
|---|---|---|
| idle | 0.08 ms | 0.89 ms |
| 3 cards spinning | 0.15 ms | 0.90 ms |
| idle again | 0.19 ms | 0.92 ms |
| 3 cards spinning again | 0.22 ms | 1.16 ms |

Moving all three cards costs **at most 0.26 ms of raster**, and the phases
overlap — the effect is at or below the noise floor of this scene at this size.
That is what one dependent-free texture read plus arithmetic should cost. Note
that "idle" is not a card-free baseline: the cards are painted in every phase, so
the number measures *animating* them, not the foil itself. The comparison against
`BackdropFilter.blur` that `CONTEXT.md` decision 7 asks for is the later
benchmark pass.

Open:

- **The accelerometer axis signs are derived, not verified.** Nobody has held a
  phone in front of this yet; `flutter build ios --debug` only proves the plugin
  compiles. If the card leans the wrong way, negate in `SensorHoloDriver._onSample`.
- **No hook to refresh the snapshot on demand.** A card with live content inside
  it freezes at capture, and only a change of `child` identity or size clears the
  raster. If a caller needs more, `HoloCard` should take a `SnapshotController`.
- **Sub-pixel sampler offset.** `SnapshotPainter` hands over both `image` and
  `sourceSize` because `image.width` is a rounded integer; the shader samples by
  normalised UV and ignores the difference, worth under a pixel.
- **No GLES Y-flip.** This is a plain `FragmentShader` over a canvas, not a
  backdrop filter, so it does not need one — but it has only been looked at on
  Impeller/Metal.
