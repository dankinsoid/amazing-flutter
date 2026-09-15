// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../snapshot/snapshot.dart';
import 'config.dart';
import 'controller.dart';

/// setFloat indices; mirrors the uniform block in `shaders/disintegration.frag`.
abstract final class _U {
	static const size = 0, childRect = 2;
	static const progress = 6, mode = 7, direction = 8, origin = 10, seed = 12;
	static const cellSize = 13, drift = 14, lift = 15, jitter = 16, spin = 17, shrink = 18;
	static const noiseScale = 19, turbulence = 20, radial = 21;
	static const softness = 22, sweep = 23, blur = 24, fade = 25, edgeFade = 26;
	static const erodeRadius = 27, erodeGrowth = 28, erodeDrag = 29, erodeSwirl = 30, erodeVortex = 31;
	static const trail = 32, trailDir = 160, trailStride = 4, maxTrail = 32;
}

/// Dissolves [child] on a swipe: shards, smoke, or blown out of the finger.
class Disintegrate extends StatefulWidget {
	const Disintegrate({
		super.key,
		required this.child,
		this.config = const DisintegrationConfig(),
		this.controller,
		this.onDismissed,
		this.enabled = true,
	});

	final Widget child;
	final DisintegrationConfig config;

	/// Null builds a private controller; pass one to drive the effect from outside.
	final DisintegrationController? controller;

	final VoidCallback? onDismissed;

	/// False leaves the child alone; a passed controller still drives it.
	final bool enabled;

	@override
	State<Disintegrate> createState() => _DisintegrateState();
}

class _DisintegrateState extends State<Disintegrate> with SingleTickerProviderStateMixin {
	static Future<ui.FragmentProgram>? _program;

	final _snapshot = ChildSnapshot();
	DisintegrationController? _private;
	ui.FragmentShader? _shader;
	Offset _travel = Offset.zero;
	bool _dismissSent = false;

	DisintegrationController get _effect => widget.controller ?? (_private ??= DisintegrationController(vsync: this));

	@override
	void initState() {
		super.initState();
		_effect.trail.spacing = widget.config.trailSpacing;
		_effect.addListener(_onEffect);
		_program ??= ui.FragmentProgram.fromAsset('packages/amazing_flutter/shaders/disintegration.frag');
		_program!.then((program) {
			if (!mounted) return;
			setState(() => _shader = program.fragmentShader());
		});
	}

	@override
	void didUpdateWidget(Disintegrate oldWidget) {
		super.didUpdateWidget(oldWidget);
		_effect.trail.spacing = widget.config.trailSpacing;
		if (oldWidget.controller != widget.controller) {
			(oldWidget.controller ?? _private)?.removeListener(_onEffect);
			_effect.addListener(_onEffect);
		}
	}

	@override
	void dispose() {
		_effect.removeListener(_onEffect);
		_private?.dispose();
		_snapshot.dispose();
		_shader?.dispose();
		super.dispose();
	}

	void _onEffect() {
		final effect = _effect;
		if (effect.isActive) {
			_snapshot.capture();
		} else {
			_snapshot.release();
		}
		final dismissed = effect.status == DisintegrationStatus.dismissed;
		if (dismissed && !_dismissSent) widget.onDismissed?.call();
		_dismissSent = dismissed;
	}

	void _onStart(DragStartDetails details) {
		_travel = Offset.zero;
		_effect.trail.spacing = widget.config.trailSpacing;
		_effect.beginDrag(details.localPosition);
	}

	void _onUpdate(DragUpdateDetails details) {
		_travel += details.delta;
		if (_effect.mode == DisintegrationMode.erode) {
			_effect.erode(details.localPosition);
			return;
		}
		_effect.drag(
			direction: _travel,
			progress: _travel.distance / widget.config.dismissDistance,
		);
	}

	void _onEnd(DragEndDetails details) {
		final direction = _effect.direction;
		final velocity = details.velocity.pixelsPerSecond;
		final along = velocity.dx * direction.dx + velocity.dy * direction.dy;
		if (_effect.mode == DisintegrationMode.erode) {
			// Any real stroke destroys the widget; only a tap-length scratch heals.
			_effect.settle(
				dismiss: _effect.trail.length > widget.config.dismissDistance * 0.25,
				velocity: velocity.distance / widget.config.dismissDistance,
			);
			return;
		}
		_effect.settle(
			dismiss: along > widget.config.flingVelocity || _effect.progress >= 0.6,
			velocity: along / widget.config.dismissDistance,
		);
	}

	void _onCancel() => _effect.settle(dismiss: false);

	ChildSnapshotPainter _painter(ui.Image snapshot, double spread) => _DisintegrationPainter(
		snapshot: snapshot,
		spread: spread,
		shader: _shader,
		config: widget.config,
		effect: _effect,
	);

	@override
	Widget build(BuildContext context) {
		final host = SnapshotHost(
			controller: _snapshot,
			spread: widget.config.spread,
			painterBuilder: _painter,
			child: widget.child,
		);
		if (!widget.enabled) return host;
		return GestureDetector(
			onPanStart: _onStart,
			onPanUpdate: _onUpdate,
			onPanEnd: _onEnd,
			onPanCancel: _onCancel,
			child: host,
		);
	}
}

class _DisintegrationPainter extends ChildSnapshotPainter {
	_DisintegrationPainter({
		required super.snapshot,
		required super.spread,
		required this.shader,
		required this.config,
		required this.effect,
	}) : super(repaint: effect);

	final ui.FragmentShader? shader;
	final DisintegrationConfig config;
	final DisintegrationController effect;

	@override
	void paint(Canvas canvas, Size size) {
		final rect = childRect(size);
		final shader = this.shader;
		if (shader == null) {
			_paintPlain(canvas, rect);
			return;
		}
		_write(shader, size, rect);
		canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
	}

	/// Until the program resolves there is a frame or two with no shader.
	void _paintPlain(Canvas canvas, Rect rect) {
		final source = Rect.fromLTWH(0, 0, snapshot.width.toDouble(), snapshot.height.toDouble());
		final paint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - effect.progress);
		canvas.drawImageRect(snapshot, source, rect, paint);
	}

	void _write(ui.FragmentShader shader, Size size, Rect rect) {
		final origin = rect.topLeft + (effect.origin ?? rect.center - rect.topLeft);
		shader
			..setFloat(_U.size, size.width)
			..setFloat(_U.size + 1, size.height)
			..setFloat(_U.childRect, rect.left)
			..setFloat(_U.childRect + 1, rect.top)
			..setFloat(_U.childRect + 2, rect.width)
			..setFloat(_U.childRect + 3, rect.height)
			..setFloat(_U.progress, effect.progress)
			..setFloat(_U.mode, effect.mode.index.toDouble())
			..setFloat(_U.direction, effect.direction.dx)
			..setFloat(_U.direction + 1, effect.direction.dy)
			..setFloat(_U.origin, origin.dx)
			..setFloat(_U.origin + 1, origin.dy)
			..setFloat(_U.seed, config.seed)
			..setFloat(_U.cellSize, config.cellSize)
			..setFloat(_U.drift, config.drift)
			..setFloat(_U.lift, config.lift)
			..setFloat(_U.jitter, config.jitter)
			..setFloat(_U.spin, config.spin)
			..setFloat(_U.shrink, config.shrink)
			..setFloat(_U.noiseScale, config.noiseScale)
			..setFloat(_U.turbulence, config.turbulence)
			..setFloat(_U.radial, config.radial)
			..setFloat(_U.softness, config.softness)
			..setFloat(_U.sweep, config.sweep)
			..setFloat(_U.blur, config.blur)
			..setFloat(_U.fade, config.fade)
			..setFloat(_U.edgeFade, config.edgeFade)
			..setFloat(_U.erodeRadius, config.erodeRadius)
			..setFloat(_U.erodeGrowth, config.erodeGrowth)
			..setFloat(_U.erodeDrag, config.erodeDrag)
			..setFloat(_U.erodeSwirl, config.erodeSwirl)
			..setFloat(_U.erodeVortex, config.erodeVortex);
		if (effect.mode == DisintegrationMode.erode) _writeTrail(shader, rect);
		shader.setImageSampler(0, snapshot);
	}

	/// Other modes never read the trail block, so it is only uploaded for erode.
	void _writeTrail(ui.FragmentShader shader, Rect rect) {
		final points = effect.trail.points;
		final now = DateTime.now();
		for (var i = 0; i < _U.maxTrail; i++) {
			final slot = _U.trail + i * _U.trailStride;
			if (i >= points.length) {
				// Strength 0 marks the slot empty; the shader reads nothing else from it.
				shader.setFloat(slot + 3, 0);
				continue;
			}
			final point = points[i];
			final at = rect.topLeft + point.position;
			final direction = _U.trailDir + i * _U.trailStride;
			shader
				..setFloat(slot, at.dx)
				..setFloat(slot + 1, at.dy)
				..setFloat(slot + 2, point.ageAt(now))
				..setFloat(slot + 3, point.strength)
				..setFloat(direction, point.direction.dx)
				..setFloat(direction + 1, point.direction.dy);
		}
	}

	@override
	bool shouldRepaint(_DisintegrationPainter old) =>
		old.shader != shader || old.config != config || old.snapshot != snapshot;
}
