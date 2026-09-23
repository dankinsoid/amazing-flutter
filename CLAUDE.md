# amazing-flutter

GPU shader effects for Flutter. Read `CONTEXT.md` before starting work — it holds
the settled architectural decisions and the build order. `docs/research.md` is the
background research behind them.

## Language

English for anything that outlives the conversation — code, comments, commits,
docs. Russian when talking to the user directly.

## Architecture rules

These are decisions, not preferences. Each has a rationale in `CONTEXT.md`.

- **One height field in screen coordinates**, shared across the scene — never
  local to a single panel.
- **Sum heights before deriving the normal.** Never layer two finished effects
  that each compute their own normal.
- **One shader with branches** beats a stack of thin shaders: Flutter cannot merge
  `FragmentProgram`s, so each stacked layer is a whole extra pass.
- **All maths in `.frag`**, Dart binding passes parameters only. Every shader must
  stay detachable as a single file.

## Shader conventions

- `.frag` files live in `shaders/`, declared in `pubspec.yaml` under
  `flutter: shaders:`.
- Uniform declaration order *is* the `setFloat` index — keep a comment marking the
  index of each uniform block, and update it when reordering.
- No int or bool uniforms exist; pass floats and compare against a threshold.
- Uniform arrays are indexed by constants only. Unroll small cases; for larger
  data, pass a texture.
- Guard every backdrop shader with `ui.ImageFilter.isShaderFilterSupported` and
  provide a fallback — it is Impeller-only.
- Invert the Y axis when running on GLES, or output renders upside-down.

## Verifying

`dart analyze` does not catch shader problems — a `.frag` that compiles can still
render nothing. Verify visually by running the example app on macOS or iOS
(Impeller), not by assuming a successful build means a working effect.

Profile with `flutter run --profile` and watch the raster thread; target under
8 ms per frame at 120 Hz. Shader compilation jank is not a concern on Impeller —
pipelines are compiled at build time.

## Git

Commit after each turn that changed files, with a descriptive message. Do not ask
permission. Assume someone else may be working on the branch.

## Formatting

Tabs for indentation.
