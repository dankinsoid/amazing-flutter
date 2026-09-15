// @ai-generated(solo)

import 'package:flutter/foundation.dart';

/// Which field and threshold the shader builds; the index is the `uMode` value.
enum DisintegrationMode { shards, smoke, blowAway, erode }

/// Every knob of `shaders/disintegration.frag`, in logical px and seconds.
@immutable
final class DisintegrationConfig {
	const DisintegrationConfig({
		this.cellSize = 1,
		this.drift = 70,
		this.lift = 26,
		this.jitter = 14,
		this.spin = 1.6,
		this.shrink = 0.5,
		this.noiseScale = 0.02,
		this.turbulence = 110,
		this.radial = 0.75,
		this.erodeRadius = 16,
		this.erodeSpread = 150,
		this.erodeExpand = 10,
		this.erodeSwirl = 30,
		this.erodeVortex = 40,
		this.erodeLifetime = 1.6,
		this.trailSpacing = 10,
		this.softness = 0.3,
		this.sweep = 0.6,
		this.blur = 0,
		this.fade = 0.45,
		this.spread = 140,
		this.edgeFade = 40,
		this.seed = 1,
		this.dismissDistance = 160,
		this.flingVelocity = 700,
	});

	/// Shards and blow-away: grid cell edge before the lattice is warped; 1 is pixel dust.
	final double cellSize;

	/// Smooth displacement at full departure.
	final double drift;

	/// Upward bias added to [drift].
	final double lift;

	/// Per-shard displacement on top of [drift].
	final double jitter;

	/// Per-shard rotation at full departure, radians.
	final double spin;

	/// Shard size lost at full departure, 0..1.
	final double shrink;

	/// Reciprocal noise feature size, 1/px.
	final double noiseScale;

	/// Smoke: noise-driven displacement.
	final double turbulence;

	/// Blow-away: radial vs swipe direction in the flow, 0..1.
	final double radial;

	/// Erode: disturbance radius under a fresh stroke point.
	final double erodeRadius;

	/// Erode: radius the front gains per second; sets how fast the touch reaches the corners.
	final double erodeSpread;

	/// Erode: outward drift away from each stroke point.
	final double erodeExpand;

	/// Erode: curl-noise eddies inside the eaten band.
	final double erodeSwirl;

	/// Erode: swirl around the finger, fading once it leaves.
	final double erodeVortex;

	/// Erode: disturbance-seconds over which the smoke thins to nothing.
	final double erodeLifetime;

	/// Erode: stroke travel between trail points; under [erodeRadius], or the band beads.
	final double trailSpacing;

	/// Dissolve edge width, in progress units.
	final double softness;

	/// 0 dissolves everywhere at once, 1 strictly front to back.
	final double sweep;

	/// Smoke: blur radius at full departure; 0 keeps a single read.
	final double blur;

	/// Alpha exponent while departing.
	final double fade;

	/// Margin the effect may paint into on every side of the child.
	final double spread;

	/// Fade band at the canvas border, where the painter clips.
	final double edgeFade;

	/// Shifts every hash; two cards with the same seed dissolve alike.
	final double seed;

	/// Drag distance that takes progress from 0 to 1.
	final double dismissDistance;

	/// Release speed that dismisses; below it the card springs back.
	final double flingVelocity;

	static const shards = DisintegrationConfig();

	static const smoke = DisintegrationConfig(
		drift: 90,
		lift: 60,
		jitter: 0,
		spin: 0,
		noiseScale: 0.03,
		turbulence: 140,
		softness: 0.22,
		sweep: 0.65,
		blur: 12,
		fade: 0.7,
	);

	static const erode = DisintegrationConfig(
		noiseScale: 0.03,
		blur: 16,
		fade: 1,
		spread: 200,
		dismissDistance: 140,
	);

	static const blowAway = DisintegrationConfig(
		cellSize: 11,
		seed: 1,
		drift: 150,
		lift: 10,
		jitter: 10,
		spin: 2.4,
		shrink: 0.6,
		turbulence: 80,
		sweep: 0.7,
		fade: 0.45,
		spread: 180,
	);

	static DisintegrationConfig of(DisintegrationMode mode) => switch (mode) {
		DisintegrationMode.shards => shards,
		DisintegrationMode.smoke => smoke,
		DisintegrationMode.blowAway => blowAway,
		DisintegrationMode.erode => erode,
	};

	DisintegrationConfig copyWith({
		double? cellSize,
		double? drift,
		double? lift,
		double? jitter,
		double? spin,
		double? shrink,
		double? noiseScale,
		double? turbulence,
		double? radial,
		double? erodeRadius,
		double? erodeSpread,
		double? erodeExpand,
		double? erodeSwirl,
		double? erodeVortex,
		double? erodeLifetime,
		double? trailSpacing,
		double? softness,
		double? sweep,
		double? blur,
		double? fade,
		double? spread,
		double? edgeFade,
		double? seed,
		double? dismissDistance,
		double? flingVelocity,
	}) => DisintegrationConfig(
		cellSize: cellSize ?? this.cellSize,
		drift: drift ?? this.drift,
		lift: lift ?? this.lift,
		jitter: jitter ?? this.jitter,
		spin: spin ?? this.spin,
		shrink: shrink ?? this.shrink,
		noiseScale: noiseScale ?? this.noiseScale,
		turbulence: turbulence ?? this.turbulence,
		radial: radial ?? this.radial,
		erodeRadius: erodeRadius ?? this.erodeRadius,
		erodeSpread: erodeSpread ?? this.erodeSpread,
		erodeExpand: erodeExpand ?? this.erodeExpand,
		erodeSwirl: erodeSwirl ?? this.erodeSwirl,
		erodeVortex: erodeVortex ?? this.erodeVortex,
		erodeLifetime: erodeLifetime ?? this.erodeLifetime,
		trailSpacing: trailSpacing ?? this.trailSpacing,
		softness: softness ?? this.softness,
		sweep: sweep ?? this.sweep,
		blur: blur ?? this.blur,
		fade: fade ?? this.fade,
		spread: spread ?? this.spread,
		edgeFade: edgeFade ?? this.edgeFade,
		seed: seed ?? this.seed,
		dismissDistance: dismissDistance ?? this.dismissDistance,
		flingVelocity: flingVelocity ?? this.flingVelocity,
	);
}
