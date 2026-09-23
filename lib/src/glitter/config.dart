// @ai-generated(solo)

import 'dart:math' as math;
import 'dart:ui' show Color;

/// Every knob of `shaders/glitter.frag` plus the light and the input filters.
class GlitterConfig {
	const GlitterConfig({
		this.base = const Color(0xFFE8A0C0),
		this.flakeScale = 1,
		this.density = 1,
		this.gain = 1,
		this.rainbow = 1,
		this.grain = 1,
		this.seed = 0,
		this.sensorRange = 50 * math.pi / 180,
		this.sensorMinCutoff = 1.6,
		this.sensorBeta = 0.08,
		this.restAgitation = 0.5,
		this.idleDrift = 0.06,
		this.movingDrift = 0.39,
	});

	/// The tone the flakes sit in; the shader dusts it rather than replacing it.
	final Color base;

	/// Flake cell size, 1 = the reference dust of ~2 logical px.
	final double flakeScale;

	/// Multiplies how many cells hold a flake; above ~1.5 the layers merge into a sheen.
	final double density;

	/// Flash brightness; SDR clips it at white, with no headroom to spill into.
	final double gain;

	/// Iridescence; 0 leaves every flake warm white.
	final double rainbow;

	/// Micro-grain over the base, fading out at both ends of the luminance range.
	final double grain;

	final double seed;

	/// Device tilt that maps to |light| = 1, rad.
	final double sensorRange;

	/// One Euro: cutoff at rest, Hz. Lower is smoother and laggier.
	final double sensorMinCutoff;

	/// One Euro: how fast the cutoff opens with speed.
	final double sensorBeta;

	/// Agitation held with no input at all; a simulator has no sensor to wake it.
	final double restAgitation;

	/// How far the light drifts on its own at rest, in tilt units. Against the
	/// narrow lobes even this much keeps a resting surface alive.
	final double idleDrift;

	/// Extra drift at full agitation; the hand already sweeps the light by then.
	final double movingDrift;

	static const pink = GlitterConfig();

	static const champagne = GlitterConfig(base: Color(0xFFD8C39A), rainbow: 0.6, seed: 3);

	static const charcoal = GlitterConfig(base: Color(0xFF1C1C22), gain: 1.2, seed: 7);

	GlitterConfig copyWith({
		Color? base,
		double? flakeScale,
		double? density,
		double? gain,
		double? rainbow,
		double? grain,
		double? seed,
		double? sensorRange,
		double? sensorMinCutoff,
		double? sensorBeta,
		double? restAgitation,
		double? idleDrift,
		double? movingDrift,
	}) {
		return GlitterConfig(
			base: base ?? this.base,
			flakeScale: flakeScale ?? this.flakeScale,
			density: density ?? this.density,
			gain: gain ?? this.gain,
			rainbow: rainbow ?? this.rainbow,
			grain: grain ?? this.grain,
			seed: seed ?? this.seed,
			sensorRange: sensorRange ?? this.sensorRange,
			sensorMinCutoff: sensorMinCutoff ?? this.sensorMinCutoff,
			sensorBeta: sensorBeta ?? this.sensorBeta,
			restAgitation: restAgitation ?? this.restAgitation,
			idleDrift: idleDrift ?? this.idleDrift,
			movingDrift: movingDrift ?? this.movingDrift,
		);
	}
}
