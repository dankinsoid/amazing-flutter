// @ai-generated(solo)

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
	double _opacity = 1;
	bool _frozen = false;

	/// Seconds the scene keeps running after the last finger lifts; set from the config.
	double lifetime = 3;

	/// Seconds of global fade at the end of [lifetime].
	double fadeOut = 1;

	/// Passes the solver recorded in the last frame; reported by the scene.
	int passes = 0;

	/// `ui.Image`s the solver holds; reported by the scene.
	int liveImages = 0;

	FluidSceneStatus get status => _status;
	bool get isActive => _status != FluidSceneStatus.idle;

	/// Seconds since the last finger lifted; it does not run while one is down.
	double get settled => _settled;

	/// Debug hold: the sim keeps stepping but the clock never reaches [lifetime].
	bool get isFrozen => _frozen;

	/// The last-resort layer fade; the dye is already all but gone when it moves.
	double get opacity => _opacity;

	/// Share of [fadeOut] over which [opacity] does the guaranteeing, once the
	/// field's own dissipation has taken the dye down to a few per cent.
	static const _guarantee = 0.3;

	/// 0 while the dye must persist, 1 at the end of the tail; drives the dissipation.
	double get settle {
		if (_status != FluidSceneStatus.settling || fadeOut <= 0) return 0;
		final tail = lifetime - fadeOut;
		if (_settled <= tail) return 0;
		return ((_settled - tail) / fadeOut).clamp(0.0, 1.0);
	}

	double get _targetOpacity => (1 - (settle - (1 - _guarantee)) / _guarantee).clamp(0.0, 1.0);

	/// A fresh stamp restarts the clock; the new dye gets a full lifetime.
	void wake() {
		_settled = 0;
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
		_opacity = 1;
		_status = FluidSceneStatus.idle;
		notifyListeners();
	}

	List<(Offset, Offset)> takeSplats() {
		if (_splats.isEmpty) return const [];
		final taken = List<(Offset, Offset)>.of(_splats);
		_splats.clear();
		return taken;
	}

	/// Walks scripted strokes and ages the clock; false once the scene is over.
	bool advance(double dt) {
		_stepStrokes(dt);
		if (!_frozen && _status == FluidSceneStatus.settling) _settled += dt;
		_slewOpacity(dt);
		if (_frozen || _status != FluidSceneStatus.settling) return _status != FluidSceneStatus.idle;
		if (_settled < lifetime) return true;
		reset();
		return false;
	}

	// The fade's own slope is the limit, so fading is exact and recovery mirrors it.
	void _slewOpacity(double dt) {
		final step = fadeOut > 0 ? dt / (fadeOut * _guarantee) : 1.0;
		_opacity = (_opacity + (_targetOpacity - _opacity).clamp(-step, step)).clamp(0.0, 1.0);
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
