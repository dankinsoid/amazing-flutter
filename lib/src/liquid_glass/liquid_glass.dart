// @ai-generated(guided)

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import 'material.dart';
import 'shapes.dart';
import 'touch.dart';

/// setFloat indices; mirrors the uniform block in `shaders/liquid_glass.frag`.
abstract final class _U {
	static const light = 2;
	static const smoothK = 5, edgeWidth = 6, glassHeight = 7;
	static const thickness = 8, aberration = 9, tint = 10, saturation = 14;
	static const specular = 15, shininess = 16, rim = 17, rimWidth = 18, fresnel = 19, innerShadow = 20;
	static const hasContent = 21, contentStrength = 26;
	static const wave = 27;
	static const touches = 31, touchStride = 4, maxTouches = 32;
	static const shapes = 159, maxShapes = 8;
	static const total = 255;
}

/// One merged glass surface over [child]; positions are logical px from its top-left.
class LiquidGlass extends StatefulWidget {
	const LiquidGlass({
		super.key,
		required this.shapes,
		required this.child,
		this.material = const GlassMaterial(),
		this.touches = const [],
		this.light,
	}) : assert(shapes.length <= _U.maxShapes);

	final List<GlassShape> shapes;
	final GlassMaterial material;
	/// Newest last; only the newest [_U.maxTouches] reach the shader.
	final List<GlassTouch> touches;
	/// Direction to the light, +z toward the viewer. Defaults to upper-left.
	final Vector3? light;
	final Widget child;

	@override
	State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> with SingleTickerProviderStateMixin {
	static Future<ui.FragmentProgram>? _program;

	ui.FragmentShader? _shader;
	late final Ticker _ticker;
	final _floats = Float32List(_U.total);

	@override
	void initState() {
		super.initState();
		_ticker = createTicker(_tick);
		// fwidth() has no SkSL equivalent: on Skia the program does not even compile.
		if (ui.ImageFilter.isShaderFilterSupported) {
			_program ??= ui.FragmentProgram.fromAsset('packages/amazing_flutter/shaders/liquid_glass.frag');
			_program!.then((program) {
				if (!mounted) return;
				setState(() => _shader = program.fragmentShader());
			});
		}
		_syncTicker();
	}

	@override
	void didUpdateWidget(LiquidGlass oldWidget) {
		super.didUpdateWidget(oldWidget);
		_syncTicker();
	}

	@override
	void dispose() {
		_ticker.dispose();
		_shader?.dispose();
		super.dispose();
	}

	bool get _hasLiveTouch {
		final now = DateTime.now();
		return widget.touches.any((t) => t.isAliveAt(now, widget.material.wave));
	}

	void _syncTicker() {
		if (_hasLiveTouch) {
			if (!_ticker.isActive) _ticker.start();
		} else {
			_ticker.stop();
		}
	}

	void _tick(Duration _) {
		if (!_hasLiveTouch) _ticker.stop();
		setState(() {});
	}

	void _writeUniforms(ui.FragmentShader shader, double dpr) {
		final f = _floats..fillRange(0, _U.total, 0);
		final m = widget.material;
		final light = widget.light ?? Vector3(-0.35, -0.6, 0.72);

		f[_U.light] = light.x;
		f[_U.light + 1] = light.y;
		f[_U.light + 2] = light.z;

		f[_U.smoothK] = m.smoothK * dpr;
		f[_U.edgeWidth] = m.edgeWidth * dpr;
		f[_U.glassHeight] = m.height * dpr;

		f[_U.thickness] = m.thickness * dpr;
		f[_U.aberration] = m.aberration;
		f[_U.tint] = m.tint.r;
		f[_U.tint + 1] = m.tint.g;
		f[_U.tint + 2] = m.tint.b;
		f[_U.tint + 3] = m.tintStrength;
		f[_U.saturation] = m.saturation;
		f[_U.specular] = m.specular;
		f[_U.shininess] = m.shininess;
		f[_U.rim] = m.rim;
		f[_U.rimWidth] = m.rimWidth * dpr;
		f[_U.fresnel] = m.fresnel;
		f[_U.innerShadow] = m.innerShadow;

		f[_U.hasContent] = 0;
		f[_U.contentStrength] = m.contentStrength;

		f[_U.wave] = m.wave.k / dpr;
		f[_U.wave + 1] = m.wave.omega;
		f[_U.wave + 2] = m.wave.reach * dpr;
		f[_U.wave + 3] = m.wave.lifetime;

		final now = DateTime.now();
		final live = widget.touches.where((t) => t.isAliveAt(now, m.wave)).toList();
		final touches = live.length > _U.maxTouches ? live.sublist(live.length - _U.maxTouches) : live;
		for (var i = 0; i < touches.length; i++) {
			final t = touches[i];
			final o = _U.touches + i * _U.touchStride;
			f[o] = t.position.dx * dpr;
			f[o + 1] = t.position.dy * dpr;
			f[o + 2] = t.ageAt(now);
			f[o + 3] = t.amplitude * m.rippleStrength * dpr;
		}

		for (var i = 0; i < widget.shapes.length; i++) {
			widget.shapes[i].write(f, _U.shapes + i * GlassShape.floatsPerShape, dpr);
		}

		// Indices 0–1 are uSize, filled by the engine.
		for (var i = _U.light; i < _U.total; i++) {
			shader.setFloat(i, f[i]);
		}
	}

	@override
	Widget build(BuildContext context) {
		if (!ui.ImageFilter.isShaderFilterSupported) return _fallback();
		final shader = _shader;
		if (shader == null) return widget.child;

		_writeUniforms(shader, MediaQuery.devicePixelRatioOf(context));
		var filter = ui.ImageFilter.shader(shader);
		final sigma = widget.material.frostSigma;
		if (sigma > 0) {
			filter = ui.ImageFilter.compose(
				outer: filter,
				inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
			);
		}
		return Stack(
			fit: StackFit.expand,
			children: [
				widget.child,
				BackdropFilter.grouped(filter: filter, child: const SizedBox.expand()),
			],
		);
	}

	Widget _fallback() {
		final m = widget.material;
		return Stack(
			fit: StackFit.expand,
			children: [
				widget.child,
				CustomPaint(
					painter: _FlatGlassPainter(widget.shapes, m.tint.withValues(alpha: 0.25 + m.tintStrength)),
				),
			],
		);
	}
}

/// Skia fallback: flat tinted shapes, no refraction, no merging.
class _FlatGlassPainter extends CustomPainter {
	_FlatGlassPainter(this.shapes, this.color);

	final List<GlassShape> shapes;
	final Color color;

	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()..color = color;
		for (final shape in shapes) {
			shape.paint(canvas, paint);
		}
	}

	@override
	bool shouldRepaint(_FlatGlassPainter old) => old.shapes != shapes || old.color != color;
}
