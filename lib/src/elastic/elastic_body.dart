// @ai-generated(guided)

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Domain warp of an outline: stretch along [stretch], and [pull] at [grab] with Gaussian falloff.
@immutable
final class ShapeDeform {
	const ShapeDeform({
		this.stretch = Offset.zero,
		this.grab = Offset.zero,
		this.pull = Offset.zero,
		this.pullRadius = 0,
	});

	static const none = ShapeDeform();

	final Offset stretch;
	final Offset grab;
	final Offset pull;
	final double pullRadius;

	bool get isNone => stretch == Offset.zero && pull == Offset.zero;
}

/// A point mass on a spring toward the finger while grabbed, coasting under
/// friction when released. Drives a [ShapeDeform] from its own state.
class ElasticBody extends ChangeNotifier {
	ElasticBody({
		required TickerProvider vsync,
		required Offset position,
		this.stiffness = 180,
		this.damping = 14,
		this.friction = 4,
		this.stretchPerSpeed = 0.0009,
		this.maxStretch = 0.6,
		this.pullGain = 0.6,
		this.pullRadius = 50,
	}) : _position = position {
		_ticker = vsync.createTicker(_tick);
	}

	/// Spring constant toward the finger, 1/s².
	double stiffness;
	/// Velocity damping while grabbed, 1/s.
	double damping;
	/// Velocity damping while coasting, 1/s.
	double friction;
	/// Extra length per px/s of speed.
	double stretchPerSpeed;
	double maxStretch;
	/// Fraction of the spring extension shown as a local pull at the grab point.
	double pullGain;
	double pullRadius;

	late final Ticker _ticker;
	Offset _position;
	Offset _velocity = Offset.zero;
	Offset? _target;
	Offset _grabLocal = Offset.zero;
	Duration _last = Duration.zero;

	Offset get position => _position;
	Offset get velocity => _velocity;
	bool get isGrabbed => _target != null;

	ShapeDeform get deform {
		final speed = _velocity.distance;
		final stretch = speed > 1e-3
			? _velocity / speed * math.min(speed * stretchPerSpeed, maxStretch)
			: Offset.zero;
		final target = _target;
		final pull = target == null ? Offset.zero : (target - (_position + _grabLocal)) * pullGain;
		return ShapeDeform(
			stretch: stretch,
			grab: _position + _grabLocal,
			pull: pull,
			pullRadius: pullRadius,
		);
	}

	/// [at] is where the finger landed; the pull acts from there.
	void grab(Offset at) {
		_grabLocal = at - _position;
		_target = at;
		_start();
	}

	void drag(Offset to) {
		_target = to;
		_start();
	}

	void release() {
		_target = null;
		_start();
	}

	void _start() {
		if (!_ticker.isActive) {
			_last = Duration.zero;
			_ticker.start();
		}
	}

	void _tick(Duration elapsed) {
		// Clamp so a stalled frame does not launch the spring.
		final dt = _last == Duration.zero ? 1 / 60 : math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
		_last = elapsed;
		final target = _target;
		Offset acceleration;
		if (target != null) {
			// The spring pulls the grab point, not the centre, toward the finger.
			acceleration = (target - (_position + _grabLocal)) * stiffness - _velocity * damping;
		} else {
			acceleration = -_velocity * friction;
		}
		_velocity += acceleration * dt;
		_position += _velocity * dt;
		final settled = target == null && _velocity.distance < 2;
		if (settled) {
			_velocity = Offset.zero;
			_ticker.stop();
		}
		notifyListeners();
	}

	@override
	void dispose() {
		_ticker.dispose();
		super.dispose();
	}
}
