// @ai-generated(guided)

import 'dart:math' as math;
import 'dart:ui';

import 'material.dart';

/// A ripple source in logical pixels of the [LiquidGlass] frame.
///
/// A tap is a point; a stroke is the segment [start]→[end] swept between
/// [startedAt] and [endedAt], so the wave is youngest at the finger.
final class GlassTouch {
	GlassTouch({
		required this.start,
		Offset? end,
		DateTime? startedAt,
		DateTime? endedAt,
		this.amplitude = 3,
	})	: end = end ?? start,
			startedAt = startedAt ?? DateTime.now(),
			endedAt = endedAt ?? startedAt ?? DateTime.now();

	final Offset start;
	final Offset end;
	final DateTime startedAt;
	final DateTime endedAt;
	/// Peak height in logical pixels.
	final double amplitude;

	/// The same stroke continued to [to] at the present moment.
	GlassTouch extendTo(Offset to) => GlassTouch(
		start: start,
		end: to,
		startedAt: startedAt,
		endedAt: DateTime.now(),
		amplitude: amplitude,
	);

	/// False once the newest part of the source is below a tenth of a pixel.
	bool isAliveAt(DateTime now, GlassWave wave) =>
		amplitude * math.exp(-now.difference(endedAt).inMicroseconds / 1e6 / wave.lifetime) > 0.1;
}
