// @ai-generated(solo)

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'config.dart';

/// The virtual light, its agitation and the flicker clock.
///
/// Aimed from outside; ticked here, because the flicker clock advances with
/// movement rather than with time.
class GlitterController extends ChangeNotifier {
	GlitterController({required TickerProvider vsync, this.config = GlitterConfig.pink}) {
		_agitation = config.restAgitation;
		_ticker = vsync.createTicker(_tick)..start();
	}

	late final Ticker _ticker;

	/// Read live on every frame; swapping it mid-flight is fine.
	GlitterConfig config;

	/// Hand tremor cancels itself out in a heavily smoothed tilt, a deliberate turn
	/// does not, so the speed of this one tells the two apart.
	static const _steadying = 0.30;

	/// Tilt units per second of steady motion that count as full agitation.
	static const _fullMovementSpeed = 1.2;

	/// Tremor sits below this and never wakes the sparkle.
	static const _tremorFloor = 0.30;

	/// Per-sample easing toward the measured speed; ~130 ms up, ~220 ms down.
	static const _attack = 0.55;
	static const _release = 0.22;

	/// The shader works in float32; both clocks stay small.
	static const _clockWrap = 3600.0;

	Offset _aim = Offset.zero;
	Offset _steady = Offset.zero;
	double _agitation = 0;
	double _flicker = 0;
	double _time = 0;
	bool _aimed = false;
	Duration _last = Duration.zero;

	/// Where the flakes think the light is, -1..1 per axis, drift included.
	Offset get light {
		final drift = config.idleDrift + config.movingDrift * _agitation;
		return Offset(
			_aim.dx + drift * math.cos(_time * 0.55),
			_aim.dy + drift * math.sin(_time * 0.40),
		);
	}

	/// How much the surface is being moved, 0..1, eased at both ends.
	double get agitation => _agitation;

	double get flicker => _flicker;

	/// Points the light; a driver calls this on its own clock.
	void aimAt(Offset light) {
		_aim = Offset(light.dx.clamp(-0.9, 0.9), light.dy.clamp(-0.9, 0.9));
		_aimed = true;
	}

	void _tick(Duration elapsed) {
		// A stalled frame must not blow the integrator up.
		final dt = _last == Duration.zero ? 1 / 60 : ((elapsed - _last).inMicroseconds / 1e6).clamp(1 / 240, 1 / 30);
		_last = elapsed;
		_time = (_time + dt) % _clockWrap;

		_measureAgitation(dt);

		// Integrated, not scaled off the clock: warping the timestamp jumps the
		// phase and winks every flake at once. The floor keeps a rest pose breathing.
		_flicker = (_flicker + dt * (0.06 + 0.94 * _agitation)) % _clockWrap;
		notifyListeners();
	}

	void _measureAgitation(double dt) {
		// Nothing aims the light on a desktop without a pointer over the surface.
		if (!_aimed) {
			_agitation = config.restAgitation;
			return;
		}

		final previous = _steady;
		_steady += (_aim - _steady) * _steadying;
		final speed = ((_steady.dx - previous.dx).abs() + (_steady.dy - previous.dy).abs()) / dt;

		final excess = math.max(0.0, speed - _tremorFloor);
		final level = math.min(1.0, excess / (_fullMovementSpeed - _tremorFloor));
		_agitation += (level - _agitation) * (level > _agitation ? _attack : _release);
	}

	@override
	void dispose() {
		_ticker.dispose();
		super.dispose();
	}
}
