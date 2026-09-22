// @ai-generated(solo)

import 'dart:math' as math;

import 'package:flutter/physics.dart';

enum HoloPattern { classic, reverse, galaxy }

enum HoloMask { card, luminance, alpha }

/// Every knob of `shaders/holo.frag` plus the tilt and the input filters.
class HoloConfig {
	const HoloConfig({
		this.pattern = HoloPattern.classic,
		this.mask = HoloMask.luminance,
		this.foil = 0.85,
		this.glare = 0.55,
		this.grain = 0.25,
		this.bandScale = 0.2,
		this.radius = 18,
		this.seed = 0,
		this.maxAngle = 12 * math.pi / 180,
		this.perspective = 1 / 600,
		SpringDescription? followSpring,
		SpringDescription? returnSpring,
		this.sensorRange = 20 * math.pi / 180,
		this.sensorMinCutoff = 1.0,
		this.sensorBeta = 0.05,
		this.sensorRestTau = 3.0,
	}) : _followSpring = followSpring,
		 _returnSpring = returnSpring;

	final HoloPattern pattern;
	final HoloMask mask;

	final double foil;
	final double glare;
	final double grain;

	/// Colour periods across the card; ~0.2 is a quarter sweep, matching the site — never a
	/// visible repeat.
	final double bandScale;

	/// Corner radius in logical px; the shader clips it, the child need not.
	final double radius;

	final double seed;

	/// Rotation at |tilt| = 1, rad; 0 leaves the card flat and only the foil reacts.
	final double maxAngle;

	/// Matrix entry (3, 2); the CSS reference uses a 600 px perspective.
	final double perspective;

	final SpringDescription? _followSpring;
	final SpringDescription? _returnSpring;

	/// Follows the pointer; stiff enough that the card does not lag behind it.
	SpringDescription get followSpring =>
		_followSpring ?? SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 1);

	/// The release: soft and slow, the way the reference drops its stiffness on leave.
	SpringDescription get returnSpring =>
		_returnSpring ?? SpringDescription.withDampingRatio(mass: 1, stiffness: 34, ratio: 0.55);

	/// Device tilt that maps to |tilt| = 1, rad.
	final double sensorRange;

	/// One Euro: cutoff at rest, Hz. Lower is smoother and laggier.
	final double sensorMinCutoff;

	/// One Euro: how fast the cutoff opens with speed.
	final double sensorBeta;

	/// Seconds over which the rest pose follows the device, so any hold reads as flat.
	final double sensorRestTau;

	static const holo = HoloConfig();

	static const reverse = HoloConfig(
		pattern: HoloPattern.reverse,
		mask: HoloMask.luminance,
		foil: 0.95,
		glare: 0.5,
		grain: 0.45,
		bandScale: 0.4,
		seed: 3,
	);

	static const galaxy = HoloConfig(
		pattern: HoloPattern.galaxy,
		mask: HoloMask.luminance,
		foil: 0.8,
		glare: 0.65,
		grain: 0.1,
		bandScale: 0.3,
		seed: 7,
	);

	static HoloConfig of(HoloPattern pattern) => switch (pattern) {
		HoloPattern.classic => holo,
		HoloPattern.reverse => reverse,
		HoloPattern.galaxy => galaxy,
	};

	HoloConfig copyWith({
		HoloPattern? pattern,
		HoloMask? mask,
		double? foil,
		double? glare,
		double? grain,
		double? bandScale,
		double? radius,
		double? seed,
		double? maxAngle,
		double? perspective,
		SpringDescription? followSpring,
		SpringDescription? returnSpring,
		double? sensorRange,
		double? sensorMinCutoff,
		double? sensorBeta,
		double? sensorRestTau,
	}) {
		return HoloConfig(
			pattern: pattern ?? this.pattern,
			mask: mask ?? this.mask,
			foil: foil ?? this.foil,
			glare: glare ?? this.glare,
			grain: grain ?? this.grain,
			bandScale: bandScale ?? this.bandScale,
			radius: radius ?? this.radius,
			seed: seed ?? this.seed,
			maxAngle: maxAngle ?? this.maxAngle,
			perspective: perspective ?? this.perspective,
			followSpring: followSpring ?? _followSpring,
			returnSpring: returnSpring ?? _returnSpring,
			sensorRange: sensorRange ?? this.sensorRange,
			sensorMinCutoff: sensorMinCutoff ?? this.sensorMinCutoff,
			sensorBeta: sensorBeta ?? this.sensorBeta,
			sensorRestTau: sensorRestTau ?? this.sensorRestTau,
		);
	}
}
