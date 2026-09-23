// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../holo/one_euro.dart';
import 'config.dart';

/// Maps a pointer over the surface to a light tilt, -1..1.
abstract final class PointerGlitterDriver {
	static Offset normalise(Offset local, Size size) {
		if (size.isEmpty) return Offset.zero;
		return Offset(
			(local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
			(local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
		);
	}
}

/// Gravity from the raw accelerometer as the angle the surface is held at.
/// The pose stays absolute: a drifting rest pose would flatten a held tilt out.
class SensorGlitterDriver {
	SensorGlitterDriver({required this.onLight, GlitterConfig config = GlitterConfig.pink}) : _config = config {
		_applyConfig();
	}

	/// Called with a light tilt in -1..1 per axis, on the sensor's own clock.
	final ValueChanged<Offset> onLight;

	static const _gravity = 9.80665;

	/// 50 Hz: flakes flash for a frame or two, and the UI interval's 15 Hz misses them.
	static const _period = SensorInterval.gameInterval;

	/// Centres the light on a hold of ~20° off flat, the way a phone is actually held.
	static const _lean = 0.35;

	GlitterConfig _config;

	final _x = OneEuroFilter();
	final _z = OneEuroFilter();
	final _clock = Stopwatch();

	StreamSubscription<AccelerometerEvent>? _subscription;
	Duration _last = Duration.zero;

	/// sensors_plus ships Android, iOS and web only; anywhere else this driver does nothing.
	static bool get isSupported =>
		kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

	bool get isRunning => _subscription != null;

	set config(GlitterConfig value) {
		_config = value;
		_applyConfig();
	}

	void _applyConfig() {
		_x.minCutoff = _config.sensorMinCutoff;
		_z.minCutoff = _config.sensorMinCutoff;
		_x.beta = _config.sensorBeta;
		_z.beta = _config.sensorBeta;
	}

	void start() {
		if (_subscription != null || !isSupported) return;
		_clock
			..reset()
			..start();
		_last = Duration.zero;
		_subscription = accelerometerEventStream(samplingPeriod: _period).listen(
			_onSample,
			// A platform without the sensor errors on the stream; the light just stays put.
			onError: (Object _) => stop(),
			cancelOnError: true,
		);
	}

	void stop() {
		_subscription?.cancel();
		_subscription = null;
		_clock.stop();
		_x.reset();
		_z.reset();
	}

	void _onSample(AccelerometerEvent event) {
		final now = _clock.elapsed;
		final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
		_last = now;

		// The accelerometer measures the reaction to gravity, so it points the
		// other way: -x is the left-right lean, -z the front-back one.
		final x = _x.filter(-event.x / _gravity, dt);
		final z = _z.filter(-event.z / _gravity, dt);

		final scale = 1 / math.sin(_config.sensorRange.clamp(0.02, math.pi / 2));
		onLight(Offset((x * scale).clamp(-1.0, 1.0), ((z + _lean) * scale).clamp(-1.0, 1.0)));
	}

	void dispose() => stop();
}
