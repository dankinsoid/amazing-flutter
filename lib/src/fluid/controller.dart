// @ai-generated(solo)

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

enum FluidStatus { idle, touching, settling }

/// Input and lifetime of one fluid effect; the widget owns the GPU and the clock.
class FluidController extends ChangeNotifier {
	final List<(Offset, Offset)> _splats = <(Offset, Offset)>[];

	Offset? _last;
	FluidStatus _status = FluidStatus.idle;
	double _settled = 0;

	/// Seconds the sim keeps running after the finger lifts; set from the config.
	double lifetime = 3;

	/// Seconds of global fade at the end of [lifetime].
	double fadeOut = 1;

	/// Passes the solver recorded in the last frame; reported by the widget.
	int passes = 0;

	FluidStatus get status => _status;
	bool get isActive => _status != FluidStatus.idle;

	double get opacity {
		if (_status != FluidStatus.settling || fadeOut <= 0) return 1;
		final tail = lifetime - fadeOut;
		if (_settled <= tail) return 1;
		return (1 - (_settled - tail) / fadeOut).clamp(0.0, 1.0);
	}

	void begin(Offset at) {
		_splats.clear();
		_last = at;
		_settled = 0;
		_status = FluidStatus.touching;
		notifyListeners();
	}

	/// Queues a velocity splat; the force follows the travel since the last move.
	void move(Offset at) {
		final delta = at - (_last ?? at);
		_last = at;
		_status = FluidStatus.touching;
		if (delta == Offset.zero) return;
		_splats.add((at, delta));
		notifyListeners();
	}

	void end() {
		if (_status != FluidStatus.touching) return;
		_last = null;
		_settled = 0;
		_status = FluidStatus.settling;
		notifyListeners();
	}

	void reset() {
		_splats.clear();
		_last = null;
		_settled = 0;
		_status = FluidStatus.idle;
		notifyListeners();
	}

	List<(Offset, Offset)> takeSplats() {
		if (_splats.isEmpty) return const [];
		final taken = List<(Offset, Offset)>.of(_splats);
		_splats.clear();
		return taken;
	}

	/// Ages the post-touch clock; false once the effect is over.
	bool advance(double dt) {
		if (_status != FluidStatus.settling) return _status != FluidStatus.idle;
		_settled += dt;
		if (_settled < lifetime) return true;
		reset();
		return false;
	}
}
