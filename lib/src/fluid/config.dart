// @ai-generated(solo)

import 'package:flutter/foundation.dart';

/// Named looks of the solver; the index carries no meaning to the shaders.
enum FluidPreset { smoke, ink, honey }

/// Every knob of the fluid scene, in logical px and seconds; see `docs/fluid.md`.
@immutable
final class FluidConfig {
	const FluidConfig({
		this.simResolution = 256,
		this.dyeResolution = 0,
		this.pressureIterations = 20,
		this.pressure = 0.8,
		this.curl = 30,
		this.densityDissipation = 1.1,
		this.velocityDissipation = 0.2,
		this.dissipationSpeed = 200,
		this.greying = 0.35,
		this.splatRadius = 20,
		this.splatForce = 10,
		this.shading = 0,
		this.lifetime = 3,
		this.fadeOut = 1,
		this.fadeDecay = 12,
		this.edgeFade = 40,
		this.velocityRange = 512,
		this.curlRange = 256,
		this.divergenceRange = 128,
		this.pressureRange = 128,
		this.floatFields = 1,
	});

	/// Velocity grid, long side of the scene in texels.
	final double simResolution;

	/// Dye grid cap, long side in texels; 0 keeps the scene's device resolution.
	final double dyeResolution;

	/// Jacobi sweeps of the pressure solve; the bulk of the per-frame passes.
	final double pressureIterations;

	/// How much of the previous frame's pressure seeds this one, 0..1.
	final double pressure;

	/// Vorticity confinement strength.
	final double curl;

	/// Dye lost per second where the flow is at [dissipationSpeed] or faster.
	final double densityDissipation;

	/// Velocity lost per second; the solver's stand-in for viscosity.
	final double velocityDissipation;

	/// Flow speed of full dye decay, logical px/s; still dye never fades.
	final double dissipationSpeed;

	/// How far decaying dye is pulled to its own luminance, 0..1; 0 keeps the colour.
	final double greying;

	/// Radius where a splat's velocity falls to 1/e, logical px.
	final double splatRadius;

	/// Flow speed gained per px of finger travel, 1/s; see `docs/fluid.md` §2.
	final double splatForce;

	/// Mix of Dobryakov's fake relief; above 0 a dye border picks up a rim.
	final double shading;

	/// Seconds the scene keeps running after the last finger lifts.
	final double lifetime;

	/// Seconds of global fade at the end of [lifetime].
	final double fadeOut;

	/// Dissipation added everywhere at the end of [fadeOut], 1/s; what ends the dye.
	final double fadeDecay;

	/// Fade band at the scene border, logical px; the walls trap dye there.
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

	/// Thins fast and rolls hard; a card is gone within its lifetime.
	static const smoke = FluidConfig(densityDissipation: 1.6, curl: 36, dissipationSpeed: 160, greying: 0.6);

	/// Keeps its colour: slow decay, low drag, long filaments.
	static const ink = FluidConfig(
		densityDissipation: 0.45,
		curl: 44,
		velocityDissipation: 0.1,
		dissipationSpeed: 280,
		greying: 0,
		lifetime: 4,
	);

	/// Viscous: motion dies quickly, so the card sags rather than explodes.
	static const honey = FluidConfig(
		densityDissipation: 0.7,
		curl: 5,
		velocityDissipation: 2.2,
		dissipationSpeed: 110,
		greying: 0.2,
		splatForce: 7,
		lifetime: 3.5,
	);

	static FluidConfig of(FluidPreset preset) => switch (preset) {
		FluidPreset.smoke => smoke,
		FluidPreset.ink => ink,
		FluidPreset.honey => honey,
	};

	FluidConfig copyWith({
		double? simResolution,
		double? dyeResolution,
		double? pressureIterations,
		double? pressure,
		double? curl,
		double? densityDissipation,
		double? velocityDissipation,
		double? dissipationSpeed,
		double? greying,
		double? splatRadius,
		double? splatForce,
		double? shading,
		double? lifetime,
		double? fadeOut,
		double? fadeDecay,
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
		dissipationSpeed: dissipationSpeed ?? this.dissipationSpeed,
		greying: greying ?? this.greying,
		splatRadius: splatRadius ?? this.splatRadius,
		splatForce: splatForce ?? this.splatForce,
		shading: shading ?? this.shading,
		lifetime: lifetime ?? this.lifetime,
		fadeOut: fadeOut ?? this.fadeOut,
		fadeDecay: fadeDecay ?? this.fadeDecay,
		edgeFade: edgeFade ?? this.edgeFade,
		velocityRange: velocityRange ?? this.velocityRange,
		curlRange: curlRange ?? this.curlRange,
		divergenceRange: divergenceRange ?? this.divergenceRange,
		pressureRange: pressureRange ?? this.pressureRange,
		floatFields: floatFields ?? this.floatFields,
	);

	/// Grid sizes are read once per effect; changing them mid-flow needs a restart.
	bool sameGrid(FluidConfig other) =>
		other.simResolution == simResolution &&
		other.dyeResolution == dyeResolution &&
		other.floatFields == floatFields;

	List<Object> get _fields => [
		simResolution,
		dyeResolution,
		pressureIterations,
		pressure,
		curl,
		densityDissipation,
		velocityDissipation,
		dissipationSpeed,
		greying,
		splatRadius,
		splatForce,
		shading,
		lifetime,
		fadeOut,
		fadeDecay,
		edgeFade,
		velocityRange,
		curlRange,
		divergenceRange,
		pressureRange,
		floatFields,
	];

	@override
	bool operator ==(Object other) =>
		other is FluidConfig && listEquals(other._fields, _fields);

	@override
	int get hashCode => Object.hashAll(_fields);
}
