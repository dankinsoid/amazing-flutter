// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'snap.dart';

// Screenshot hook: a diagonal stroke across every card.
const _debugStroke = false;
// Seconds from launch at which that stroke starts; the programs must resolve first.
const _debugStrokeAt = 0.6;
// Seconds at which a second, fast horizontal stroke crosses the dissolving smoke; < 0 skips it.
const _debugSecondStroke = -1.0;
// Seconds from launch at which a snap is written; see snap.dart.
const _debugSnapAt = <double>[];
// Profiling hook: runs _profileRuns back to back and prints a timing table.
const _debugProfile = false;
// Dobryakov's 6000 assumes a full-window canvas; over a 330 px card it detonates.
const _demoSplatForce = 1200.0;

/// label, sim resolution, pressure iterations, float fields; a zero sim resolution measures idle.
const _profileRuns = <(String, double, double, double)>[
	('idle', 0, 0, 0),
	('sim 128, pressure 20, rgba8', 128, 20, 0),
	('sim 128, pressure 8, rgba8', 128, 8, 0),
	('sim 128, pressure 4, rgba8', 128, 4, 0),
	('sim 64, pressure 8, rgba8', 64, 8, 0),
	('sim 128, pressure 20, float32', 128, 20, 1),
	('sim 128, pressure 8, float32', 128, 8, 1),
	('sim 128, pressure 40, rgba8', 128, 40, 0),
	('sim 256, pressure 20, rgba8', 256, 20, 0),
	('sim 256, pressure 20, float32', 256, 20, 1),
	('idle again', 0, 0, 0),
];

const _profileFrames = 120;

const _cards = <(String, String, List<Color>)>[
	('Flow', 'drag across me', [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
	('Swirl', 'or stir slowly', [Color(0xFF00B4DB), Color(0xFF0083B0)]),
	('Smoke', 'and let it settle', [Color(0xFFF7971E), Color(0xFFFFD200)]),
];

class FluidDemo extends StatefulWidget {
	const FluidDemo({super.key});

	@override
	State<FluidDemo> createState() => _FluidDemoState();
}

class _FluidDemoState extends State<FluidDemo> {
	final List<FluidController> _effects = [
		for (var i = 0; i < _cards.length; i++) FluidController(),
	];
	FluidConfig _config = const FluidConfig(splatForce: _demoSplatForce, floatFields: 1);
	bool _panel = true;
	Timer? _driver;
	String _report = '';

	@override
	void initState() {
		super.initState();
		if (!_debugStroke && !_debugProfile && _debugSnapAt.isEmpty) return;
		_panel = false;
		// The snapshot needs a painted boundary, so drive only after the first frame.
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_debugProfile) {
				unawaited(_runProfile());
				return;
			}
			if (_debugStroke) {
				Timer(Duration(milliseconds: (_debugStrokeAt * 1000).round()), () {
					_stroke(const Offset(18, 24), const Offset(132, 176), 0.25);
				});
			}
			if (_debugSecondStroke >= 0) {
				Timer(Duration(milliseconds: (_debugSecondStroke * 1000).round()), () {
					_stroke(const Offset(-40, 110), const Offset(190, 96), 0.1);
				});
			}
			_scheduleSnaps();
		});
	}

	@override
	void dispose() {
		_driver?.cancel();
		for (final effect in _effects) {
			effect.dispose();
		}
		super.dispose();
	}

	/// Walks every card's pointer from [from] to [to] in real time over [seconds].
	void _stroke(Offset from, Offset to, double seconds) {
		_driver?.cancel();
		final steps = (seconds * 60).round().clamp(2, 600);
		for (final effect in _effects) {
			effect.begin(from);
		}
		var i = 0;
		_driver = Timer.periodic(const Duration(milliseconds: 16), (timer) {
			i++;
			for (final effect in _effects) {
				effect.move(Offset.lerp(from, to, i / steps)!);
			}
			if (i < steps) return;
			timer.cancel();
			for (final effect in _effects) {
				effect.end();
			}
			debugPrint('fluid stroke done: passes/frame=${_effects.first.passes}');
		});
	}

	/// Keeps a finger circling so the sim never idles while the window is measured.
	void _stir() {
		_driver?.cancel();
		const centre = Offset(75, 100);
		for (final effect in _effects) {
			effect.begin(centre);
		}
		var i = 0;
		_driver = Timer.periodic(const Duration(milliseconds: 16), (_) {
			i++;
			final t = i * 0.12;
			final at = centre + Offset(60 * math.cos(t), 70 * math.sin(t * 1.3));
			for (final effect in _effects) {
				effect.move(at);
			}
		});
	}

	Future<void> _runProfile() async {
		final lines = <String>[];
		for (final (label, sim, iterations, floats) in _profileRuns) {
			setState(() {
				_config = _config.copyWith(
					simResolution: sim > 0 ? sim : _config.simResolution,
					pressureIterations: iterations > 0 ? iterations : _config.pressureIterations,
					floatFields: floats,
					lifetime: 30,
				);
			});
			await Future<void>.delayed(const Duration(milliseconds: 150));
			if (sim > 0) {
				_stir();
			} else {
				startSnapPump();
			}
			await Future<void>.delayed(const Duration(milliseconds: 300));
			final timings = await _measure(_profileFrames);
			final passes = sim > 0 ? _effects.first.passes : 0;
			lines.add('$label: build ${timings.$1.toStringAsFixed(2)} ms, '
				'raster ${timings.$2.toStringAsFixed(2)} ms, passes/frame/card $passes');
			debugPrint('PROFILE ${lines.last}');
			_driver?.cancel();
			stopSnapPump();
			for (final effect in _effects) {
				effect.reset();
			}
			await Future<void>.delayed(const Duration(milliseconds: 400));
		}
		setState(() => _report = lines.join('\n'));
		debugPrint('PROFILE TABLE\n${lines.join('\n')}');
	}

	/// Mean build and raster ms over [frames] rendered frames.
	Future<(double, double)> _measure(int frames) {
		final done = Completer<(double, double)>();
		var count = 0;
		var build = 0.0;
		var raster = 0.0;
		late final TimingsCallback callback;
		callback = (List<FrameTiming> timings) {
			for (final timing in timings) {
				build += timing.buildDuration.inMicroseconds / 1000;
				raster += timing.rasterDuration.inMicroseconds / 1000;
				count++;
			}
			if (count < frames || done.isCompleted) return;
			SchedulerBinding.instance.removeTimingsCallback(callback);
			done.complete((build / count, raster / count));
		};
		SchedulerBinding.instance.addTimingsCallback(callback);
		return done.future;
	}

	void _scheduleSnaps() {
		if (_debugSnapAt.isEmpty) return;
		final dpr = MediaQuery.devicePixelRatioOf(context);
		startSnapPump();
		var pending = _debugSnapAt.length;
		for (final at in _debugSnapAt) {
			Future<void>.delayed(Duration(milliseconds: (at * 1000).round()), () async {
				await writeSnap('fluid_${at.toStringAsFixed(2)}s', dpr);
				if (--pending == 0) stopSnapPump();
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				Positioned.fill(child: _scene()),
				if (_panel) Positioned(top: 0, right: 0, bottom: 0, child: _controls()),
				if (_report.isNotEmpty)
					Positioned(
						left: 12,
						bottom: 12,
						child: Text(_report, style: const TextStyle(color: Colors.white, fontSize: 11)),
					),
				Positioned(
					top: 8,
					right: _panel ? 268 : 8,
					child: IconButton(
						icon: Icon(_panel ? Icons.chevron_right : Icons.tune, color: Colors.white),
						onPressed: () => setState(() => _panel = !_panel),
					),
				),
			],
		);
	}

	Widget _scene() {
		return DecoratedBox(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [Color(0xFF12131A), Color(0xFF2B1B44), Color(0xFF0C3B4A)],
				),
			),
			child: Padding(
				padding: EdgeInsets.only(right: _panel ? 260 : 0),
				child: Center(
					child: Wrap(
						spacing: 28,
						runSpacing: 28,
						alignment: WrapAlignment.center,
						children: [
							for (var i = 0; i < _cards.length; i++)
								Fluid(
									controller: _effects[i],
									config: _config,
									child: _Card(card: _cards[i]),
								),
						],
					),
				),
			),
		);
	}

	Widget _controls() {
		final knobs = <(String, double, double, double, FluidConfig Function(double))>[
			('sim', 32, 256, _config.simResolution, (v) => _config.copyWith(simResolution: v)),
			('dye', 0, 1024, _config.dyeResolution, (v) => _config.copyWith(dyeResolution: v)),
			('pressure it', 1, 32, _config.pressureIterations, (v) => _config.copyWith(pressureIterations: v)),
			('pressure', 0, 1, _config.pressure, (v) => _config.copyWith(pressure: v)),
			('curl', 0, 60, _config.curl, (v) => _config.copyWith(curl: v)),
			('dye decay', 0, 4, _config.densityDissipation, (v) => _config.copyWith(densityDissipation: v)),
			('vel decay', 0, 4, _config.velocityDissipation, (v) => _config.copyWith(velocityDissipation: v)),
			('splat radius', 0.02, 1, _config.splatRadius, (v) => _config.copyWith(splatRadius: v)),
			('splat force', 500, 20000, _config.splatForce, (v) => _config.copyWith(splatForce: v)),
			('shading', 0, 1, _config.shading, (v) => _config.copyWith(shading: v)),
			('lifetime', 0.5, 10, _config.lifetime, (v) => _config.copyWith(lifetime: v)),
			('fade out', 0, 4, _config.fadeOut, (v) => _config.copyWith(fadeOut: v)),
			('spread', 0, 200, _config.spread, (v) => _config.copyWith(spread: v)),
			('edge fade', 0, 120, _config.edgeFade, (v) => _config.copyWith(edgeFade: v)),
			('vel range', 32, 2048, _config.velocityRange, (v) => _config.copyWith(velocityRange: v)),
			('curl range', 16, 2048, _config.curlRange, (v) => _config.copyWith(curlRange: v)),
			('div range', 8, 1024, _config.divergenceRange, (v) => _config.copyWith(divergenceRange: v)),
			('press range', 8, 1024, _config.pressureRange, (v) => _config.copyWith(pressureRange: v)),
			('float fields', 0, 1, _config.floatFields, (v) => _config.copyWith(floatFields: v)),
		];
		return Container(
			width: 260,
			color: const Color(0xCC101418),
			child: ListView(
				padding: const EdgeInsets.fromLTRB(0, 48, 0, 8),
				children: [
					_group('Debug'),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
						child: Row(
							children: [
								TextButton(
									onPressed: () => _stroke(const Offset(18, 24), const Offset(132, 176), 0.25),
									child: const Text('Stroke'),
								),
								TextButton(onPressed: _runProfile, child: const Text('Profile')),
							],
						),
					),
					_group('Solver'),
					for (final (label, min, max, value, set) in knobs)
						_row(label, value, min, max, (v) => setState(() => _config = set(v))),
				],
			),
		);
	}

	Widget _group(String label) => Padding(
		padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
		child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
	);

	Widget _row(String label, double value, double min, double max, ValueChanged<double> set) {
		return SizedBox(
			height: 34,
			child: Row(
				children: [
					SizedBox(
						width: 84,
						child: Padding(
							padding: const EdgeInsets.only(left: 12),
							child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
						),
					),
					Expanded(
						child: SliderTheme(
							data: const SliderThemeData(
								trackHeight: 2,
								thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
							),
							child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: set),
						),
					),
					SizedBox(
						width: 50,
						child: Text(
							value.toStringAsFixed(value.abs() < 10 ? 2 : 0),
							style: const TextStyle(color: Colors.white70, fontSize: 11),
						),
					),
				],
			),
		);
	}
}

class _Card extends StatelessWidget {
	const _Card({required this.card});

	final (String, String, List<Color>) card;

	@override
	Widget build(BuildContext context) {
		final (title, hint, colors) = card;
		return Container(
			width: 150,
			height: 200,
			decoration: BoxDecoration(
				gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
				borderRadius: BorderRadius.circular(20),
			),
			padding: const EdgeInsets.all(16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Icon(Icons.water_drop, color: Colors.white, size: 26),
					const Spacer(),
					Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
					const SizedBox(height: 4),
					Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 12)),
					const SizedBox(height: 10),
					for (var i = 0; i < 3; i++)
						Container(
							height: 4,
							width: 90.0 - i * 22,
							margin: const EdgeInsets.only(bottom: 5),
							decoration: BoxDecoration(
								color: const Color(0x55FFFFFF),
								borderRadius: BorderRadius.circular(2),
							),
						),
				],
			),
		);
	}
}
