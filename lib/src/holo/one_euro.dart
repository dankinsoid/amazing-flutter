// @ai-generated(solo)

import 'dart:math' as math;

/// Adaptive low-pass (Casiez, Roussel, Vogel): smooths at rest, opens up with speed.
class OneEuroFilter {
	OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.05, this.derivativeCutoff = 1.0});

	/// Cutoff at zero speed, Hz. Lower is steadier and laggier.
	double minCutoff;

	/// Hz of extra cutoff per unit of signal speed; what buys back the lag.
	double beta;

	/// Cutoff of the speed estimate itself, Hz.
	double derivativeCutoff;

	double? _value;
	double _speed = 0;

	double? get value => _value;

	void reset() {
		_value = null;
		_speed = 0;
	}

	double filter(double x, double dt) {
		final previous = _value;
		if (previous == null || dt <= 0) {
			_value = x;
			return x;
		}
		_speed = _lowPass((x - previous) / dt, _speed, _alpha(derivativeCutoff, dt));
		_value = _lowPass(x, previous, _alpha(minCutoff + beta * _speed.abs(), dt));
		return _value!;
	}

	static double _alpha(double cutoff, double dt) {
		final tau = 1 / (2 * math.pi * cutoff);
		return 1 / (1 + tau / dt);
	}

	static double _lowPass(double x, double previous, double alpha) => alpha * x + (1 - alpha) * previous;
}

/// Exponential smoothing with a time constant, for the slowly drifting rest pose.
class DriftFilter {
	DriftFilter(this.tau);

	/// Seconds to cover 63% of a step.
	double tau;

	double? _value;

	double? get value => _value;

	void reset() => _value = null;

	double filter(double x, double dt) {
		final previous = _value;
		if (previous == null || dt <= 0 || tau <= 0) {
			_value = x;
			return x;
		}
		final alpha = 1 - math.exp(-dt / tau);
		_value = previous + alpha * (x - previous);
		return _value!;
	}
}
