// @ai-generated(solo)

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'config.dart';
import 'trail.dart';

enum DisintegrationStatus { idle, dragging, settling, dismissed }

/// Owns the progress of one effect; the gesture feeds it, a spring finishes it.
class DisintegrationController extends ChangeNotifier {
	DisintegrationController({
		required TickerProvider vsync,
		DisintegrationMode mode = DisintegrationMode.shards,
		SpringDescription? spring,
		ErodeTrail? trail,
	}) : _mode = mode,
		 _spring = spring ?? SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1),
		 trail = trail ?? ErodeTrail() {
		_anim = AnimationController.unbounded(vsync: vsync)..addListener(_tick);
		_trailTicker = vsync.createTicker(_ageTrail);
	}

	/// The destroying stroke of erode mode, in the child's own coordinates.
	final ErodeTrail trail;

	final SpringDescription _spring;
	late final AnimationController _anim;
	late final Ticker _trailTicker;

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
	bool get isActive => _status != DisintegrationStatus.idle || _progress > 0 || !trail.isEmpty;

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
		if (_mode == DisintegrationMode.erode) {
			trail.start(origin);
			_trailTicker.start();
		}
		notifyListeners();
	}

	/// Feeds the destroying stroke; erode mode only, and it leaves [progress] alone.
	void erode(Offset at) {
		trail.drag(at);
		final direction = trail.points.isEmpty ? Offset.zero : trail.points.last.direction;
		if (direction != Offset.zero) _direction = direction;
		_status = DisintegrationStatus.dragging;
		if (!_trailTicker.isActive) _trailTicker.start();
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
		_trailTicker.stop();
		_generation++;
		trail.clear();
		_progress = 0;
		_status = DisintegrationStatus.idle;
		notifyListeners();
	}

	void _run(double target, double velocity) {
		trail.end();
		// Springing back means the scratch never counted: heal rather than hold the holes.
		if (target <= 0) {
			trail.clear();
			_trailTicker.stop();
		}
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

	// A still finger emits no points, but its hole must keep widening.
	void _ageTrail(Duration _) {
		if (trail.isEmpty || _status == DisintegrationStatus.dismissed) {
			_trailTicker.stop();
			return;
		}
		notifyListeners();
	}

	static Offset _unit(Offset v) {
		final d = v.distance;
		return d > 1e-3 ? v / d : const Offset(1, 0);
	}

	@override
	void dispose() {
		_trailTicker.dispose();
		_anim.dispose();
		super.dispose();
	}
}
