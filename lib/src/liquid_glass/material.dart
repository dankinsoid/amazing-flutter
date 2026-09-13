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
	/// Content displacement per pixel of water envelope.
	final double contentStrength;
	/// Multiplies every touch amplitude; 0 turns the water off.
	final double rippleStrength;
	/// Backdrop blur; applied by the engine, never reaches the shader.
	final double frostSigma;
	final GlassWave wave;
}
