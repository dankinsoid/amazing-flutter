// @ai-generated(solo)

import 'dart:async';

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';

import 'snap.dart';

// Screenshot hooks: a non-null light parks it and ignores live input.
const Offset? _debugLight = null;
// Seconds from launch at which a snap is written; see snap.dart.
const _debugSnapAt = <double>[];

/// label, base tone.
const _tones = <(String, Color)>[
	('Pink', Color(0xFFE8A0C0)),
	('Champagne', Color(0xFFD8C39A)),
	('Charcoal', Color(0xFF1C1C22)),
	('Snow', Color(0xFFF2F2F4)),
];

class GlitterDemo extends StatefulWidget {
	const GlitterDemo({super.key});

	@override
	State<GlitterDemo> createState() => _GlitterDemoState();
}

class _GlitterDemoState extends State<GlitterDemo> with SingleTickerProviderStateMixin {
	// Both panels share one light, the way two bars of the same physical surface would.
	late final GlitterController _light = GlitterController(vsync: this, config: _config);

	int _tone = 0;
	double _flakeScale = 1;
	double _density = 1;
	double _gain = 1;
	double _rainbow = 1;
	bool _panelOpen = false;

	GlitterConfig get _config => GlitterConfig(
		base: _tones[_tone].$2,
		flakeScale: _flakeScale,
		density: _density,
		gain: _gain,
		rainbow: _rainbow,
	);

	@override
	void initState() {
		super.initState();
		final parked = _debugLight;
		if (parked != null) _light.aimAt(parked);
		if (_debugSnapAt.isEmpty) return;
		_panelOpen = false;
		// An occluded macOS window gets no frames at all, so pump from the first tick.
		startSnapPump();
		for (final at in _debugSnapAt) {
			Timer(Duration(milliseconds: (at * 1000).round()), () async {
				if (parked != null) _light.aimAt(parked);
				await writeSnap('glitter_$at', MediaQuery.devicePixelRatioOf(context));
				if (at == _debugSnapAt.last) stopSnapPump();
			});
		}
	}

	@override
	void dispose() {
		_light.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final config = _config;
		_light.config = config;
		final onSurface = ThemeData.estimateBrightnessForColor(config.base) == Brightness.dark
			? Colors.white
			: Colors.black87;

		return Stack(
			children: [
				Column(
					children: [
						GlitterSurface(
							config: config,
							controller: _light,
							// One sensor subscription feeds the shared light; a second would only duplicate it.
							sensors: false,
							child: SizedBox(height: 110, child: _topBar(onSurface)),
						),
						Expanded(
							child: ColoredBox(
								color: Colors.black,
								child: Center(
									child: Text('camera preview', style: TextStyle(color: Colors.white24)),
								),
							),
						),
						GlitterSurface(
							config: config,
							controller: _light,
							child: SizedBox(height: 210, child: _bottomBar(onSurface)),
						),
					],
				),
				Positioned(right: 8, bottom: 8, child: SafeArea(child: _knobs())),
			],
		);
	}

	Widget _topBar(Color onSurface) {
		return SafeArea(
			bottom: false,
			child: Align(
				alignment: Alignment.bottomRight,
				child: Padding(
					padding: const EdgeInsets.only(right: 20, bottom: 16),
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							for (final icon in [Icons.bolt, Icons.motion_photos_on, Icons.tune, Icons.settings])
								Padding(
									padding: const EdgeInsets.only(left: 22),
									child: Icon(icon, color: onSurface, size: 20),
								),
						],
					),
				),
			),
		);
	}

	Widget _bottomBar(Color onSurface) {
		return Center(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							for (var i = 0; i < 4; i++)
								Container(
									margin: const EdgeInsets.symmetric(horizontal: 5),
									width: 44,
									height: 44,
									decoration: BoxDecoration(
										color: onSurface.withValues(alpha: 0.12),
										borderRadius: BorderRadius.circular(10),
									),
								),
						],
					),
					const SizedBox(height: 24),
					Container(
						width: 68,
						height: 68,
						decoration: BoxDecoration(
							shape: BoxShape.circle,
							border: Border.all(color: onSurface, width: 4),
						),
					),
				],
			),
		);
	}

	Widget _knobs() {
		if (!_panelOpen) {
			return FloatingActionButton.small(
				onPressed: () => setState(() => _panelOpen = true),
				child: const Icon(Icons.tune),
			);
		}
		return Container(
			width: 260,
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: const Color(0xCC101418),
				borderRadius: BorderRadius.circular(16),
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							for (var i = 0; i < _tones.length; i++)
								GestureDetector(
									onTap: () => setState(() => _tone = i),
									child: Container(
										margin: const EdgeInsets.only(right: 8),
										width: 26,
										height: 26,
										decoration: BoxDecoration(
											color: _tones[i].$2,
											shape: BoxShape.circle,
											border: Border.all(
												color: _tone == i ? Colors.white : Colors.transparent,
												width: 2,
											),
										),
									),
								),
							const Spacer(),
							GestureDetector(
								onTap: () => setState(() => _panelOpen = false),
								child: const Icon(Icons.close, color: Colors.white54, size: 18),
							),
						],
					),
					_slider('flakeScale', _flakeScale, 0.4, 3, (v) => _flakeScale = v),
					_slider('density', _density, 0.1, 2, (v) => _density = v),
					_slider('gain', _gain, 0.2, 3, (v) => _gain = v),
					_slider('rainbow', _rainbow, 0, 1, (v) => _rainbow = v),
				],
			),
		);
	}

	Widget _slider(String label, double value, double min, double max, ValueChanged<double> set) {
		return Row(
			children: [
				SizedBox(
					width: 76,
					child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
				),
				Expanded(
					child: Slider(
						value: value.clamp(min, max),
						min: min,
						max: max,
						onChanged: (v) => setState(() => set(v)),
					),
				),
				SizedBox(
					width: 32,
					child: Text(
						value.toStringAsFixed(2),
						style: const TextStyle(color: Colors.white38, fontSize: 10),
					),
				),
			],
		);
	}
}
