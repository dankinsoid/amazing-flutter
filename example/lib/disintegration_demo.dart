// @ai-generated(solo)

import 'dart:async';
import 'dart:math' as math;

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';

import 'snap.dart';

// Screenshot hook: a progress below 0 leaves the screen interactive.
const _debugProgress = -1.0;
const _debugMode = DisintegrationMode.shards;
const _debugAngle = 0.0;
// Erode screenshot hook: draws a synthetic stroke, then parks a global progress on top.
const _debugStroke = false;
const _debugStrokeProgress = -1.0;
// Seconds after the stroke at which a snap is written; see snap.dart.
const _debugSnapAt = <double>[];
// Seconds after the first stroke at which a second, faster one is injected as pointer
// events through the real hit test; below 0 = off.
const _debugStirAt = -1.0;

typedef _Read = double Function(DisintegrationConfig c);
typedef _Write = DisintegrationConfig Function(DisintegrationConfig c, double v);

class _Knob {
	const _Knob(this.label, this.min, this.max, this.get, this.set);

	final String label;
	final double min;
	final double max;
	final _Read get;
	final _Write set;
}

const _knobs = <_Knob>[
	_Knob('cellSize', 0.5, 60, _cs, _scs),
	_Knob('drift', 0, 300, _dr, _sdr),
	_Knob('lift', -100, 200, _li, _sli),
	_Knob('jitter', 0, 300, _ji, _sji),
	_Knob('spin', 0, 6, _sp, _ssp),
	_Knob('shrink', 0, 1, _sk, _ssk),
	_Knob('noiseScale', 0.002, 0.08, _ns, _sns),
	_Knob('turbulence', 0, 200, _tu, _stu),
	_Knob('radial', 0, 1, _ra, _sra),
	_Knob('softness', 0.02, 0.8, _so, _sso),
	_Knob('sweep', 0, 1, _sw, _ssw),
	_Knob('blur', 0, 30, _bl, _sbl),
	_Knob('fade', 0.2, 4, _fa, _sfa),
	_Knob('erodeRadius', 5, 80, _er, _ser),
	_Knob('erodeSpread', 0, 600, _eg, _seg),
	_Knob('erodeExpand', 0, 120, _ed, _sed),
	_Knob('erodeLife', 0.3, 6, _el, _sel),
	_Knob('erodeSwirl', 0, 150, _et, _set),
	_Knob('erodeVortex', 0, 150, _ev, _sev),
	_Knob('erodePush', 0, 0.2, _ep, _sep),
	_Knob('trailSpacing', 4, 40, _ts, _sts),
];

double _cs(DisintegrationConfig c) => c.cellSize;
DisintegrationConfig _scs(DisintegrationConfig c, double v) => c.copyWith(cellSize: v);
double _dr(DisintegrationConfig c) => c.drift;
DisintegrationConfig _sdr(DisintegrationConfig c, double v) => c.copyWith(drift: v);
double _li(DisintegrationConfig c) => c.lift;
DisintegrationConfig _sli(DisintegrationConfig c, double v) => c.copyWith(lift: v);
double _ji(DisintegrationConfig c) => c.jitter;
DisintegrationConfig _sji(DisintegrationConfig c, double v) => c.copyWith(jitter: v);
double _sp(DisintegrationConfig c) => c.spin;
DisintegrationConfig _ssp(DisintegrationConfig c, double v) => c.copyWith(spin: v);
double _sk(DisintegrationConfig c) => c.shrink;
DisintegrationConfig _ssk(DisintegrationConfig c, double v) => c.copyWith(shrink: v);
double _ns(DisintegrationConfig c) => c.noiseScale;
DisintegrationConfig _sns(DisintegrationConfig c, double v) => c.copyWith(noiseScale: v);
double _tu(DisintegrationConfig c) => c.turbulence;
DisintegrationConfig _stu(DisintegrationConfig c, double v) => c.copyWith(turbulence: v);
double _ra(DisintegrationConfig c) => c.radial;
DisintegrationConfig _sra(DisintegrationConfig c, double v) => c.copyWith(radial: v);
double _so(DisintegrationConfig c) => c.softness;
DisintegrationConfig _sso(DisintegrationConfig c, double v) => c.copyWith(softness: v);
double _sw(DisintegrationConfig c) => c.sweep;
DisintegrationConfig _ssw(DisintegrationConfig c, double v) => c.copyWith(sweep: v);
double _bl(DisintegrationConfig c) => c.blur;
DisintegrationConfig _sbl(DisintegrationConfig c, double v) => c.copyWith(blur: v);
double _fa(DisintegrationConfig c) => c.fade;
DisintegrationConfig _sfa(DisintegrationConfig c, double v) => c.copyWith(fade: v);
double _er(DisintegrationConfig c) => c.erodeRadius;
DisintegrationConfig _ser(DisintegrationConfig c, double v) => c.copyWith(erodeRadius: v);
double _eg(DisintegrationConfig c) => c.erodeSpread;
DisintegrationConfig _seg(DisintegrationConfig c, double v) => c.copyWith(erodeSpread: v);
double _ed(DisintegrationConfig c) => c.erodeExpand;
DisintegrationConfig _sed(DisintegrationConfig c, double v) => c.copyWith(erodeExpand: v);
double _el(DisintegrationConfig c) => c.erodeLifetime;
DisintegrationConfig _sel(DisintegrationConfig c, double v) => c.copyWith(erodeLifetime: v);
double _et(DisintegrationConfig c) => c.erodeSwirl;
DisintegrationConfig _set(DisintegrationConfig c, double v) => c.copyWith(erodeSwirl: v);
double _ev(DisintegrationConfig c) => c.erodeVortex;
DisintegrationConfig _sev(DisintegrationConfig c, double v) => c.copyWith(erodeVortex: v);
double _ep(DisintegrationConfig c) => c.erodePush;
DisintegrationConfig _sep(DisintegrationConfig c, double v) => c.copyWith(erodePush: v);
double _ts(DisintegrationConfig c) => c.trailSpacing;
DisintegrationConfig _sts(DisintegrationConfig c, double v) => c.copyWith(trailSpacing: v);

const _cards = <(String, String, List<Color>)>[
	('Snap', 'swipe me away', [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
	('Dust', 'or drag slowly', [Color(0xFF00B4DB), Color(0xFF0083B0)]),
	('Gone', 'and fling', [Color(0xFFF7971E), Color(0xFFFFD200)]),
];

class DisintegrationDemo extends StatefulWidget {
	const DisintegrationDemo({super.key});

	@override
	State<DisintegrationDemo> createState() => _DisintegrationDemoState();
}

class _DisintegrationDemoState extends State<DisintegrationDemo> with TickerProviderStateMixin {
	late final List<DisintegrationController> _effects = [
		for (var i = 0; i < _cards.length; i++) DisintegrationController(vsync: this),
	];
	final _gone = <int>{};
	final _firstCard = GlobalKey();
	DisintegrationMode _mode = DisintegrationMode.shards;
	DisintegrationConfig _config = DisintegrationConfig.shards;
	double _frozen = 0;
	double _angle = _debugAngle;
	bool? _panelOpen;

	/// A phone has no room beside a 260px panel; it starts closed there.
	bool get _panel => _panelOpen ?? MediaQuery.sizeOf(context).width > 700;

	@override
	void initState() {
		super.initState();
		if (_debugProgress < 0 && !_debugStroke) return;
		_mode = _debugMode;
		_config = DisintegrationConfig.of(_debugMode);
		_panelOpen = false;
		for (final effect in _effects) {
			effect.mode = _debugMode;
		}
		// The snapshot needs a painted boundary, so freeze only after the first frame.
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_debugStroke) {
				_syntheticStroke();
				return;
			}
			_freeze(_debugProgress);
			debugPrint('debug freeze: mode=${_debugMode.name} progress=$_debugProgress angle=$_debugAngle');
			_scheduleSnaps();
		});
	}

	/// Walks a diagonal across every card in real time, so the trail ages as a stroke would.
	void _syntheticStroke() {
		const from = Offset(18, 24);
		const to = Offset(132, 176);
		const steps = 15;
		for (final effect in _effects) {
			effect.beginDrag(from);
		}
		var i = 0;
		Timer.periodic(const Duration(milliseconds: 16), (timer) {
			i++;
			for (final effect in _effects) {
				effect.erode(Offset.lerp(from, to, i / steps)!);
			}
			if (i < steps) return;
			timer.cancel();
			debugPrint('debug stroke: mode=${_debugMode.name} points=${_effects.first.trail.points.length} progress=$_debugStrokeProgress');
			_scheduleSnaps();
			if (_debugStirAt >= 0) {
				Future<void>.delayed(Duration(milliseconds: (_debugStirAt * 1000).round()), _injectStir);
			}
			if (_debugStrokeProgress < 0) return;
			for (final effect in _effects) {
				effect.freeze(_debugStrokeProgress);
			}
		});
	}

	/// Real pointer events, so the stir goes through hit testing rather than around it.
	Future<void> _injectStir() async {
		final box = _firstCard.currentContext?.findRenderObject();
		if (box is! RenderBox) return;
		final origin = box.localToGlobal(Offset.zero);
		const from = Offset(15, 165);
		const to = Offset(235, 55);
		const steps = 8;
		const pointer = 7;
		var time = const Duration(seconds: 30);
		var last = origin + from;
		final binding = WidgetsBinding.instance;
		final view = View.of(context).viewId;
		binding.handlePointerEvent(PointerDownEvent(viewId: view, pointer: pointer, position: last, timeStamp: time));
		for (var i = 1; i <= steps; i++) {
			await Future<void>.delayed(const Duration(milliseconds: 16));
			time += const Duration(milliseconds: 16);
			final at = origin + Offset.lerp(from, to, i / steps)!;
			binding.handlePointerEvent(
				PointerMoveEvent(viewId: view, pointer: pointer, position: at, delta: at - last, timeStamp: time),
			);
			last = at;
		}
		binding.handlePointerEvent(PointerUpEvent(viewId: view, pointer: pointer, position: last, timeStamp: time));
		debugPrint('debug stir: trail=${_effects.first.trail.points.length} progress=${_effects.first.progress.toStringAsFixed(2)}');
	}

	@override
	void dispose() {
		for (final effect in _effects) {
			effect.dispose();
		}
		super.dispose();
	}

	void _setMode(DisintegrationMode mode) {
		setState(() {
			_mode = mode;
			_config = DisintegrationConfig.of(mode);
			for (final effect in _effects) {
				effect.mode = mode;
			}
		});
	}

	void _freeze(double progress) {
		setState(() {
			_frozen = progress;
			for (final effect in _effects) {
				effect
					..direction = Offset(math.cos(_angle), math.sin(_angle))
					..freeze(progress);
			}
		});
	}

	void _scheduleSnaps() {
		if (_debugSnapAt.isEmpty) return;
		final dpr = MediaQuery.devicePixelRatioOf(context);
		startSnapPump();
		var pending = _debugSnapAt.length;
		for (final at in _debugSnapAt) {
			Future<void>.delayed(Duration(milliseconds: (at * 1000).round()), () async {
				await writeSnap('${at.toStringAsFixed(2)}s', dpr);
				if (--pending == 0) stopSnapPump();
			});
		}
	}

	void _restore() {
		setState(() {
			_frozen = 0;
			_gone.clear();
			for (final effect in _effects) {
				effect.reset();
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				Positioned.fill(child: _sceneView()),
				if (_panel) Positioned(top: 0, right: 0, bottom: 0, child: SafeArea(child: _controls())),
				Positioned(
					top: 8,
					right: _panel ? 268 : 8,
					child: SafeArea(
						child: IconButton(
							icon: Icon(_panel ? Icons.chevron_right : Icons.tune, color: Colors.white),
							onPressed: () => setState(() => _panelOpen = !_panel),
						),
					),
				),
			],
		);
	}

	Widget _sceneView() {
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
							for (var i = 0; i < _cards.length; i++) _slot(i),
						],
					),
				),
			),
		);
	}

	Widget _slot(int index) {
		if (_gone.contains(index)) return const SizedBox(width: 150, height: 200);
		final (title, hint, colors) = _cards[index];
		return Disintegrate(
			key: index == 0 ? _firstCard : null,
			controller: _effects[index],
			config: _config,
			onDismissed: () => _onDismissed(index),
			child: _Card(title: title, hint: hint, colors: colors),
		);
	}

	void _onDismissed(int index) {
		// The debug slider parks progress at 1; the card must survive that.
		if (_frozen > 0) return;
		setState(() => _gone.add(index));
	}

	Widget _controls() {
		return Container(
			width: 260,
			color: const Color(0xCC101418),
			child: ListView(
				padding: const EdgeInsets.fromLTRB(0, 48, 0, 8),
				children: [
					_group('Mode'),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 12),
						child: Row(
							children: [
								for (final mode in DisintegrationMode.values)
									Expanded(
										child: GestureDetector(
											onTap: () => _setMode(mode),
											child: Container(
												margin: const EdgeInsets.symmetric(horizontal: 2),
												padding: const EdgeInsets.symmetric(vertical: 6),
												decoration: BoxDecoration(
													color: _mode == mode ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF),
													borderRadius: BorderRadius.circular(10),
												),
												child: Text(
													mode.name,
													textAlign: TextAlign.center,
													style: TextStyle(
														color: _mode == mode ? Colors.white : Colors.white54,
														fontSize: 11,
													),
												),
											),
										),
									),
							],
						),
					),
					_group('Debug'),
					_row('progress', _frozen, 0, 1, _freeze),
					_row('angle', _angle, -math.pi, math.pi, (v) {
						_angle = v;
						_freeze(_frozen);
					}),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
						child: Row(
							children: [
								TextButton(onPressed: _restore, child: const Text('Restore')),
								TextButton(
									onPressed: () {
										for (final effect in _effects) {
											effect.play(direction: Offset(math.cos(_angle), math.sin(_angle)));
										}
									},
									child: const Text('Play'),
								),
							],
						),
					),
					_group('Field'),
					for (final knob in _knobs)
						_row(knob.label, knob.get(_config), knob.min, knob.max, (v) {
							setState(() => _config = knob.set(_config, v));
						}),
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
							value.toStringAsFixed(value.abs() < 0.1 ? 3 : value.abs() < 10 ? 2 : 0),
							style: const TextStyle(color: Colors.white70, fontSize: 11),
						),
					),
				],
			),
		);
	}
}

class _Card extends StatelessWidget {
	const _Card({required this.title, required this.hint, required this.colors});

	final String title;
	final String hint;
	final List<Color> colors;

	@override
	Widget build(BuildContext context) {
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
					const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
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
