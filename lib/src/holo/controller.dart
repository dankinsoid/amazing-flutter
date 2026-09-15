// @ai-generated(solo)

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'config.dart';

/// Where the spring is pulling: an aimed target, or the drifting rest pose.
enum HoloAim { aimed, resting }

/// Owns tilt, pointer and pointer strength; drivers aim it, a spring carries it.
class HoloController extends ChangeNotifier {
	HoloController({required TickerProvider vsync, this.config = HoloConfig.holo}) {
		_ticker = vsync.createTicker(_tick);
	}

	late final Ticker _ticker;

	/// The springs and the sensor filters read it live; swapping it mid-flight is fine.
	HoloConfig config;

	final _tiltX = _Spring();
	final _tiltY = _Spring();
	final _pointerX = _Spring();
	final _pointerY = _Spring();
	final _strength = _Spring();

	HoloAim _aim = HoloAim.resting;
	Offset _aimedTilt = Offset.zero;
	Offset _aimedPointer = Offset.zero;
	double _aimedStrength = 0;

	Offset _restTilt = Offset.zero;
	Offset _restPointer = Offset.zero;
	double _restStrength = 0;

	Duration _last = Duration.zero;

	Offset get tilt => Offset(_tiltX.value, _tiltY.value);

	Offset get pointer => Offset(_pointerX.value, _pointerY.value);

	double get pointerStrength => _strength.value;

	HoloAim get aim => _aim;

	/// True until the release has settled; a background driver should not fight it.
	bool get isSettling => _aim == HoloAim.resting && _ticker.isActive;

	/// Where [release] springs to; a sensor driver writes it every sample.
	Offset get restTilt => _restTilt;

	set restTilt(Offset value) {
		if (value == _restTilt) return;
		_restTilt = value;
		if (_aim == HoloAim.resting) _start();
	}

	Offset get restPointer => _restPointer;

	set restPointer(Offset value) {
		if (value == _restPointer) return;
		_restPointer = value;
		if (_aim == HoloAim.resting) _start();
	}

	double get restStrength => _restStrength;

	set restStrength(double value) {
		if (value == _restStrength) return;
		_restStrength = value;
		if (_aim == HoloAim.resting) _start();
	}

	/// Drives the card from an active input; the stiff spring keeps up with it.
	void aimAt({Offset? tilt, Offset? pointer, double? strength}) {
		_aimedTilt = tilt ?? _aimedTilt;
		_aimedPointer = pointer ?? _aimedPointer;
		_aimedStrength = strength ?? _aimedStrength;
		_aim = HoloAim.aimed;
		_start();
	}

	/// Hands the card back to the rest pose on the soft spring.
	void release() {
		_aim = HoloAim.resting;
		_start();
	}

	/// Debug entry point: parks the card without a simulation.
	void freeze({Offset? tilt, Offset? pointer, double? strength}) {
		_ticker.stop();
		if (tilt != null) {
			_tiltX.park(tilt.dx);
			_tiltY.park(tilt.dy);
			_aimedTilt = tilt;
			_restTilt = tilt;
		}
		if (pointer != null) {
			_pointerX.park(pointer.dx);
			_pointerY.park(pointer.dy);
			_aimedPointer = pointer;
			_restPointer = pointer;
		}
		if (strength != null) {
			_strength.park(strength);
			_aimedStrength = strength;
			_restStrength = strength;
		}
		notifyListeners();
	}

	void _start() {
		if (_ticker.isActive) return;
		_last = Duration.zero;
		_ticker.start();
	}

	void _tick(Duration elapsed) {
		// A stalled frame must not blow the integrator up.
		final dt = _last == Duration.zero ? 1 / 60 : ((elapsed - _last).inMicroseconds / 1e6).clamp(1 / 240, 1 / 30);
		_last = elapsed;

		final aimed = _aim == HoloAim.aimed;
		final spring = aimed ? config.followSpring : config.returnSpring;
		final tilt = aimed ? _aimedTilt : _restTilt;
		final pointer = aimed ? _aimedPointer : _restPointer;
		final strength = aimed ? _aimedStrength : _restStrength;

		var settled = _tiltX.step(tilt.dx, spring, dt);
		settled &= _tiltY.step(tilt.dy, spring, dt);
		settled &= _pointerX.step(pointer.dx, spring, dt);
		settled &= _pointerY.step(pointer.dy, spring, dt);
		settled &= _strength.step(strength, spring, dt);

		if (settled) _ticker.stop();
		notifyListeners();
	}

	@override
	void dispose() {
		_ticker.dispose();
		super.dispose();
	}
}

/// One spring axis; integrated, not a [SpringSimulation], because the target keeps moving.
class _Spring {
	double value = 0;
	double velocity = 0;

	void park(double target) {
		value = target;
		velocity = 0;
	}

	bool step(double target, SpringDescription spring, double dt) {
		final acceleration = (spring.stiffness * (target - value) - spring.damping * velocity) / spring.mass;
		velocity += acceleration * dt;
		value += velocity * dt;
		if ((target - value).abs() < 1e-3 && velocity.abs() < 1e-3) {
			park(target);
			return true;
		}
		return false;
	}
}
