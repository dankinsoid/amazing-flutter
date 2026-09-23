# amazing_flutter

GPU shader effects for Flutter: a real fluid solver, holographic foil, refracting
glass, and dissolves — all written as fragment shaders and driven from Dart.

Everything below is a screen recording of the example app, rendered in real time
on Impeller.

> **Beta.** The effects work, the API does not stand still yet: names and parameters
> change between commits, there is no release on pub.dev, and only macOS and iOS are
> exercised regularly. Pin a commit if you depend on it.

---

## Fluid

https://github.com/user-attachments/assets/01ba7d6e-78ad-44bb-8462-5343483db653

Stable Fluids on the GPU — splat, vorticity confinement, a Jacobi pressure solve,
advection — with one twist: the dye is not ink, it is a live widget. A card is
snapshotted the moment a finger lands on it and handed to the field, so it looks
solid until you touch it and then flows, swirls and dissipates.

```dart
FluidScene(
	child: Row(
		children: [
			for (final card in cards)
				Fluid(onDismissed: () => remove(card), child: card),
		],
	),
)
```

One simulation domain per scene, not per card: a per-card domain has walls, and the
eye reads the box before it reads the fluid. The solver is a port of Pavel
Dobryakov's [WebGL-Fluid-Simulation](https://github.com/PavelDoGreat/WebGL-Fluid-Simulation)
(MIT). Design notes and timings: [`docs/fluid.md`](docs/fluid.md).

---

## Holo

https://github.com/user-attachments/assets/5fa0210f-9444-4711-803b-f8c7b1a9ecc3

Holographic foil over any widget: a rainbow whose phase follows the tilt, a glare
that tracks the pointer, and sparkles that glint in and out with the angle. There
are no foil textures — the pattern is a cosine palette and a hash, and the mask is
the child's own luminance, so any card gets a foil that follows its artwork.

The idea comes straight from the holographic Pokémon cards of
[poke-holo](https://poke-holo.simey.me/) and
[pokemon-cards-css](https://github.com/simeydotme/pokemon-cards-css) (MIT). Nothing
was copied — what was taken is the recipe, and the port is not one to one: the site
stacks DOM layers with CSS blend modes over authored foil artwork, this is one
fragment shader with no assets. A CSS gradient has no surface normal, so its foil
moves but never faces the light, and its grain cannot change which grains are lit.

```dart
HoloCard(
	config: HoloConfig.galaxy,
	sensors: true, // device tilt; pointer is on by default
	child: card,
)
```

Cursor drives it on desktop, the accelerometer on phones, both smoothed by a One
Euro filter. Design notes: [`docs/holo.md`](docs/holo.md).

---

## Liquid glass

https://github.com/user-attachments/assets/190ad2ae-f940-45ba-8bcd-d7bdbe8dd831

One backdrop pass draws every glass surface in the scene: shapes are merged with a
smooth minimum into a single distance field, turned into a height field, and the
normal of that field refracts the backdrop. The border carries spectral dispersion,
so the steep rim splits the background into a fringe instead of a white outline.
Touches drop water rings into the same height field, which is why a ripple can cross
the wallpaper and enter the glass.

```dart
LiquidGlass(
	shapes: [
		GlassCapsule(a: Offset(60, 120), b: Offset(300, 120), radius: 28),
		GlassCircle(center: blob, radius: 74),
	],
	material: const GlassMaterial(edgeWidth: 26, thickness: 88, aberration: 0.45),
	child: wallpaper,
)
```

The height field lives in screen coordinates, so `LiquidGlass` fills the screen and
shape positions are screen positions — that is what makes one pass enough for the
whole scene. Design notes: [`docs/liquid_glass.md`](docs/liquid_glass.md).

---

## Disintegration

A widget dissolves on a swipe, in four modes out of one shader: `shards` (the
lattice blows apart), `smoke`, `blowAway` (radial, out of the finger), and `erode`,
where the finger itself eats the widget away along its trail.

```dart
Disintegrate(
	config: DisintegrationConfig.of(DisintegrationMode.erode),
	onDismissed: () => remove(item),
	child: item,
)
```

This one runs over a snapshot rather than the backdrop, so it works on Skia too.
Design notes: [`docs/disintegration.md`](docs/disintegration.md).

---

## Using it

```yaml
dependencies:
  amazing_flutter:
    git: https://github.com/dankinsoid/amazing-flutter.git
```

Requirements:

- **Impeller.** Liquid glass and fluid read the backdrop through
  `ui.ImageFilter.shader`, which Skia cannot compile; liquid glass falls back to flat
  tinted shapes where `ui.ImageFilter.isShaderFilterSupported` is false. Holo and
  disintegration run anywhere.
- Flutter 3.38+, Dart 3.10+.
- On GLES the Y axis is flipped; the bindings handle it.

Run the demos:

```sh
cd example && flutter run -d macos --release
```

## How it works

- [`CONTEXT.md`](CONTEXT.md) — the architectural decisions every effect is built on:
  one height field in screen coordinates, compose before taking the normal, one fat
  shader instead of stacked passes.
- [`docs/`](docs/) — one design note per effect: pipeline, uniforms, and the
  measurements behind the defaults.
- [`docs/research.md`](docs/research.md) — the survey these decisions came out of.
