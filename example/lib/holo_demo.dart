// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'snap.dart';

// Screenshot hooks: a non-null tilt or pointer parks every card and ignores live input.
const Offset? _debugTilt = null;
const Offset? _debugPointer = null;
const _debugStrength = 1.0;
// Seconds from launch at which a snap is written; see snap.dart.
const _debugSnapAt = <double>[];
// Profiling hook: spins every card for _profileFrames and prints a timing table.
const _debugProfile = false;

const _profileFrames = 120;

/// label, tilts, pointer, sensors.
const _cards = <(String, String, bool, bool, bool)>[
	('Aurora', 'pointer + sensors', true, true, true),
	('Etched', 'reacts, never moves', false, true, true),
	('Cosmos', 'pointer only', true, true, false),
];

const _patterns = [HoloPattern.classic, HoloPattern.reverse, HoloPattern.galaxy];

class HoloDemo extends StatefulWidget {
	const HoloDemo({super.key});

	@override
	State<HoloDemo> createState() => _HoloDemoState();
}

class _HoloDemoState extends State<HoloDemo> with TickerProviderStateMixin {
	late final List<HoloController> _controllers = [
		for (var i = 0; i < _cards.length; i++) HoloController(vsync: this, config: _presetOf(i)),
	];

	Ticker? _spin;
	double _foil = HoloConfig.holo.foil;
	double _glare = HoloConfig.holo.glare;
	double _grain = HoloConfig.holo.grain;
	double _bandScale = HoloConfig.holo.bandScale;
	double _radius = 20;
	double _seed = 0;
	double _maxAngle = HoloConfig.holo.maxAngle;
	HoloMask? _mask;
	bool _panel = true;
	String _report = '';

	static HoloConfig _presetOf(int index) => HoloConfig.of(_patterns[index]);

	@override
	void initState() {
		super.initState();
		if (_debugTilt == null && _debugPointer == null && !_debugProfile && _debugSnapAt.isEmpty) return;
		_panel = false;
		// An occluded macOS window gets no frames at all, so pump from the first tick.
		startSnapPump();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_freezeDebug();
			if (_debugProfile) unawaited(_runProfile());
			_scheduleSnaps();
		});
	}

	@override
	void dispose() {
		_spin?.dispose();
		for (final controller in _controllers) {
			controller.dispose();
		}
		super.dispose();
	}

	void _freezeDebug() {
		if (_debugTilt == null && _debugPointer == null) return;
		for (final controller in _controllers) {
			controller.freeze(tilt: _debugTilt, pointer: _debugPointer, strength: _debugStrength);
		}
		debugPrint('debug freeze: tilt=$_debugTilt pointer=$_debugPointer strength=$_debugStrength');
	}

	void _scheduleSnaps() {
		if (_debugSnapAt.isEmpty) return;
		final dpr = MediaQuery.devicePixelRatioOf(context);
		var pending = _debugSnapAt.length;
		for (final at in _debugSnapAt) {
			Future<void>.delayed(Duration(milliseconds: (at * 1000).round()), () async {
				await writeSnap('holo_${at.toStringAsFixed(2)}s', dpr);
				if (--pending == 0) stopSnapPump();
			});
		}
	}

	Future<void> _runProfile() async {
		final lines = <String>[];
		// The first run is cold; a second idle pass is what the spinning one is read against.
		for (final label in ['idle', '3 cards spinning', 'idle again', '3 cards spinning again']) {
			label.startsWith('idle') ? _spin?.stop() : _startSpin();
			final timing = await _measure(_profileFrames);
			lines.add('$label: build ${timing.$1.toStringAsFixed(2)} ms, raster ${timing.$2.toStringAsFixed(2)} ms');
			debugPrint(lines.last);
		}
		_spin?.stop();
		setState(() => _report = lines.join('\n'));
	}

	// The cards only repaint when the controller notifies, so profiling has to move them.
	void _startSpin() {
		_spin ??= createTicker((elapsed) {
			final t = elapsed.inMicroseconds / 1e6;
			final tilt = Offset(math.cos(t * 2), math.sin(t * 1.4));
			for (final controller in _controllers) {
				controller.aimAt(tilt: tilt, pointer: tilt * 0.8, strength: 1);
			}
		});
		_spin!.start();
	}

	Future<(double, double)> _measure(int frames) {
		final done = Completer<(double, double)>();
		var seen = 0;
		var build = 0.0;
		var raster = 0.0;
		late final TimingsCallback callback;
		callback = (List<FrameTiming> timings) {
			for (final timing in timings) {
				build += timing.buildDuration.inMicroseconds / 1000;
				raster += timing.rasterDuration.inMicroseconds / 1000;
				if (++seen < frames) continue;
				SchedulerBinding.instance.removeTimingsCallback(callback);
				if (!done.isCompleted) done.complete((build / seen, raster / seen));
				return;
			}
		};
		SchedulerBinding.instance.addTimingsCallback(callback);
		return done.future;
	}

	HoloConfig _configFor(int index) {
		final (_, _, tilts, _, _) = _cards[index];
		final preset = _presetOf(index);
		return preset.copyWith(
			foil: _foil,
			glare: _glare,
			grain: _grain,
			bandScale: _bandScale,
			radius: _radius,
			seed: preset.seed + _seed,
			maxAngle: tilts ? _maxAngle : 0,
			mask: _mask ?? preset.mask,
		);
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				Positioned.fill(child: _scene()),
				if (_panel) Positioned(top: 0, right: 0, bottom: 0, child: _controls()),
				Positioned(
					top: 8,
					right: _panel ? 268 : 8,
					child: IconButton(
						icon: Icon(_panel ? Icons.chevron_right : Icons.tune, color: Colors.white),
						onPressed: () => setState(() => _panel = !_panel),
					),
				),
				if (_report.isNotEmpty)
					Positioned(
						left: 12,
						bottom: 12,
						child: Text(_report, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
					colors: [Color(0xFF0B0C12), Color(0xFF1A1430), Color(0xFF07242E)],
				),
			),
			child: Padding(
				padding: EdgeInsets.only(right: _panel ? 260 : 0),
				child: Center(
					child: Wrap(
						spacing: 34,
						runSpacing: 26,
						alignment: WrapAlignment.center,
						children: [
							for (var i = 0; i < _cards.length; i++) _slot(i),
						],
					),
				),
			),
		);
	}

	Widget _slot(int index) {
		final (title, hint, _, pointer, sensors) = _cards[index];
		final live = _debugTilt == null && _debugPointer == null;
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				HoloCard(
					controller: _controllers[index],
					config: _configFor(index),
					pointer: pointer && live,
					sensors: sensors && live,
					child: _CardArt(title: title, pattern: _patterns[index]),
				),
				const SizedBox(height: 10),
				Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 11)),
			],
		);
	}

	Widget _controls() {
		return Container(
			width: 260,
			color: const Color(0xCC101418),
			child: ListView(
				padding: const EdgeInsets.fromLTRB(0, 48, 0, 8),
				children: [
					_group('Mask'),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 12),
						child: Row(
							children: [
								for (final mask in [null, ...HoloMask.values])
									Expanded(
										child: GestureDetector(
											onTap: () => setState(() => _mask = mask),
											child: Container(
												margin: const EdgeInsets.symmetric(horizontal: 2),
												padding: const EdgeInsets.symmetric(vertical: 6),
												decoration: BoxDecoration(
													color: _mask == mask ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF),
													borderRadius: BorderRadius.circular(10),
												),
												child: Text(
													mask?.name ?? 'preset',
													textAlign: TextAlign.center,
													style: TextStyle(
														color: _mask == mask ? Colors.white : Colors.white54,
														fontSize: 10,
													),
												),
											),
										),
									),
							],
						),
					),
					_group('Foil'),
					_row('foil', _foil, 0, 2, (v) => setState(() => _foil = v)),
					_row('glare', _glare, 0, 1.5, (v) => setState(() => _glare = v)),
					_row('grain', _grain, 0, 1, (v) => setState(() => _grain = v)),
					_row('bandScale', _bandScale, 0.3, 12, (v) => setState(() => _bandScale = v)),
					_row('radius', _radius, 0, 60, (v) => setState(() => _radius = v)),
					_row('seed', _seed, 0, 20, (v) => setState(() => _seed = v)),
					_group('Card'),
					_row('maxAngle', _maxAngle, 0, 0.5, (v) => setState(() => _maxAngle = v)),
					_group('Debug'),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
						child: Row(
							children: [
								TextButton(
									onPressed: () {
										for (final controller in _controllers) {
											controller.release();
										}
									},
									child: const Text('Release'),
								),
								TextButton(onPressed: () => unawaited(_runProfile()), child: const Text('Profile')),
							],
						),
					),
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
						width: 90,
						child: Padding(
							padding: const EdgeInsets.only(left: 12),
							child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
						),
					),
					Expanded(
						child: SliderTheme(
							data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
							child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: set),
						),
					),
					SizedBox(
						width: 46,
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

const _art = <HoloPattern, (List<Color>, Color, String)>{
	HoloPattern.classic: ([Color(0xFF2B6CF6), Color(0xFF7BE3FF)], Color(0xFF0E1A33), 'water'),
	HoloPattern.reverse: ([Color(0xFFE8552B), Color(0xFFFFD36E)], Color(0xFF2A1208), 'fire'),
	HoloPattern.galaxy: ([Color(0xFF7B2FF7), Color(0xFFDC5CFF)], Color(0xFF140B28), 'psychic'),
};

/// The card the foil rides on; no rounding here, the shader clips the corners.
class _CardArt extends StatelessWidget {
	const _CardArt({required this.title, required this.pattern});

	final String title;
	final HoloPattern pattern;

	@override
	Widget build(BuildContext context) {
		final (colors, ink, type) = _art[pattern]!;
		return SizedBox(
			width: 210,
			height: 292,
			child: ColoredBox(
				color: ink,
				child: Padding(
					padding: const EdgeInsets.all(9),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
									const Spacer(),
									Text('HP 120', style: TextStyle(color: colors.last, fontSize: 12, fontWeight: FontWeight.w600)),
								],
							),
							const SizedBox(height: 7),
							Expanded(child: _ArtWindow(colors: colors)),
							const SizedBox(height: 8),
							Text(
								'$type · stage 2',
								style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2),
							),
							const SizedBox(height: 6),
							for (final (move, damage) in [('Prism Beam', '90'), ('Refract', '40')])
								Padding(
									padding: const EdgeInsets.only(bottom: 5),
									child: Row(
										children: [
											Container(width: 12, height: 12, decoration: BoxDecoration(color: colors.first, shape: BoxShape.circle)),
											const SizedBox(width: 7),
											Text(move, style: const TextStyle(color: Colors.white, fontSize: 12)),
											const Spacer(),
											Text(damage, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
										],
									),
								),
							Container(height: 1, color: const Color(0x33FFFFFF)),
							const SizedBox(height: 5),
							const Text('weakness ×2 · retreat ●●', style: TextStyle(color: Colors.white38, fontSize: 9)),
						],
					),
				),
			),
		);
	}
}

/// A bright art window: the luminance mask needs something to follow.
class _ArtWindow extends StatelessWidget {
	const _ArtWindow({required this.colors});

	final List<Color> colors;

	@override
	Widget build(BuildContext context) {
		return ClipRect(
			child: DecoratedBox(
				decoration: BoxDecoration(
					gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
				),
				child: Stack(
					children: [
						Positioned(
							left: -20,
							top: -16,
							child: Container(
								width: 120,
								height: 120,
								decoration: const BoxDecoration(color: Color(0x44FFFFFF), shape: BoxShape.circle),
							),
						),
						Positioned(
							right: 12,
							bottom: 16,
							child: Transform.rotate(
								angle: math.pi / 5,
								child: Container(width: 58, height: 58, color: const Color(0xCCFFFFFF)),
							),
						),
						Positioned(
							left: 24,
							bottom: -30,
							child: Container(
								width: 90,
								height: 90,
								decoration: const BoxDecoration(color: Color(0x33000000), shape: BoxShape.circle),
							),
						),
						const Positioned(
							right: 10,
							top: 8,
							child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
						),
					],
				),
			),
		);
	}
}
