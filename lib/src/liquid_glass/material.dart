// @ai-generated(guided)

import 'dart:math' as math;
import 'dart:ui';

/// Ripple parameters shared by every touch, in logical pixels and seconds.
final class GlassWave {
	const GlassWave({
		this.wavelength = 28,
		this.frequency = 3,
		this.reach = 220,
		this.lifetime = 1.4,
	});

	final double wavelength;
	final double frequency;
	/// Spreading scale: amplitude halves once the front has travelled 3× this.
	final double reach;
	/// Time over which the amplitude falls by `e`.
	final double lifetime;

	double get k => 2 * math.pi / wavelength;
	double get omega => 2 * math.pi * frequency;

	GlassWave copyWith({double? wavelength, double? frequency, double? reach, double? lifetime}) => GlassWave(
		wavelength: wavelength ?? this.wavelength,
		frequency: frequency ?? this.frequency,
		reach: reach ?? this.reach,
		lifetime: lifetime ?? this.lifetime,
	);
}

/// Everything the shader needs beyond geometry, in logical pixels.
final class GlassMaterial {
	const GlassMaterial({
		this.smoothK = 24,
		this.edgeWidth = 28,
		this.height = 10,
		this.thickness = 36,
		this.aberration = 0.15,
		this.tint = const Color(0xFFFFFFFF),
		this.tintStrength = 0.08,
		this.saturation = 1.25,
		this.specular = 0.6,
		this.shininess = 40,
		this.rim = 0.6,
		this.rimWidth = 6,
		this.fresnel = 0.25,
		this.innerShadow = 0.15,
		this.shadow = 0,
		this.floorScale = 1,
		this.caustic = 0,
		this.contentStrength = 0.6,
		this.rippleStrength = 1,
		this.frostSigma = 0,
		this.wave = const GlassWave(),
	});

	/// Smooth-union radius between shapes.
	final double smoothK;
	/// Width of the squircle ramp from the edge inward.
	final double edgeWidth;
	/// Profile amplitude; sets the normal slope independently of [thickness].
	final double height;
	/// Refraction offset at unit slope.
	final double thickness;
	/// Per-channel offset spread; 0 disables the extra reads.
	final double aberration;
	final Color tint;
	final double tintStrength;
	final double saturation;
	final double specular;
	final double shininess;
	/// Light-facing edge highlight; 0 disables it.
	final double rim;
	/// Edge band for rim light and inner shadow.
	final double rimWidth;
	final double fresnel;
	final double innerShadow;
	/// Cast shadow past the far edge and the dark seam inside the near edge.
	final double shadow;
	/// Multiplies the physical shadow length `height / tan(elevation)`; 1 = as ray-traced.
	final double floorScale;
	/// Bright focus band inside the near edge, right after the dark seam.
	final double caustic;
	/// Content displacement per pixel of water envelope.
	final double contentStrength;
	/// Multiplies every touch amplitude; 0 turns the water off.
	final double rippleStrength;
	/// Backdrop blur; applied by the engine, never reaches the shader.
	final double frostSigma;
	final GlassWave wave;

	GlassMaterial copyWith({
		double? smoothK,
		double? edgeWidth,
		double? height,
		double? thickness,
		double? aberration,
		Color? tint,
		double? tintStrength,
		double? saturation,
		double? specular,
		double? shininess,
		double? rim,
		double? rimWidth,
		double? fresnel,
		double? innerShadow,
		double? shadow,
		double? floorScale,
		double? caustic,
		double? contentStrength,
		double? rippleStrength,
		double? frostSigma,
		GlassWave? wave,
	}) => GlassMaterial(
		smoothK: smoothK ?? this.smoothK,
		edgeWidth: edgeWidth ?? this.edgeWidth,
		height: height ?? this.height,
		thickness: thickness ?? this.thickness,
		aberration: aberration ?? this.aberration,
		tint: tint ?? this.tint,
		tintStrength: tintStrength ?? this.tintStrength,
		saturation: saturation ?? this.saturation,
		specular: specular ?? this.specular,
		shininess: shininess ?? this.shininess,
		rim: rim ?? this.rim,
		rimWidth: rimWidth ?? this.rimWidth,
		fresnel: fresnel ?? this.fresnel,
		innerShadow: innerShadow ?? this.innerShadow,
		shadow: shadow ?? this.shadow,
		floorScale: floorScale ?? this.floorScale,
		caustic: caustic ?? this.caustic,
		contentStrength: contentStrength ?? this.contentStrength,
		rippleStrength: rippleStrength ?? this.rippleStrength,
		frostSigma: frostSigma ?? this.frostSigma,
		wave: wave ?? this.wave,
	);
}
