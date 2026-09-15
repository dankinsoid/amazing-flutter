// @ai-generated(solo)

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'config.dart';
import 'passes.dart';

/// setFloat indices; mirrors the uniform block of each `shaders/fluid_*.frag`.
abstract final class _U {
	static const resolution = 0;

	static const advTexel = 2, advSourceTexel = 4, advDt = 6;
	static const advDissipation = 7, advVector = 8, advVelCode = 9, advSourceCode = 11;

	static const curlTexel = 2, curlVelCode = 4, curlCurlCode = 6;

	static const vortTexel = 2, vortCurl = 4, vortDt = 5, vortVelCode = 6, vortCurlCode = 8;

	static const divTexel = 2, divVelCode = 4, divDivCode = 6;

	static const presTexel = 2, presDecay = 4, presPressCode = 5, presDivCode = 7;

	static const gradTexel = 2, gradVelCode = 4, gradPressCode = 6;

	static const splatPoint = 2, splatForce = 4, splatRadius = 6, splatAspect = 7, splatVelCode = 8;

	static const dispTexel = 2, dispShading = 4, dispOpacity = 5, dispEdgeFade = 6;
}

/// The eight programs of the solver, loaded once per isolate.
class FluidShaders {
	FluidShaders._(List<ui.FragmentProgram> programs)
		: advection = programs[0].fragmentShader(),
			curl = programs[1].fragmentShader(),
			vorticity = programs[2].fragmentShader(),
			divergence = programs[3].fragmentShader(),
			pressure = programs[4].fragmentShader(),
			gradient = programs[5].fragmentShader(),
			splat = programs[6].fragmentShader(),
			display = programs[7].fragmentShader();

	static const _names = [
		'fluid_advection',
		'fluid_curl',
		'fluid_vorticity',
		'fluid_divergence',
		'fluid_pressure',
		'fluid_gradient',
		'fluid_splat',
		'fluid_display',
	];

	static Future<List<ui.FragmentProgram>>? _loading;

	final ui.FragmentShader advection;
	final ui.FragmentShader curl;
	final ui.FragmentShader vorticity;
	final ui.FragmentShader divergence;
	final ui.FragmentShader pressure;
	final ui.FragmentShader gradient;
	final ui.FragmentShader splat;
	final ui.FragmentShader display;

	static Future<FluidShaders> load() async {
		_loading ??= Future.wait([
			for (final name in _names)
				ui.FragmentProgram.fromAsset('packages/amazing_flutter/shaders/$name.frag'),
		]);
		return FluidShaders._(await _loading!);
	}

	void dispose() {
		advection.dispose();
		curl.dispose();
		vorticity.dispose();
		divergence.dispose();
		pressure.dispose();
		gradient.dispose();
		splat.dispose();
		display.dispose();
	}
}

/// Stable Fluids on ping-ponged `toImageSync` targets; dye is a widget snapshot.
class FluidSolver {
	FluidSolver(this.shaders);

	final FluidShaders shaders;
	final PassRunner _runner = PassRunner();
	final Field _velocity = Field();
	final Field _pressure = Field();
	final Field _dye = Field();

	FluidConfig _config = const FluidConfig();
	ui.Image? _curl;
	ui.Image? _divergence;
	ui.Size _canvas = ui.Size.zero;
	int _dyeW = 0;
	int _dyeH = 0;
	int _simW = 0;
	int _simH = 0;
	int _passes = 0;

	bool get isReady => !_dye.isEmpty;
	ui.Image get dye => _dye.image;

	/// Card plus the spread margin, logical px; the painter's canvas.
	ui.Size get canvasSize => _canvas;

	/// Passes recorded since the last [beginFrame].
	int get passes => _passes;

	ui.Size get simSize => ui.Size(_simW.toDouble(), _simH.toDouble());
	ui.Size get dyeSize => ui.Size(_dyeW.toDouble(), _dyeH.toDouble());

	bool get _float => _config.floatFields > 0.5;

	ui.TargetPixelFormat get _fieldFormat =>
		_float ? ui.TargetPixelFormat.rgbaFloat32 : ui.TargetPixelFormat.dontCare;

	/// Store transform `value * x + y`; the bias is 128/255 so zero stays exact.
	(double, double) _code(double range) =>
		_float ? (1, 0) : (1 / (2 * math.max(range, 1e-3)), 128 / 255);

	/// Seeds the dye from [snapshot] and clears the sim; sizes follow the snapshot.
	void begin(ui.Image snapshot, double devicePixelRatio, FluidConfig config) {
		_config = config;
		final margin = (config.spread * devicePixelRatio).round();
		final fullW = snapshot.width + 2 * margin;
		final fullH = snapshot.height + 2 * margin;
		_canvas = ui.Size(fullW / devicePixelRatio, fullH / devicePixelRatio);

		final cap = config.dyeResolution.round();
		final long = math.max(fullW, fullH);
		final scale = cap > 0 && long > cap ? cap / long : 1.0;
		_dyeW = math.max(2, (fullW * scale).round());
		_dyeH = math.max(2, (fullH * scale).round());

		final sim = config.simResolution.round();
		_simW = math.max(2, (sim * fullW / long).round());
		_simH = math.max(2, (sim * fullH / long).round());

		_dye.swap(_seedDye(snapshot, margin * scale, scale), _runner);
		_velocity.swap(_zeroField(), _runner);
		_pressure.swap(_zeroField(), _runner);
		_runner.retire(_curl);
		_runner.retire(_divergence);
		_curl = null;
		_divergence = null;
	}

	void end() {
		_dye.clear(_runner);
		_velocity.clear(_runner);
		_pressure.clear(_runner);
		_runner.retire(_curl);
		_runner.retire(_divergence);
		_curl = null;
		_divergence = null;
		_runner.recycle();
		_runner.recycle();
	}

	void beginFrame() {
		_runner.recycle();
		_passes = 0;
	}

	/// [at] and [delta] are child-local logical px; the force follows the travel.
	void splat(ui.Offset at, ui.Offset delta) {
		if (_velocity.isEmpty) return;
		final point = ui.Offset(
			(at.dx + _config.spread) / _canvas.width,
			(at.dy + _config.spread) / _canvas.height,
		);
		final aspect = _simW / _simH;
		var dx = delta.dx / _canvas.width;
		var dy = delta.dy / _canvas.height;
		// Dobryakov's correctDelta: a splat stays round on a non-square grid.
		if (aspect < 1) {
			dx *= aspect;
		} else {
			dy /= aspect;
		}
		final radius = _config.splatRadius / 100 * (aspect > 1 ? aspect : 1);
		final code = _code(_config.velocityRange);

		final shader = shaders.splat;
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.splatPoint, point.dx)
			..setFloat(_U.splatPoint + 1, point.dy)
			..setFloat(_U.splatForce, dx * _config.splatForce)
			..setFloat(_U.splatForce + 1, dy * _config.splatForce)
			..setFloat(_U.splatRadius, radius)
			..setFloat(_U.splatAspect, aspect)
			..setFloat(_U.splatVelCode, code.$1)
			..setFloat(_U.splatVelCode + 1, code.$2)
			..setImageSampler(0, _velocity.image);
		_velocity.swap(_runner.run(shader, _simW, _simH, format: _fieldFormat), _runner);
		_passes++;
	}

	void step(double dt) {
		if (_dye.isEmpty) return;
		final vel = _code(_config.velocityRange);
		final crl = _code(_config.curlRange);
		final div = _code(_config.divergenceRange);
		final prs = _code(_config.pressureRange);
		final texel = ui.Offset(1 / _simW, 1 / _simH);

		_curlPass(texel, vel, crl);
		_vorticityPass(texel, dt, vel, crl);
		_divergencePass(texel, vel, div);
		_pressurePasses(texel, prs, div);
		_gradientPass(texel, vel, prs);
		_advectVelocity(texel, dt, vel);
		_advectDye(texel, dt);
	}

	void _curlPass(ui.Offset texel, (double, double) vel, (double, double) crl) {
		final shader = shaders.curl;
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.curlTexel, texel.dx)
			..setFloat(_U.curlTexel + 1, texel.dy)
			..setFloat(_U.curlVelCode, vel.$1)
			..setFloat(_U.curlVelCode + 1, vel.$2)
			..setFloat(_U.curlCurlCode, crl.$1)
			..setFloat(_U.curlCurlCode + 1, crl.$2)
			..setImageSampler(0, _velocity.image);
		_runner.retire(_curl);
		_curl = _runner.run(shader, _simW, _simH, format: _fieldFormat);
		_passes++;
	}

	void _vorticityPass(ui.Offset texel, double dt, (double, double) vel, (double, double) crl) {
		final shader = shaders.vorticity;
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.vortTexel, texel.dx)
			..setFloat(_U.vortTexel + 1, texel.dy)
			..setFloat(_U.vortCurl, _config.curl)
			..setFloat(_U.vortDt, dt)
			..setFloat(_U.vortVelCode, vel.$1)
			..setFloat(_U.vortVelCode + 1, vel.$2)
			..setFloat(_U.vortCurlCode, crl.$1)
			..setFloat(_U.vortCurlCode + 1, crl.$2)
			..setImageSampler(0, _velocity.image)
			..setImageSampler(1, _curl!);
		_velocity.swap(_runner.run(shader, _simW, _simH, format: _fieldFormat), _runner);
		_passes++;
	}

	void _divergencePass(ui.Offset texel, (double, double) vel, (double, double) div) {
		final shader = shaders.divergence;
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.divTexel, texel.dx)
			..setFloat(_U.divTexel + 1, texel.dy)
			..setFloat(_U.divVelCode, vel.$1)
			..setFloat(_U.divVelCode + 1, vel.$2)
			..setFloat(_U.divDivCode, div.$1)
			..setFloat(_U.divDivCode + 1, div.$2)
			..setImageSampler(0, _velocity.image);
		_runner.retire(_divergence);
		_divergence = _runner.run(shader, _simW, _simH, format: _fieldFormat);
		_passes++;
	}

	void _pressurePasses(ui.Offset texel, (double, double) prs, (double, double) div) {
		final shader = shaders.pressure;
		final iterations = math.max(1, _config.pressureIterations.round());
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.presTexel, texel.dx)
			..setFloat(_U.presTexel + 1, texel.dy)
			..setFloat(_U.presPressCode, prs.$1)
			..setFloat(_U.presPressCode + 1, prs.$2)
			..setFloat(_U.presDivCode, div.$1)
			..setFloat(_U.presDivCode + 1, div.$2)
			..setImageSampler(1, _divergence!);
		for (var i = 0; i < iterations; i++) {
			shader
				..setFloat(_U.presDecay, i == 0 ? _config.pressure : 1)
				..setImageSampler(0, _pressure.image);
			_pressure.swap(_runner.run(shader, _simW, _simH, format: _fieldFormat), _runner);
			_passes++;
		}
	}

	void _gradientPass(ui.Offset texel, (double, double) vel, (double, double) prs) {
		final shader = shaders.gradient;
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setFloat(_U.gradTexel, texel.dx)
			..setFloat(_U.gradTexel + 1, texel.dy)
			..setFloat(_U.gradVelCode, vel.$1)
			..setFloat(_U.gradVelCode + 1, vel.$2)
			..setFloat(_U.gradPressCode, prs.$1)
			..setFloat(_U.gradPressCode + 1, prs.$2)
			..setImageSampler(0, _pressure.image)
			..setImageSampler(1, _velocity.image);
		_velocity.swap(_runner.run(shader, _simW, _simH, format: _fieldFormat), _runner);
		_passes++;
	}

	void _advectVelocity(ui.Offset texel, double dt, (double, double) vel) {
		final shader = shaders.advection;
		_writeAdvection(shader, texel, texel, dt, _config.velocityDissipation, 1, vel, vel);
		shader
			..setFloat(_U.resolution, _simW.toDouble())
			..setFloat(_U.resolution + 1, _simH.toDouble())
			..setImageSampler(0, _velocity.image)
			..setImageSampler(1, _velocity.image);
		_velocity.swap(_runner.run(shader, _simW, _simH, format: _fieldFormat), _runner);
		_passes++;
	}

	void _advectDye(ui.Offset texel, double dt) {
		final shader = shaders.advection;
		final vel = _code(_config.velocityRange);
		_writeAdvection(
			shader,
			texel,
			ui.Offset(1 / _dyeW, 1 / _dyeH),
			dt,
			_config.densityDissipation,
			0,
			vel,
			(1, 0),
		);
		shader
			..setFloat(_U.resolution, _dyeW.toDouble())
			..setFloat(_U.resolution + 1, _dyeH.toDouble())
			..setImageSampler(0, _velocity.image)
			..setImageSampler(1, _dye.image);
		_dye.swap(_runner.run(shader, _dyeW, _dyeH), _runner);
		_passes++;
	}

	void _writeAdvection(
		ui.FragmentShader shader,
		ui.Offset texel,
		ui.Offset sourceTexel,
		double dt,
		double dissipation,
		double vector,
		(double, double) vel,
		(double, double) source,
	) {
		shader
			..setFloat(_U.advTexel, texel.dx)
			..setFloat(_U.advTexel + 1, texel.dy)
			..setFloat(_U.advSourceTexel, sourceTexel.dx)
			..setFloat(_U.advSourceTexel + 1, sourceTexel.dy)
			..setFloat(_U.advDt, dt)
			..setFloat(_U.advDissipation, dissipation)
			..setFloat(_U.advVector, vector)
			..setFloat(_U.advVelCode, vel.$1)
			..setFloat(_U.advVelCode + 1, vel.$2)
			..setFloat(_U.advSourceCode, source.$1)
			..setFloat(_U.advSourceCode + 1, source.$2);
	}

	/// Paints the dye over [size]; the caller owns the canvas and its transform.
	void paint(ui.Canvas canvas, ui.Size size, double opacity) {
		if (_dye.isEmpty) return;
		final shader = shaders.display;
		shader
			..setFloat(_U.resolution, size.width)
			..setFloat(_U.resolution + 1, size.height)
			..setFloat(_U.dispTexel, 1 / _dyeW)
			..setFloat(_U.dispTexel + 1, 1 / _dyeH)
			..setFloat(_U.dispShading, _config.shading)
			..setFloat(_U.dispOpacity, opacity)
			..setFloat(_U.dispEdgeFade, _config.edgeFade)
			..setImageSampler(0, _dye.image);
		canvas.drawRect(
			ui.Offset.zero & size,
			ui.Paint()
				..shader = shader
				..isAntiAlias = false,
		);
	}

	ui.Image _seedDye(ui.Image snapshot, double margin, double scale) {
		final src = ui.Rect.fromLTWH(0, 0, snapshot.width.toDouble(), snapshot.height.toDouble());
		final dst = ui.Rect.fromLTWH(margin, margin, snapshot.width * scale, snapshot.height * scale);
		return _runner.rasterize(_dyeW, _dyeH, (canvas) {
			canvas.drawImageRect(
				snapshot,
				src,
				dst,
				ui.Paint()
					// Nearest at scale 1 keeps the frozen card byte-identical to the child.
					..filterQuality = scale == 1 ? ui.FilterQuality.none : ui.FilterQuality.medium
					..isAntiAlias = false,
			);
		});
	}

	ui.Image _zeroField() {
		final colour = _float ? const ui.Color(0xFF000000) : const ui.Color(0xFF808000);
		return _runner.rasterize(_simW, _simH, (canvas) {
			canvas.drawRect(
				ui.Rect.fromLTWH(0, 0, _simW.toDouble(), _simH.toDouble()),
				ui.Paint()
					..color = colour
					..blendMode = ui.BlendMode.src
					..isAntiAlias = false,
			);
		}, format: _fieldFormat);
	}

	void dispose() {
		end();
		_runner.dispose();
	}
}
