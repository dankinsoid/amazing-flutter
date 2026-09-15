// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show PaintingContextCallback;
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'controller.dart';
import 'drivers.dart';

/// setFloat indices; mirrors the uniform block in `shaders/holo.frag`.
abstract final class _U {
	static const size = 0, tilt = 2, pointer = 4, pointerStrength = 6;
	static const pattern = 7, mask = 8;
	static const foil = 9, glare = 10, grain = 11, bandScale = 12, radius = 13, seed = 14;
}

/// A foil over [child]: it sweeps with the tilt and glints under the pointer.
class HoloCard extends StatefulWidget {
	const HoloCard({
		super.key,
		required this.child,
		this.config = HoloConfig.holo,
		this.controller,
		this.pointer = true,
		this.sensors = false,
	});

	final Widget child;
	final HoloConfig config;

	/// Null builds a private controller; pass one to drive the card from outside.
	final HoloController? controller;

	/// Hover on desktop, drag on touch.
	final bool pointer;

	/// Device tilt; a no-op where `sensors_plus` has no platform.
	final bool sensors;

	@override
	State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard> with SingleTickerProviderStateMixin {
	static Future<ui.FragmentProgram>? _program;

	final _snapshot = SnapshotController(allowSnapshotting: true);
	HoloController? _private;
	SensorHoloDriver? _sensors;
	_HoloPainter? _painter;
	ui.FragmentShader? _shader;
	bool _pointerDown = false;

	HoloController get _effect => widget.controller ?? (_private ??= HoloController(vsync: this, config: widget.config));

	@override
	void initState() {
		super.initState();
		_effect.config = widget.config;
		_startSensors();
		_program ??= ui.FragmentProgram.fromAsset('packages/amazing_flutter/shaders/holo.frag');
		_program!.then((program) {
			if (!mounted) return;
			setState(() {
				_shader = program.fragmentShader();
				_painter = _HoloPainter(shader: _shader!, controller: _effect, config: widget.config);
			});
		});
	}

	@override
	void didUpdateWidget(HoloCard oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.controller != widget.controller) {
			_painter?.controller = _effect;
			_sensors?.stop();
			_startSensors();
		}
		if (oldWidget.config != widget.config) {
			_effect.config = widget.config;
			_sensors?.config = widget.config;
			_painter?.config = widget.config;
		}
		if (widget.sensors != oldWidget.sensors) {
			if (widget.sensors) {
				_startSensors();
			} else {
				_sensors?.dispose();
				_sensors = null;
				_effect
					..restTilt = Offset.zero
					..restPointer = Offset.zero
					..restStrength = 0;
			}
		}
		// A different child is different content; the raster would otherwise stay stale.
		if (oldWidget.child != widget.child) _snapshot.clear();
	}

	@override
	void dispose() {
		_sensors?.dispose();
		_painter?.dispose();
		_shader?.dispose();
		_private?.dispose();
		_snapshot.dispose();
		super.dispose();
	}

	void _startSensors() {
		if (!widget.sensors || !SensorHoloDriver.isSupported) return;
		_sensors = SensorHoloDriver(onTilt: _onSensorTilt, config: widget.config)..start();
	}

	void _onSensorTilt(Offset tilt) {
		final effect = _effect;
		effect
			..restTilt = tilt
			..restPointer = tilt
			..restStrength = 1;
		// The finger owns the card while it is down, and the release spring owns it after.
		if (_pointerDown || effect.isSettling) return;
		effect.aimAt(tilt: tilt, pointer: tilt, strength: 1);
	}

	Size? get _cardSize {
		final box = context.findRenderObject();
		return box is RenderBox && box.hasSize ? box.size : null;
	}

	void _aim(Offset local) {
		final size = _cardSize;
		if (size == null) return;
		final pointer = PointerHoloDriver.normalise(local, size);
		_effect.aimAt(tilt: PointerHoloDriver.tiltFor(pointer), pointer: pointer, strength: 1);
	}

	void _releasePointer() {
		_pointerDown = false;
		_effect.release();
	}

	@override
	Widget build(BuildContext context) {
		final painter = _painter;
		Widget card = painter == null
			? widget.child
			: SnapshotWidget(
				controller: _snapshot,
				mode: SnapshotMode.permissive,
				autoresize: true,
				painter: painter,
				child: widget.child,
			);

		if (widget.config.maxAngle > 0) {
			card = ListenableBuilder(
				listenable: _effect,
				builder: (context, child) => Transform(
					alignment: Alignment.center,
					transform: _tiltMatrix(_effect.tilt, widget.config),
					child: child,
				),
				child: card,
			);
		}

		if (!widget.pointer) return card;

		return MouseRegion(
			onHover: (event) => _aim(event.localPosition),
			onExit: (_) => _releasePointer(),
			child: Listener(
				behavior: HitTestBehavior.translucent,
				onPointerDown: (event) {
					_pointerDown = true;
					_aim(event.localPosition);
				},
				onPointerMove: (event) => _aim(event.localPosition),
				onPointerUp: (_) => _releasePointer(),
				onPointerCancel: (_) => _releasePointer(),
				child: card,
			),
		);
	}
}

/// A layer matrix, the same cost class as a `CATransform3D`; no extra GPU pass.
Matrix4 _tiltMatrix(Offset tilt, HoloConfig config) {
	// With a positive (3, 2) entry, +rotateY brings the right edge toward the viewer.
	return Matrix4.identity()
		..setEntry(3, 2, config.perspective)
		..rotateY(tilt.dx * config.maxAngle)
		..rotateX(-tilt.dy * config.maxAngle);
}

class _HoloPainter extends SnapshotPainter {
	_HoloPainter({required this.shader, required HoloController controller, required HoloConfig config})
		: _controller = controller,
		  _config = config {
		_controller.addListener(notifyListeners);
	}

	final ui.FragmentShader shader;

	HoloController _controller;
	HoloConfig _config;

	set controller(HoloController value) {
		if (value == _controller) return;
		_controller.removeListener(notifyListeners);
		_controller = value;
		_controller.addListener(notifyListeners);
		notifyListeners();
	}

	set config(HoloConfig value) {
		if (value == _config) return;
		_config = value;
		notifyListeners();
	}

	@override
	void paintSnapshot(
		PaintingContext context,
		Offset offset,
		Size size,
		ui.Image image,
		Size sourceSize,
		double pixelRatio,
	) {
		final tilt = _controller.tilt;
		final pointer = _controller.pointer;
		shader
			..setFloat(_U.size, size.width)
			..setFloat(_U.size + 1, size.height)
			..setFloat(_U.tilt, tilt.dx)
			..setFloat(_U.tilt + 1, tilt.dy)
			..setFloat(_U.pointer, pointer.dx)
			..setFloat(_U.pointer + 1, pointer.dy)
			..setFloat(_U.pointerStrength, _controller.pointerStrength)
			..setFloat(_U.pattern, _config.pattern.index.toDouble())
			..setFloat(_U.mask, _config.mask.index.toDouble())
			..setFloat(_U.foil, _config.foil)
			..setFloat(_U.glare, _config.glare)
			..setFloat(_U.grain, _config.grain)
			..setFloat(_U.bandScale, _config.bandScale)
			..setFloat(_U.radius, _config.radius)
			..setFloat(_U.seed, _config.seed)
			..setImageSampler(0, image);
		context.canvas
			..save()
			..translate(offset.dx, offset.dy)
			..drawRect(Offset.zero & size, Paint()..shader = shader)
			..restore();
	}

	@override
	void paint(PaintingContext context, Offset offset, Size size, PaintingContextCallback painter) {
		painter(context, offset);
	}

	@override
	bool shouldRepaint(covariant _HoloPainter oldPainter) => true;

	@override
	void dispose() {
		_controller.removeListener(notifyListeners);
		super.dispose();
	}
}
