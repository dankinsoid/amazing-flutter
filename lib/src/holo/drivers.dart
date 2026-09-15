// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'config.dart';
import 'one_euro.dart';

/// Maps a pointer inside the card to a tilt and a glare centre, both -1..1.
abstract final class PointerHoloDriver {
	/// The reference clamps the pointer to the card and reads it from the centre out.
	static Offset normalise(Offset local, Size size) {
		if (size.isEmpty) return Offset.zero;
		return Offset(
			(local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
			(local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
		);
	}

	/// The reference leans the card into the cursor: the edge under it comes toward the viewer.
	static Offset tiltFor(Offset pointer) => pointer;
}

/// Gravity from the raw accelerometer as a tilt the card rests on.
class SensorHoloDriver {
	SensorHoloDriver({required this.onTilt, HoloConfig config = HoloConfig.holo}) : _config = config {
		_applyConfig();
	}

	/// Called with a tilt in -1..1 per axis, on the sensor's own clock.
	final ValueChanged<Offset> onTilt;

	static const _gravity = 9.80665;

	/// 50 Hz: the UI interval is 15 Hz, which reads as a card that steps rather than moves.
	static const _period = SensorInterval.gameInterval;

	HoloConfig _config;

	final _x = OneEuroFilter();
	final _y = OneEuroFilter();
	final _restX = DriftFilter(3);
	final _restY = DriftFilter(3);
	final _clock = Stopwatch();

	StreamSubscription<AccelerometerEvent>? _subscription;
	Duration _last = Duration.zero;

	/// sensors_plus ships Android, iOS and web only; anywhere else this driver does nothing.
	static bool get isSupported =>
		kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

	bool get isRunning => _subscription != null;

	set config(HoloConfig value) {
		_config = value;
		_applyConfig();
	}

	void _applyConfig() {
		_x.minCutoff = _config.sensorMinCutoff;
		_y.minCutoff = _config.sensorMinCutoff;
		_x.beta = _config.sensorBeta;
		_y.beta = _config.sensorBeta;
		_restX.tau = _config.sensorRestTau;
		_restY.tau = _config.sensorRestTau;
	}

	void start() {
		if (_subscription != null || !isSupported) return;
		_clock
			..reset()
			..start();
		_last = Duration.zero;
		_subscription = accelerometerEventStream(samplingPeriod: _period).listen(
			_onSample,
			// A platform without the sensor errors on the stream; the card just stays flat.
			onError: (Object _) => stop(),
			cancelOnError: true,
		);
	}

	void stop() {
		_subscription?.cancel();
		_subscription = null;
		_clock.stop();
		_x.reset();
		_y.reset();
		_restX.reset();
		_restY.reset();
	}

	void _onSample(AccelerometerEvent event) {
		final now = _clock.elapsed;
		final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
		_last = now;

		final x = _x.filter(event.x, dt);
		final y = _y.filter(event.y, dt);
		final restX = _restX.filter(x, dt);
		final restY = _restY.filter(y, dt);

		final scale = 1 / (_gravity * math.sin(_config.sensorRange.clamp(0.02, math.pi / 2)));
		// The accelerometer reads +x with the right edge raised and +y with the top raised.
		onTilt(Offset(
			((x - restX) * scale).clamp(-1.0, 1.0),
			(-(y - restY) * scale).clamp(-1.0, 1.0),
		));
	}

	void dispose() => stop();
}
