// @ai-generated(guided)

import 'dart:math' as math;
import 'dart:ui';

import 'material.dart';

/// A ripple source in logical pixels of the [LiquidGlass] frame.
final class GlassTouch {
	GlassTouch({required this.position, DateTime? startedAt, this.amplitude = 3})
		: startedAt = startedAt ?? DateTime.now();

	final Offset position;
	final DateTime startedAt;
	/// Peak height in logical pixels.
	final double amplitude;

	double ageAt(DateTime now) => now.difference(startedAt).inMicroseconds / 1e6;

	/// False once the ring is below a tenth of a pixel anywhere.
	bool isAliveAt(DateTime now, GlassWave wave) =>
		amplitude * math.exp(-ageAt(now) / wave.lifetime) > 0.1;
}
