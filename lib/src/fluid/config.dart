// @ai-generated(solo)

import 'package:flutter/foundation.dart';

/// Every knob of the fluid solver; defaults are Dobryakov's, see `docs/fluid.md`.
@immutable
final class FluidConfig {
	const FluidConfig({
		this.simResolution = 128,
		this.dyeResolution = 0,
		this.pressureIterations = 20,
		this.pressure = 0.8,
		this.curl = 30,
		this.densityDissipation = 1,
		this.velocityDissipation = 0.2,
		this.splatRadius = 0.25,
		this.splatForce = 6000,
		this.shading = 0,
		this.lifetime = 3,
		this.fadeOut = 1,
		this.spread = 90,
		this.edgeFade = 40,
		this.velocityRange = 512,
		this.curlRange = 256,
		this.divergenceRange = 128,
		this.pressureRange = 128,
		this.floatFields = 0,
	});

	/// Velocity grid, long side in texels.
	final double simResolution;

	/// Dye grid cap, long side in texels; 0 keeps the snapshot's own resolution.
	///
	/// Unlike Dobryakov's 1024, the default is no cap: resampling the seed makes
	/// the card pop the moment it is touched.
	final double dyeResolution;

	/// Jacobi sweeps of the pressure solve; the bulk of the per-frame passes.
	final double pressureIterations;

	/// How much of the previous frame's pressure seeds this one, 0..1.
	final double pressure;

	/// Vorticity confinement strength.
	final double curl;

	/// Dye lost per second.
	final double densityDissipation;

	/// Velocity lost per second.
	final double velocityDissipation;

	/// Gaussian falloff of a splat, in hundredths of the grid's uv.
	final double splatRadius;

	/// Velocity added per unit of finger travel in uv.
	final double splatForce;

	/// Mix of Dobryakov's fake relief; above 0 the card's border picks up a rim.
	final double shading;

	/// Seconds the sim keeps running after the finger lifts.
	final double lifetime;

	/// Seconds of global fade at the end of [lifetime].
	final double fadeOut;

	/// Margin the dye may flow into on every side of the child, logical px.
	final double spread;

	/// Fade band at the canvas border, logical px; the walls trap dye there.
	final double edgeFade;

	/// Half-width of the packed velocity range, grid texels/s.
	final double velocityRange;

	/// Half-width of the packed curl range.
	final double curlRange;

	/// Half-width of the packed divergence range.
	final double divergenceRange;

	/// Half-width of the packed pressure range.
	final double pressureRange;

	/// Above 0.5 the sim fields use rgbaFloat32 targets and no packing at all.
	final double floatFields;

	FluidConfig copyWith({
		double? simResolution,
		double? dyeResolution,
		double? pressureIterations,
		double? pressure,
		double? curl,
		double? densityDissipation,
		double? velocityDissipation,
		double? splatRadius,
		double? splatForce,
		double? shading,
		double? lifetime,
		double? fadeOut,
		double? spread,
		double? edgeFade,
		double? velocityRange,
		double? curlRange,
		double? divergenceRange,
		double? pressureRange,
		double? floatFields,
	}) => FluidConfig(
		simResolution: simResolution ?? this.simResolution,
		dyeResolution: dyeResolution ?? this.dyeResolution,
		pressureIterations: pressureIterations ?? this.pressureIterations,
		pressure: pressure ?? this.pressure,
		curl: curl ?? this.curl,
		densityDissipation: densityDissipation ?? this.densityDissipation,
		velocityDissipation: velocityDissipation ?? this.velocityDissipation,
		splatRadius: splatRadius ?? this.splatRadius,
		splatForce: splatForce ?? this.splatForce,
		shading: shading ?? this.shading,
		lifetime: lifetime ?? this.lifetime,
		fadeOut: fadeOut ?? this.fadeOut,
		spread: spread ?? this.spread,
		edgeFade: edgeFade ?? this.edgeFade,
		velocityRange: velocityRange ?? this.velocityRange,
		curlRange: curlRange ?? this.curlRange,
		divergenceRange: divergenceRange ?? this.divergenceRange,
		pressureRange: pressureRange ?? this.pressureRange,
		floatFields: floatFields ?? this.floatFields,
	);

	@override
	bool operator ==(Object other) =>
		other is FluidConfig &&
		other.simResolution == simResolution &&
		other.dyeResolution == dyeResolution &&
		other.pressureIterations == pressureIterations &&
		other.pressure == pressure &&
		other.curl == curl &&
		other.densityDissipation == densityDissipation &&
		other.velocityDissipation == velocityDissipation &&
		other.splatRadius == splatRadius &&
		other.splatForce == splatForce &&
		other.shading == shading &&
		other.lifetime == lifetime &&
		other.fadeOut == fadeOut &&
		other.spread == spread &&
		other.edgeFade == edgeFade &&
		other.velocityRange == velocityRange &&
		other.curlRange == curlRange &&
		other.divergenceRange == divergenceRange &&
		other.pressureRange == pressureRange &&
		other.floatFields == floatFields;

	@override
	int get hashCode => Object.hash(
		simResolution,
		dyeResolution,
		pressureIterations,
		pressure,
		curl,
		densityDissipation,
		velocityDissipation,
		splatRadius,
		splatForce,
		shading,
		lifetime,
		fadeOut,
		spread,
		edgeFade,
		Object.hash(velocityRange, curlRange, divergenceRange, pressureRange, floatFields),
	);
}
