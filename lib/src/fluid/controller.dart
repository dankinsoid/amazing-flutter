// @ai-generated(solo)

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Where one [FluidScene] is in its life; the scene owns the GPU and the clock.
enum FluidSceneStatus { idle, touching, settling }

/// Where one `Fluid` child is; a stamped child is dye, not a widget.
enum FluidStatus { idle, flowing, dismissed }

/// A scripted finger, in scene-local logical px; `play` and debug hooks use it.
class FluidStroke {
	FluidStroke({required this.from, required this.to, this.speed = 900});

	final Offset from;
	final Offset to;

	/// Travel along the path, logical px/s.
	final double speed;

	double _travelled = 0;

	double get _length => (to - from).distance;

	bool get _done => _travelled >= _length;

	Offset get _at => _length <= 0 ? from : Offset.lerp(from, to, _travelled / _length)!;

	/// Walks the finger by [dt] and returns the travel since the last step.
	(Offset, Offset) _step(double dt) {
		final was = _at;
		_travelled = (_travelled + speed * dt).clamp(0.0, _length);
		final at = _at;
		return (at, at - was);
	}
}

/// Input and lifetime of one fluid scene; the scene widget owns the GPU and the clock.
class FluidSceneController extends ChangeNotifier {
	final List<(Offset, Offset)> _splats = <(Offset, Offset)>[];
	final Map<int, Offset> _pointers = <int, Offset>{};
	final List<FluidStroke> _strokes = <FluidStroke>[];

	FluidSceneStatus _status = FluidSceneStatus.idle;
	double _settled = 0;
	double _alpha = 1;
	bool _frozen = false;

	/// Seconds a stamp keeps its body before settling; set from the config.
	double settleDelay = 0.4;

	/// Seconds the settling ramps in over; set from the config.
	double settleRamp = 0.5;

	/// Dissipation applied everywhere once the dye settles, 1/s; set from the config.
	double settleDecay = 1;

	/// Passes the solver recorded in the last frame; reported by the scene.
	int passes = 0;

	/// `ui.Image`s the solver holds; reported by the scene.
	int liveImages = 0;

	FluidSceneStatus get status => _status;
	bool get isActive => _status != FluidSceneStatus.idle;

	/// Seconds since the last stamp; a finger does not pause it, only [freeze] does.
	double get settled => _settled;

	/// Debug hold: the sim keeps stepping and the dye never runs out.
	bool get isFrozen => _frozen;

	/// Upper bound on the dye's peak alpha; the effect ends when it is under 1/255.
	double get alphaBound => _alpha;

	/// 0 while a stamp keeps its body, 1 once it settles; smooth, never a step.
	double get settle {
		if (settleRamp <= 0) return _settled >= settleDelay ? 1 : 0;
		final t = ((_settled - settleDelay) / settleRamp).clamp(0.0, 1.0);
		return t * t * (3 - 2 * t);
	}

	/// A fresh stamp restarts the clock; the new dye gets its own settle delay.
	void wake() {
		_settled = 0;
		_alpha = 1;
		if (_status == FluidSceneStatus.idle) _status = _touching ? FluidSceneStatus.touching : FluidSceneStatus.settling;
		notifyListeners();
	}

	bool get _touching => _pointers.isNotEmpty || _strokes.isNotEmpty;

	void down(int pointer, Offset at) {
		_pointers[pointer] = at;
		_status = FluidSceneStatus.touching;
		notifyListeners();
	}

	/// Queues a velocity splat; the force follows the travel since the last move.
	void moveTo(int pointer, Offset at) {
		final last = _pointers[pointer];
		_pointers[pointer] = at;
		_status = FluidSceneStatus.touching;
		if (last == null || at == last) return;
		_splats.add((at, at - last));
		notifyListeners();
	}

	void up(int pointer) {
		if (_pointers.remove(pointer) == null) return;
		if (!_touching && _status == FluidSceneStatus.touching) _status = FluidSceneStatus.settling;
		notifyListeners();
	}

	/// Runs a synthetic finger along a path; the scene's ticker walks it.
	void stroke(FluidStroke stroke) {
		_strokes.add(stroke);
		_status = FluidSceneStatus.touching;
		notifyListeners();
	}

	/// Debug entry point: parks the settle clock at [seconds] and holds it there.
	void freeze(double seconds) {
		_frozen = true;
		_settled = seconds < 0 ? 0 : seconds;
		if (_status == FluidSceneStatus.idle) _status = FluidSceneStatus.settling;
		notifyListeners();
	}

	void resume() {
		if (!_frozen) return;
		_frozen = false;
		notifyListeners();
	}

	void reset() {
		_splats.clear();
		_pointers.clear();
		_strokes.clear();
		_frozen = false;
		_settled = 0;
		_alpha = 1;
		_status = FluidSceneStatus.idle;
		notifyListeners();
	}

	List<(Offset, Offset)> takeSplats() {
		if (_splats.isEmpty) return const [];
		final taken = List<(Offset, Offset)>.of(_splats);
		_splats.clear();
		return taken;
	}

	/// Walks scripted strokes and ages the dye; false once nothing visible is left.
	///
	/// A finger stirs the dye as it goes; it does not hold the dye alive. The bound
	/// mirrors the two decays the shader applies everywhere and ignores the flow's
	/// own, so the real dye is never above it.
	bool advance(double dt) {
		_stepStrokes(dt);
		if (_frozen || _status == FluidSceneStatus.idle) return _status != FluidSceneStatus.idle;
		_settled += dt;
		final settled = settle;
		// The shader takes whichever of the two decays is faster; so must the bound.
		_alpha = math.min(_alpha / (1 + settleDecay * settled * dt), _alpha - settled / 255);
		if (_alpha > 1 / 255) return true;
		reset();
		return false;
	}

	void _stepStrokes(double dt) {
		if (_strokes.isEmpty) return;
		for (final stroke in _strokes) {
			final (at, delta) = stroke._step(dt);
			if (delta != Offset.zero) _splats.add((at, delta));
		}
		_strokes.removeWhere((stroke) => stroke._done);
		if (!_touching && _status == FluidSceneStatus.touching) _status = FluidSceneStatus.settling;
	}
}

/// Handle on one `Fluid` child: stamp it into the scene, or play a stroke over it.
class FluidController extends ChangeNotifier {
	FluidStatus _status = FluidStatus.idle;
	({Offset? direction, Offset? origin, double speed})? _request;
	bool _wantsStamp = false;

	FluidStatus get status => _status;
	bool get isFlowing => _status == FluidStatus.flowing;

	/// Hands the child to the scene as dye right now, with no velocity.
	void stamp() {
		_wantsStamp = true;
		notifyListeners();
	}

	/// Stamps the child and drags a synthetic finger across it, child-local px.
	void play({Offset? direction, Offset? origin, double speed = 900}) {
		_wantsStamp = true;
		_request = (direction: direction, origin: origin, speed: speed);
		notifyListeners();
	}

	void reset() {
		_wantsStamp = false;
		_request = null;
		_status = FluidStatus.idle;
		notifyListeners();
	}

	/// Set by the widget; the scene decides when a child starts flowing and ends.
	void report(FluidStatus status) {
		if (status == _status) return;
		_status = status;
		notifyListeners();
	}

	bool takeStamp() {
		final wanted = _wantsStamp;
		_wantsStamp = false;
		return wanted;
	}

	({Offset? direction, Offset? origin, double speed})? takePlay() {
		final request = _request;
		_request = null;
		return request;
	}
}
