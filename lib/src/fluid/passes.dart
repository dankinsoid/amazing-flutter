// @ai-generated(solo)

import 'dart:ui' as ui;

/// Runs offscreen fragment-shader passes and frees their images; see `docs/fluid.md`.
class PassRunner {
	var _retiring = <ui.Image>[];
	var _retired = <ui.Image>[];

	/// Images recorded but not yet freed; a frame's working set.
	int get pending => _retiring.length + _retired.length;

	/// Rasterises whatever [draw] records into a fresh [width] x [height] image.
	ui.Image rasterize(
		int width,
		int height,
		void Function(ui.Canvas canvas) draw, {
		ui.TargetPixelFormat format = ui.TargetPixelFormat.dontCare,
	}) {
		final recorder = ui.PictureRecorder();
		final canvas = ui.Canvas(recorder);
		draw(canvas);
		final picture = recorder.endRecording();
		final image = picture.toImageSync(width, height, targetFormat: format);
		picture.dispose();
		return image;
	}

	/// One pass over the whole target.
	ui.Image run(
		ui.FragmentShader shader,
		int width,
		int height, {
		ui.TargetPixelFormat format = ui.TargetPixelFormat.dontCare,
	}) {
		return rasterize(width, height, (canvas) {
			canvas.drawRect(
				ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
				ui.Paint()
					// src, or the target's clear colour blends into packed field data.
					..shader = shader
					..blendMode = ui.BlendMode.src
					..isAntiAlias = false,
			);
		}, format: format);
	}

	/// Hands back a superseded image; it is freed one [recycle] later.
	void retire(ui.Image? image) {
		if (image != null) _retiring.add(image);
	}

	/// `toImageSync` rasterises lazily, so an image must outlive the frame reading it.
	void recycle() {
		for (final image in _retired) {
			image.dispose();
		}
		_retired = _retiring;
		_retiring = <ui.Image>[];
	}

	void dispose() {
		recycle();
		recycle();
	}
}

/// One simulation field; no ping-pong pair, since every pass allocates its target.
class Field {
	ui.Image? _image;

	ui.Image get image => _image!;
	bool get isEmpty => _image == null;

	/// Retires the previous image through [runner] and adopts [next].
	void swap(ui.Image next, PassRunner runner) {
		runner.retire(_image);
		_image = next;
	}

	void clear(PassRunner runner) {
		runner.retire(_image);
		_image = null;
	}
}
