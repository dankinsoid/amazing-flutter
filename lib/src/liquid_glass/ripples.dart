// @ai-generated(guided)

import 'dart:ui';

import 'material.dart';
import 'touch.dart';

/// Turns pointer events into the source trail [LiquidGlass] sums.
///
/// A moving finger emits one source per [spacing] of travel, so a still
/// finger emits nothing and the rings superpose into a smooth front.
final class GlassRipples {
	GlassRipples({
		this.wave = const GlassWave(),
		this.capacity = 32,
		this.tapAmplitude = 3,
		this.strokeAmplitude = 1.2,
		this.fadeCount = 6,
	});

	final GlassWave wave;
	/// Matches `MAX_TOUCHES` in the shader; older sources are evicted.
	final int capacity;
	final double tapAmplitude;
	/// Per source; ~2.5 sources add up coherently across a front.
	final double strokeAmplitude;
	/// How many of the oldest sources taper off before eviction, so the tail never pops.
	final int fadeCount;

	final List<GlassTouch> _sources = [];
	Offset? _last;
	DateTime? _lastAt;

	/// Under half a wavelength, or the rings alias into a grating.
	double get spacing => wave.wavelength * 0.4;

	void tap(Offset at) {
		_prune();
		_add(GlassTouch(position: at, amplitude: tapAmplitude));
	}

	void drag(Offset at) {
		_prune();
		final now = DateTime.now();
		final last = _last;
		if (last == null) {
			_add(GlassTouch(position: at, startedAt: now, amplitude: strokeAmplitude));
		} else {
			final delta = at - last;
			final steps = delta.distance ~/ spacing;
			final lastAt = _lastAt ?? now;
			for (var i = 1; i <= steps; i++) {
				final f = i * spacing / delta.distance;
				final t = lastAt.add(Duration(microseconds: (now.difference(lastAt).inMicroseconds * f).round()));
				_add(GlassTouch(position: last + delta * f, startedAt: t, amplitude: strokeAmplitude));
			}
			if (steps == 0) return;
			at = last + delta * (steps * spacing / delta.distance);
		}
		_last = at;
		_lastAt = now;
	}

	void end() {
		_last = null;
		_lastAt = null;
	}

	/// Newest last, oldest tapered; pass straight to [LiquidGlass.touches].
	List<GlassTouch> get touches {
		_prune();
		final n = _sources.length;
		return [
			for (var i = 0; i < n; i++)
				if (capacity - n + i >= fadeCount)
					_sources[i]
				else
					_sources[i].withAmplitude(_sources[i].amplitude * (capacity - n + i) / fadeCount),
		];
	}

	bool get isEmpty => _sources.isEmpty;

	void _add(GlassTouch source) {
		if (_sources.length >= capacity) _sources.removeAt(0);
		_sources.add(source);
	}

	void _prune() {
		final now = DateTime.now();
		_sources.removeWhere((t) => !t.isAliveAt(now, wave));
	}
}
