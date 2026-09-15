// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'snap.dart';

// Screenshot hook: a diagonal stroke across every card, driven by real pointers.
const _debugStroke = false;
// Seconds from launch at which that stroke starts; the programs must resolve first.
const _debugStrokeAt = 0.8;
// Seconds at which a second stroke crosses the flow of the first; < 0 skips it.
const _debugSecondStroke = -1.0;
// Seconds at which a stroke carries the left card's dye across its neighbour; < 0 skips it.
const _debugCrossStroke = -1.0;
// Seconds at which a stroke runs through empty background only; < 0 skips it.
const _debugAwayStroke = -1.0;
// Seconds at which every card is stamped with no velocity at all; < 0 skips it.
const _debugStampAt = -1.0;
// Holds the settle clock so a captured frame never moves; < 0 lets it run.
const _debugFreezeAt = -1.0;
// Seconds from launch at which a snap is written; see snap.dart.
const _debugSnapAt = <double>[];
// Profiling hook: runs _profileRuns back to back and prints a timing table.
const _debugProfile = false;
// Prints the live ui.Image count once a second; the leak check.
const _debugCensus = false;
// Overrides dissipationSpeed; 1 makes the decay global again, as Dobryakov has it.
const _debugDecaySpeed = -1.0;
// Same content and a flat backdrop on every card, so their dye must come out
// byte-identical; the sim-grid determinism check.
const _debugIdenticalCards = false;

/// label, sim resolution, pressure iterations, dye cap, float fields.
const _profileRuns = <(String, double, double, double, double)>[
	('idle', 0, 0, 0, 0),
	('sim 256, pressure 20, dye native, float32', 256, 20, 0, 1),
	('sim 256, pressure 8, dye native, float32', 256, 8, 0, 1),
	('sim 128, pressure 20, dye native, float32', 128, 20, 0, 1),
	('sim 256, pressure 20, dye native, rgba8', 256, 20, 0, 0),
	('sim 256, pressure 20, dye 1024, float32', 256, 20, 1024, 1),
	('sim 384, pressure 20, dye native, float32', 384, 20, 0, 1),
	('idle again', 0, 0, 0, 0),
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
	final FluidSceneController _scene = FluidSceneController();
	final GlobalKey _sceneKey = GlobalKey();
	final List<GlobalKey> _cardKeys = [for (var i = 0; i < _cards.length; i++) GlobalKey()];
	final List<FluidController> _effects = [
		for (var i = 0; i < _cards.length; i++) FluidController(),
	];
	final Stopwatch _clock = Stopwatch()..start();

	FluidConfig _config = _debugDecaySpeed < 0
		? const FluidConfig()
		: const FluidConfig(dissipationSpeed: _debugDecaySpeed);
	FluidPreset? _preset;
	bool _panel = true;
	Timer? _driver;
	Timer? _census;
	int _pointer = 100;
	int _live = 0;
	String _report = '';

	@override
	void initState() {
		super.initState();
		if (_debugCensus) _startCensus();
		if (!_debugStroke && !_debugProfile && _debugSnapAt.isEmpty && _debugStampAt < 0) return;
		_panel = false;
		// An occluded macOS window gets no frames at all, so pump from the first tick.
		startSnapPump();
		if (_debugProfile) {
			_at(0.5, () => unawaited(_runProfile()));
			return;
		}
		_scheduleDebugInput();
		WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSnaps());
	}

	@override
	void dispose() {
		_driver?.cancel();
		_census?.cancel();
		_scene.dispose();
		for (final effect in _effects) {
			effect.dispose();
		}
		super.dispose();
	}

	void _scheduleDebugInput() {
		if (_debugStampAt >= 0) {
			_at(_debugStampAt, () {
				for (final effect in _effects) {
					effect.stamp();
				}
			});
		}
		if (_debugStroke) _at(_debugStrokeAt, () => _cardStroke(const Offset(18, 24), const Offset(132, 176), 0.25));
		if (_debugSecondStroke >= 0) {
			_at(_debugSecondStroke, () => _cardStroke(const Offset(-40, 110), const Offset(190, 96), 0.1));
		}
		if (_debugCrossStroke >= 0) _at(_debugCrossStroke, _crossStroke);
		if (_debugAwayStroke >= 0) _at(_debugAwayStroke, _awayStroke);
		if (_debugFreezeAt >= 0) _at(_debugFreezeAt, () => _scene.freeze(_scene.settled));
	}

	void _at(double seconds, VoidCallback run) =>
		Timer(Duration(milliseconds: (seconds * 1000).round()), run);

	void _startCensus() {
		ui.Image.onCreate = (_) => _live++;
		ui.Image.onDispose = (_) => _live--;
		_census = Timer.periodic(const Duration(seconds: 1), (_) {
			debugPrint('fluid census: ui.Image live=$_live solver=${_scene.liveImages} '
				'passes=${_scene.passes} status=${_scene.status}');
		});
	}

	void _send(PointerEvent event) => WidgetsBinding.instance.handlePointerEvent(event);

	Offset _inCard(int index, Offset local) {
		final box = _cardKeys[index].currentContext?.findRenderObject();
		return box is RenderBox && box.hasSize ? box.localToGlobal(local) : local;
	}

	Offset _inScene(Offset local) {
		final box = _sceneKey.currentContext?.findRenderObject();
		return box is RenderBox && box.hasSize ? box.localToGlobal(local) : local;
	}

	/// The same card-local stroke on every card at once, as three real pointers.
	void _cardStroke(Offset from, Offset to, double seconds) => _pointerStroke([
		for (var i = 0; i < _cards.length; i++) (_inCard(i, from), _inCard(i, to)),
	], seconds);

	/// Starts on the left card and runs across its neighbour; one pointer, one domain.
	void _crossStroke() =>
		_pointerStroke([(_inCard(0, const Offset(40, 100)), _inCard(2, const Offset(110, 120)))], 0.35);

	/// Never touches a card: it may only stir dye that is already in the field.
	void _awayStroke() {
		final box = _sceneKey.currentContext?.findRenderObject();
		if (box is! RenderBox || !box.hasSize) return;
		final h = box.size.height;
		_pointerStroke([(_inScene(Offset(30, h - 60)), _inScene(Offset(box.size.width - 60, h - 200)))], 0.3);
	}

	/// Walks real pointers along [paths] (global px) over [seconds] of wall clock.
	void _pointerStroke(List<(Offset, Offset)> paths, double seconds) {
		_driver?.cancel();
		final steps = (seconds * 60).round().clamp(2, 600);
		final ids = [for (var i = 0; i < paths.length; i++) _pointer++];
		for (var i = 0; i < paths.length; i++) {
			_send(PointerDownEvent(
				pointer: ids[i],
				position: paths[i].$1,
				kind: PointerDeviceKind.touch,
				timeStamp: _clock.elapsed,
			));
		}
		var step = 0;
		_driver = Timer.periodic(const Duration(milliseconds: 16), (timer) {
			step++;
			for (var i = 0; i < paths.length; i++) {
				final (from, to) = paths[i];
				final at = Offset.lerp(from, to, step / steps)!;
				final was = Offset.lerp(from, to, (step - 1) / steps)!;
				_send(PointerMoveEvent(
					pointer: ids[i],
					position: at,
					delta: at - was,
					kind: PointerDeviceKind.touch,
					timeStamp: _clock.elapsed,
				));
			}
			if (step < steps) return;
			timer.cancel();
			for (var i = 0; i < paths.length; i++) {
				_send(PointerUpEvent(
					pointer: ids[i],
					position: paths[i].$2,
					kind: PointerDeviceKind.touch,
					timeStamp: _clock.elapsed,
				));
			}
			debugPrint('fluid stroke done: passes/frame=${_scene.passes} live=${_scene.liveImages}');
		});
	}

	/// Keeps a pointer circling so the sim never idles while the window is measured.
	void _stir() {
		_driver?.cancel();
		final id = _pointer++;
		final centre = _inCard(1, const Offset(75, 100));
		_send(PointerDownEvent(
			pointer: id,
			position: centre,
			kind: PointerDeviceKind.touch,
			timeStamp: _clock.elapsed,
		));
		var step = 0;
		var last = centre;
		_driver = Timer.periodic(const Duration(milliseconds: 16), (_) {
			step++;
			final t = step * 0.12;
			final at = centre + Offset(120 * math.cos(t), 140 * math.sin(t * 1.3));
			_send(PointerMoveEvent(
				pointer: id,
				position: at,
				delta: at - last,
				kind: PointerDeviceKind.touch,
				timeStamp: _clock.elapsed,
			));
			last = at;
		});
	}

	Future<void> _runProfile() async {
		final lines = <String>[];
		for (final (label, sim, iterations, dye, floats) in _profileRuns) {
			_scene.reset();
			setState(() {
				_config = _config.copyWith(
					simResolution: sim > 0 ? sim : _config.simResolution,
					pressureIterations: iterations > 0 ? iterations : _config.pressureIterations,
					dyeResolution: dye,
					floatFields: floats,
					lifetime: 30,
				);
			});
			await Future<void>.delayed(const Duration(milliseconds: 200));
			if (sim > 0) {
				for (final effect in _effects) {
					effect.stamp();
				}
				await Future<void>.delayed(const Duration(milliseconds: 100));
				_stir();
			} else {
				startSnapPump();
			}
			await Future<void>.delayed(const Duration(milliseconds: 400));
			final timings = await _measure(_profileFrames);
			final passes = sim > 0 ? _scene.passes : 0;
			lines.add('$label: build ${timings.$1.toStringAsFixed(2)} ms, '
				'raster ${timings.$2.toStringAsFixed(2)} ms, passes/frame $passes');
			debugPrint('PROFILE ${lines.last}');
			_driver?.cancel();
			stopSnapPump();
			_scene.reset();
			await Future<void>.delayed(const Duration(milliseconds: 500));
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
				Positioned.fill(child: _sceneWidget()),
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

	Widget _sceneWidget() {
		return FluidScene(
			key: _sceneKey,
			controller: _scene,
			config: _config,
			child: DecoratedBox(
				decoration: const BoxDecoration(
					color: _debugIdenticalCards ? Color(0xFF12131A) : null,
					gradient: _debugIdenticalCards
						? null
						: LinearGradient(
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
										key: _cardKeys[i],
										controller: _effects[i],
										child: _Card(card: _cards[_debugIdenticalCards ? 0 : i]),
									),
							],
						),
					),
				),
			),
		);
	}

	Widget _controls() {
		final knobs = <(String, double, double, double, FluidConfig Function(double))>[
			('sim', 32, 384, _config.simResolution, (v) => _config.copyWith(simResolution: v)),
			('dye cap', 0, 2048, _config.dyeResolution, (v) => _config.copyWith(dyeResolution: v)),
			('pressure it', 1, 32, _config.pressureIterations, (v) => _config.copyWith(pressureIterations: v)),
			('pressure', 0, 1, _config.pressure, (v) => _config.copyWith(pressure: v)),
			('curl', 0, 60, _config.curl, (v) => _config.copyWith(curl: v)),
			('dye decay', 0, 4, _config.densityDissipation, (v) => _config.copyWith(densityDissipation: v)),
			('decay speed', 10, 800, _config.dissipationSpeed, (v) => _config.copyWith(dissipationSpeed: v)),
			('vel decay', 0, 4, _config.velocityDissipation, (v) => _config.copyWith(velocityDissipation: v)),
			('splat radius', 4, 120, _config.splatRadius, (v) => _config.copyWith(splatRadius: v)),
			('splat force', 1, 40, _config.splatForce, (v) => _config.copyWith(splatForce: v)),
			('shading', 0, 1, _config.shading, (v) => _config.copyWith(shading: v)),
			('lifetime', 0.5, 10, _config.lifetime, (v) => _config.copyWith(lifetime: v)),
			('fade out', 0, 4, _config.fadeOut, (v) => _config.copyWith(fadeOut: v)),
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
					_group('Preset'),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
						child: Wrap(
							spacing: 6,
							children: [
								for (final preset in FluidPreset.values)
									ChoiceChip(
										label: Text(preset.name, style: const TextStyle(fontSize: 11)),
										selected: _preset == preset,
										onSelected: (_) => setState(() {
											_preset = preset;
											_config = FluidConfig.of(preset);
										}),
									),
							],
						),
					),
					_group('Debug'),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
						child: Wrap(
							children: [
								TextButton(
									onPressed: () => _cardStroke(const Offset(18, 24), const Offset(132, 176), 0.25),
									child: const Text('Stroke'),
								),
								TextButton(onPressed: _crossStroke, child: const Text('Cross')),
								TextButton(
									onPressed: () => _effects[0].play(direction: const Offset(1, 0.6)),
									child: const Text('Play'),
								),
								TextButton(onPressed: _runProfile, child: const Text('Profile')),
							],
						),
					),
					_group('Solver'),
					for (final (label, min, max, value, set) in knobs)
						_row(label, value, min, max, (v) => setState(() {
							_preset = null;
							_config = set(v);
						})),
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
