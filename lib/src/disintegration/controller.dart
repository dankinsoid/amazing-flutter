// @ai-generated(solo)

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'config.dart';

enum DisintegrationStatus { idle, dragging, settling, dismissed }

/// Owns the progress of one effect; the gesture feeds it, a spring finishes it.
class DisintegrationController extends ChangeNotifier {
	DisintegrationController({
		required TickerProvider vsync,
		DisintegrationMode mode = DisintegrationMode.shards,
		SpringDescription? spring,
	}) : _mode = mode,
		 _spring = spring ?? SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1) {
		_anim = AnimationController.unbounded(vsync: vsync)..addListener(_tick);
	}

	final SpringDescription _spring;
	late final AnimationController _anim;

	DisintegrationMode _mode;
	double _progress = 0;
	Offset _direction = const Offset(1, 0);
	Offset? _origin;
	DisintegrationStatus _status = DisintegrationStatus.idle;
	double _target = 0;
	int _generation = 0;

	DisintegrationMode get mode => _mode;
	double get progress => _progress;
	Offset get direction => _direction;

	/// Finger position in the child's own coordinates; null means its centre.
	Offset? get origin => _origin;

	DisintegrationStatus get status => _status;
	bool get isActive => _status != DisintegrationStatus.idle || _progress > 0;

	set mode(DisintegrationMode value) {
		if (value == _mode) return;
		_mode = value;
		notifyListeners();
	}

	set direction(Offset value) {
		_direction = _unit(value);
		notifyListeners();
	}

	void beginDrag(Offset origin) {
		_anim.stop();
		_generation++;
		_origin = origin;
		_progress = 0;
		_status = DisintegrationStatus.dragging;
		notifyListeners();
	}

	void drag({required Offset direction, required double progress}) {
		_direction = _unit(direction);
		_progress = progress.clamp(0.0, 1.0);
		_status = DisintegrationStatus.dragging;
		notifyListeners();
	}

	/// [velocity] is in progress units per second, signed along [direction].
	void settle({required bool dismiss, double velocity = 0}) {
		_run(dismiss ? 1 : 0, velocity);
	}

	void play({Offset? direction, Offset? origin, double velocity = 1.5}) {
		if (direction != null) _direction = _unit(direction);
		if (origin != null) _origin = origin;
		_run(1, velocity);
	}

	/// Debug entry point: parks progress without a simulation.
	void freeze(double progress) {
		_anim.stop();
		_generation++;
		_progress = progress.clamp(0.0, 1.0);
		_status = _progress <= 0
			? DisintegrationStatus.idle
			: _progress >= 1
				? DisintegrationStatus.dismissed
				: DisintegrationStatus.settling;
		notifyListeners();
	}

	void reset() {
		_anim.stop();
		_generation++;
		_progress = 0;
		_status = DisintegrationStatus.idle;
		notifyListeners();
	}

	void _run(double target, double velocity) {
		_target = target;
		_status = DisintegrationStatus.settling;
		final generation = ++_generation;
		_anim.value = _progress;
		_anim
			.animateWith(SpringSimulation(_spring, _progress, target, velocity))
			.whenComplete(() {
				if (generation != _generation) return;
				_progress = _target;
				_status = _target >= 1 ? DisintegrationStatus.dismissed : DisintegrationStatus.idle;
				notifyListeners();
			});
		notifyListeners();
	}

	void _tick() {
		_progress = _anim.value.clamp(0.0, 1.0);
		notifyListeners();
	}

	static Offset _unit(Offset v) {
		final d = v.distance;
		return d > 1e-3 ? v / d : const Offset(1, 0);
	}

	@override
	void dispose() {
		_anim.dispose();
		super.dispose();
	}
}
