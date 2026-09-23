// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'config.dart';
import 'controller.dart';
import 'drivers.dart';

/// setFloat indices; mirrors the uniform block in `shaders/glitter.frag`.
abstract final class _U {
	static const base = 0, light = 3, flicker = 5;
	static const flakeScale = 6, density = 7, gain = 8, rainbow = 9, grain = 10, seed = 11;
}

/// A glitter panel: a flat tone dusted with flakes that flash as the light moves.
/// It paints its own base instead of filtering a backdrop, so it needs no Impeller.
class GlitterSurface extends StatefulWidget {
	const GlitterSurface({
		super.key,
		this.config = GlitterConfig.pink,
		this.controller,
		this.pointer = true,
		this.sensors = true,
		this.child,
	});

	final GlitterConfig config;

	/// Null builds a private controller; pass one to share a light across panels.
	final GlitterController? controller;

	/// Hover on desktop, drag on touch.
	final bool pointer;

	/// Device tilt; a no-op where `sensors_plus` has no platform.
	final bool sensors;

	/// Painted over the glitter; the flakes never touch it.
	final Widget? child;

	@override
	State<GlitterSurface> createState() => _GlitterSurfaceState();
}

class _GlitterSurfaceState extends State<GlitterSurface> with SingleTickerProviderStateMixin {
	static Future<ui.FragmentProgram>? _program;

	GlitterController? _private;
	SensorGlitterDriver? _sensors;
	ui.FragmentShader? _shader;

	GlitterController get _light =>
		widget.controller ?? (_private ??= GlitterController(vsync: this, config: widget.config));

	@override
	void initState() {
		super.initState();
		_light.config = widget.config;
		_startSensors();
		_program ??= ui.FragmentProgram.fromAsset('packages/amazing_flutter/shaders/glitter.frag');
		_program!.then((program) {
			if (!mounted) return;
			setState(() => _shader = program.fragmentShader());
		});
	}

	@override
	void didUpdateWidget(GlitterSurface oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.config != widget.config) {
			_light.config = widget.config;
			_sensors?.config = widget.config;
		}
		if (widget.sensors != oldWidget.sensors || oldWidget.controller != widget.controller) {
			_sensors?.dispose();
			_sensors = null;
			_startSensors();
		}
	}

	@override
	void dispose() {
		_sensors?.dispose();
		_shader?.dispose();
		_private?.dispose();
		super.dispose();
	}

	void _startSensors() {
		if (!widget.sensors || !SensorGlitterDriver.isSupported) return;
		_sensors = SensorGlitterDriver(onLight: _light.aimAt, config: widget.config)..start();
	}

	void _aim(Offset local) {
		final box = context.findRenderObject();
		if (box is! RenderBox || !box.hasSize) return;
		_light.aimAt(PointerGlitterDriver.normalise(local, box.size));
	}

	@override
	Widget build(BuildContext context) {
		final shader = _shader;
		Widget surface = shader == null
			? ColoredBox(color: widget.config.base, child: widget.child)
			: CustomPaint(
				painter: _GlitterPainter(shader: shader, light: _light, config: widget.config),
				child: widget.child,
			);

		if (!widget.pointer) return surface;

		return MouseRegion(
			onHover: (event) => _aim(event.localPosition),
			child: Listener(
				behavior: HitTestBehavior.translucent,
				onPointerDown: (event) => _aim(event.localPosition),
				onPointerMove: (event) => _aim(event.localPosition),
				child: surface,
			),
		);
	}
}

class _GlitterPainter extends CustomPainter {
	_GlitterPainter({required this.shader, required this.light, required this.config}) : super(repaint: light);

	final ui.FragmentShader shader;
	final GlitterController light;
	final GlitterConfig config;

	@override
	void paint(Canvas canvas, Size size) {
		final base = config.base;
		final tilt = light.light;
		shader
			..setFloat(_U.base, base.r)
			..setFloat(_U.base + 1, base.g)
			..setFloat(_U.base + 2, base.b)
			..setFloat(_U.light, tilt.dx)
			..setFloat(_U.light + 1, tilt.dy)
			..setFloat(_U.flicker, light.flicker)
			..setFloat(_U.flakeScale, config.flakeScale)
			..setFloat(_U.density, config.density)
			..setFloat(_U.gain, config.gain)
			..setFloat(_U.rainbow, config.rainbow)
			..setFloat(_U.grain, config.grain)
			..setFloat(_U.seed, config.seed);
		canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
	}

	// The controller repaints this painter; a rebuild only ever changes the config.
	@override
	bool shouldRepaint(_GlitterPainter old) => old.shader != shader || old.config != config;
}
