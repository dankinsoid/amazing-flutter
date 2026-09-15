// @ai-generated(solo)

import 'dart:ui';

/// One point of a destroying stroke, in the child's own logical px.
final class ErodePoint {
	ErodePoint({
		required this.position,
		required this.direction,
		DateTime? startedAt,
		this.speed = 0,
		this.strength = 1,
	}) : startedAt = startedAt ?? DateTime.now();

	final Offset position;

	/// Unit stroke direction here; zero where the stroke had not moved yet.
	final Offset direction;

	final DateTime startedAt;

	/// Stroke speed here, px/s; what turns a fast swipe into a push.
	final double speed;

	/// Tapers to 0 over the oldest slots so eviction does not pop.
	final double strength;

	double ageAt(DateTime now) => now.difference(startedAt).inMicroseconds / 1e6;

	ErodePoint withStrength(double value) => ErodePoint(
		position: position,
		direction: direction,
		startedAt: startedAt,
		speed: speed,
		strength: value,
	);
}

/// Turns a pan into the stroke the erode mode eats along, one point per [spacing].
final class ErodeTrail {
	ErodeTrail({this.spacing = 14, this.capacity = 32, this.fadeCount = 5});

	/// Travel between points; under the hole radius, or the band reads as beads.
	double spacing;

	/// Matches `MAX_TRAIL` in the shader; older points are evicted.
	final int capacity;

	/// How many of the oldest points taper off before eviction.
	final int fadeCount;

	final List<ErodePoint> _points = [];
	Offset? _last;
	DateTime? _lastAt;
	double _length = 0;

	bool get isEmpty => _points.isEmpty;

	/// Total travel of the stroke, not its net displacement.
	double get length => _length;

	/// Oldest first, oldest tapered.
	List<ErodePoint> get points {
		final n = _points.length;
		return [
			for (var i = 0; i < n; i++)
				if (capacity - n + i >= fadeCount)
					_points[i]
				else
					_points[i].withStrength(_points[i].strength * (capacity - n + i) / fadeCount),
		];
	}

	void start(Offset at) {
		_last = at;
		_lastAt = DateTime.now();
		_add(ErodePoint(position: at, direction: Offset.zero, startedAt: _lastAt));
	}

	void drag(Offset at) {
		final now = DateTime.now();
		final last = _last;
		if (last == null) {
			start(at);
			return;
		}
		final delta = at - last;
		final travel = delta.distance;
		if (travel < spacing) return;
		final direction = delta / travel;
		final steps = travel ~/ spacing;
		final lastAt = _lastAt ?? now;
		final elapsed = now.difference(lastAt).inMicroseconds / 1e6;
		final speed = elapsed > 1e-4 ? travel / elapsed : 0.0;
		for (var i = 1; i <= steps; i++) {
			final f = i * spacing / travel;
			// Timestamps interpolate, or a fast stroke lands as one age.
			final t = lastAt.add(Duration(microseconds: (now.difference(lastAt).inMicroseconds * f).round()));
			_add(ErodePoint(position: last + delta * f, direction: direction, startedAt: t, speed: speed));
		}
		_length += steps * spacing;
		_last = last + delta * (steps * spacing / travel);
		_lastAt = now;
	}

	void end() {
		_last = null;
		_lastAt = null;
	}

	void clear() {
		_points.clear();
		_length = 0;
		end();
	}

	void _add(ErodePoint point) {
		if (_points.length >= capacity) _points.removeAt(0);
		_points.add(point);
	}
}
