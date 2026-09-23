// @ai-generated(solo)

import 'dart:math' as math;

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';

import 'snap.dart';
import 'tuning_panel.dart';

const _photo = 'assets/backdrop.jpg';

/// Screenshot hooks: which scene the tab opens on, and whether the demo chrome is drawn.
const _debugScene = _Scene.showcase;
const _debugChrome = true;
// The slow drift keeps content moving under the glass without a hand on screen.
const _drift = true;
// Seconds from launch at which a snap of each scene is written; see snap.dart.
const _debugSnapAt = <double>[];
// Frost sweep for the snapshot pass: one showcase frame per sigma.
const _debugFrost = <double>[0, 8, 16];

enum _Scene { showcase, presets }

/// name, hint, material. One tile per entry in the presets scene.
final _presets = <(String, String, GlassMaterial)>[
	(
		'Clear',
		'thin, dispersive',
		const GlassMaterial(edgeWidth: 38, height: 20, thickness: 66, aberration: 0.42, rim: 0.6, rimWidth: 9, innerShadow: 0.1, tintStrength: 0.04),
	),
	(
		'Frosted',
		'blurred backdrop',
		const GlassMaterial(edgeWidth: 38, height: 18, thickness: 40, aberration: 0.3, frostSigma: 14, specular: 0.35, rim: 0.5, rimWidth: 9, tintStrength: 0.16, saturation: 1.05),
	),
	(
		'Lens',
		'deep, magnifying',
		const GlassMaterial(edgeWidth: 52, height: 30, thickness: 120, aberration: 0.6, specular: 0.9, shininess: 80, rim: 0.7, rimWidth: 10, innerShadow: 0.08),
	),
	(
		'Bevel',
		'hard machined edge',
		const GlassMaterial(edgeWidth: 14, height: 16, thickness: 44, aberration: 0.35, rim: 1, rimWidth: 4, innerShadow: 0.45, specular: 0.85, shininess: 70),
	),
	(
		'Tinted',
		'coloured body',
		const GlassMaterial(edgeWidth: 38, height: 20, thickness: 66, aberration: 0.3, tint: Color(0xFF5BC8FF), tintStrength: 0.32, saturation: 1.5, rim: 0.6, rimWidth: 9),
	),
	(
		'Droplet',
		'cast shadow, caustic',
		const GlassMaterial(smoothK: 8, edgeWidth: 44, height: 28, thickness: 86, aberration: 0.5, shadow: 0.55, floorScale: 1.4, caustic: 0.7, rim: 0.8, rimWidth: 8),
	),
];
class LiquidGlassDemo extends StatefulWidget {
	const LiquidGlassDemo({super.key});

	@override
	State<LiquidGlassDemo> createState() => _LiquidGlassDemoState();
}

class _LiquidGlassDemoState extends State<LiquidGlassDemo> with TickerProviderStateMixin {
	static const _blobRadius = 74.0;
	static const _panelWidth = 260.0;

	late final ElasticBody _blob = ElasticBody(vsync: this, position: const Offset(190, 330))
		..addListener(() => setState(() {}));
	late final AnimationController _pan = AnimationController(vsync: this, duration: const Duration(seconds: 28));
	final _ripples = GlassRipples();
	bool _dragging = false;
	// edgeWidth stays under the inradius of the thinnest shape: a ramp wider than that
	// never reaches the plateau, and the leftover crease along the medial axis reads as
	// a hard specular line down the middle of a capsule.
	GlassMaterial _material = const GlassMaterial(
		edgeWidth: 26,
		height: 24,
		thickness: 88,
		aberration: 0.45,
		specular: 0.5,
		shininess: 50,
		rim: 0.6,
		rimWidth: 8,
		fresnel: 0.3,
		innerShadow: 0.14,
		tintStrength: 0.06,
		saturation: 1.15,
		frostSigma: 10,
	);
	_Scene _scene = _debugScene;
	bool? _panelOpen;

	/// A phone has no room beside the panel; it starts closed there.
	bool get _panel => _scene == _Scene.showcase && (_panelOpen ?? MediaQuery.sizeOf(context).width > 700);

	@override
	void initState() {
		super.initState();
		if (_drift) _pan.repeat(reverse: true);
		if (_debugSnapAt.isNotEmpty) _scheduleSnaps();
	}

	void _scheduleSnaps() {
		_panelOpen = false;
		// An occluded macOS window gets no frames at all, so pump from the first tick.
		startSnapPump();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			final dpr = MediaQuery.devicePixelRatioOf(context);
			for (final sigma in _debugFrost) {
				setState(() {
					_scene = _Scene.showcase;
					_material = _material.copyWith(frostSigma: sigma);
				});
				await Future<void>.delayed(const Duration(milliseconds: 1200));
				await writeSnap('glass_frost_${sigma.toStringAsFixed(0)}', dpr);
			}
			setState(() => _scene = _Scene.presets);
			await Future<void>.delayed(const Duration(milliseconds: 1200));
			await writeSnap('glass_presets', dpr);
			stopSnapPump();
		});
	}

	@override
	void dispose() {
		_pan.dispose();
		_blob.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final inset = _panel ? _panelWidth : 0.0;
		return Stack(
			children: [
				Positioned.fill(
					child: Padding(
						padding: EdgeInsets.only(right: inset),
						child: switch (_scene) {
							_Scene.showcase => _showcase(),
							_Scene.presets => _presetSheet(),
						},
					),
				),
				if (_panel)
					Positioned(
						top: 0,
						right: 0,
						bottom: 0,
						child: TuningPanel(
							material: _material,
							body: _blob,
							onChanged: (m) => setState(() => _material = m),
							onBodyChanged: () => setState(() {}),
						),
					),
				if (_debugChrome) ...[
					Positioned(left: 12, bottom: 12, child: SafeArea(child: _sceneSwitch())),
					if (_scene == _Scene.showcase)
						Positioned(
							top: 8,
							right: _panel ? _panelWidth + 8 : 8,
							child: SafeArea(
								child: IconButton(
									icon: Icon(_panel ? Icons.chevron_right : Icons.tune, color: Colors.white70),
									onPressed: () => setState(() => _panelOpen = !_panel),
								),
							),
						),
				],
			],
		);
	}

	Widget _sceneSwitch() {
		return Container(
			decoration: BoxDecoration(color: const Color(0x99101418), borderRadius: BorderRadius.circular(16)),
			padding: const EdgeInsets.all(3),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					for (final scene in _Scene.values)
						GestureDetector(
							onTap: () => setState(() => _scene = scene),
							child: AnimatedContainer(
								duration: const Duration(milliseconds: 160),
								padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
								decoration: BoxDecoration(
									color: _scene == scene ? const Color(0x2EFFFFFF) : Colors.transparent,
									borderRadius: BorderRadius.circular(13),
								),
								child: Text(
									scene == _Scene.showcase ? 'Showcase' : 'Presets',
									style: TextStyle(
										color: _scene == scene ? Colors.white : Colors.white54,
										fontSize: 11,
										letterSpacing: 0.3,
									),
								),
							),
						),
				],
			),
		);
	}

	// ---------------------------------------------------------------- showcase

	Widget _showcase() {
		return LayoutBuilder(
			builder: (context, constraints) {
				final size = constraints.biggest;
				final safe = MediaQuery.paddingOf(context);
				final pillWidth = math.min(size.width - 56, 400.0);
				final dockWidth = math.min(size.width - 64, 340.0);
				final pillY = safe.top + 104;
				final dockY = size.height - safe.bottom - 52;
				final centre = size.width / 2;
				return GestureDetector(
					onTapDown: (d) => setState(() => _ripples.tap(d.localPosition)),
					onPanStart: (d) {
						_dragging = (d.localPosition - _blob.position).distance < _blobRadius;
						if (_dragging) _blob.grab(d.localPosition);
					},
					onPanUpdate: (d) => setState(() {
						if (_dragging) {
							_blob.drag(d.localPosition);
						} else {
							_ripples.drag(d.localPosition);
						}
					}),
					onPanEnd: (_) {
						if (_dragging) _blob.release();
						_ripples.end();
					},
					child: Stack(
						fit: StackFit.expand,
						children: [
							LiquidGlass(
								shapes: [
									GlassCapsule(
										a: Offset(centre - pillWidth / 2 + 28, pillY),
										b: Offset(centre + pillWidth / 2 - 28, pillY),
										radius: 28,
									),
									GlassCapsule(
										a: Offset(centre - dockWidth / 2 + 34, dockY),
										b: Offset(centre + dockWidth / 2 - 34, dockY),
										radius: 34,
									),
									GlassCircle(center: _blob.position, radius: _blobRadius, deform: _blob.deform),
								],
								touches: _ripples.touches,
								material: _material,
								child: _Gallery(pan: _pan, dockTop: dockY - 29),
							),
							// Labels ride on top of the glass; only the gallery below refracts.
							Positioned(
								top: pillY - 28,
								left: centre - pillWidth / 2,
								width: pillWidth,
								height: 56,
								child: const _SearchLabel(),
							),
							Positioned(
								top: dockY - 34,
								left: centre - dockWidth / 2,
								width: dockWidth,
								height: 68,
								child: const _DockLabel(),
							),
						],
					),
				);
			},
		);
	}

	// ----------------------------------------------------------------- presets

	/// The shader reads screen coordinates, so every swatch lives in one full-screen
	/// pass stack: the photo crops paint first, then one glass layer per material.
	Widget _presetSheet() {
		return LayoutBuilder(
			builder: (context, constraints) {
				final grid = _Grid(constraints.biggest, MediaQuery.paddingOf(context), _presets.length);
				var scene = _swatchBackdrop(grid);
				for (var i = 0; i < _presets.length; i++) {
					scene = LiquidGlass(
						shapes: [GlassRoundedBox(rect: grid.glassAt(i), cornerRadius: 30)],
						material: _presets[i].$3,
						child: scene,
					);
				}
				return Stack(
					fit: StackFit.expand,
					children: [scene, _swatchLabels(grid)],
				);
			},
		);
	}

	Widget _swatchBackdrop(_Grid grid) {
		return ColoredBox(
			color: const Color(0xFF0B0D12),
			child: Stack(
				children: [
					Positioned(
						top: grid.headerTop,
						left: 0,
						right: 0,
						child: const Column(
							children: [
								Text(
									'One shader, one surface',
									style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
								),
								SizedBox(height: 6),
								Text(
									'The same backdrop under six GlassMaterial settings',
									style: TextStyle(color: Colors.white38, fontSize: 12),
								),
							],
						),
					),
					for (var i = 0; i < _presets.length; i++)
						Positioned.fromRect(
							rect: grid.tileAt(i),
							child: Container(
								decoration: BoxDecoration(
									borderRadius: BorderRadius.circular(20),
									border: Border.all(color: const Color(0x14FFFFFF)),
								),
								child: ClipRRect(
									borderRadius: BorderRadius.circular(19),
									child: const _Crop(width: 420, height: 570, focus: Alignment(-0.45, -0.1)),
								),
							),
						),
				],
			),
		);
	}

	Widget _swatchLabels(_Grid grid) {
		return Stack(
			children: [
				for (var i = 0; i < _presets.length; i++)
					Positioned(
						top: grid.tileAt(i).bottom + 9,
						left: grid.tileAt(i).left,
						width: grid.tile,
						child: Column(
							children: [
								Text(
									_presets[i].$1,
									style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
								),
								const SizedBox(height: 2),
								Text(_presets[i].$2, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
							],
						),
					),
			],
		);
	}
}

/// Swatch placement in screen coordinates; both the crops and the glass shapes read it.
class _Grid {
	_Grid(Size size, EdgeInsets safe, int count)
		: columns = _columnsFor(size.width, count),
			tile = _tileFor(size.width, _columnsFor(size.width, count)) {
		final rows = (count / columns).ceil();
		final height = _header + rows * (tile + _caption) + (rows - 1) * gap;
		headerTop = math.max(safe.top + 56, (size.height - height) / 2);
		top = headerTop + _header;
		left = (size.width - (columns * tile + (columns - 1) * gap)) / 2;
	}

	static const gap = 22.0;
	static const _caption = 46.0;
	static const _header = 108.0;

	final int columns;
	final double tile;
	late final double headerTop;
	late final double top;
	late final double left;

	static int _columnsFor(double width, int count) =>
		math.max(2, math.min(count, ((width - 40 + gap) / (152 + gap)).floor()));

	static double _tileFor(double width, int columns) =>
		math.min(152, (width - 40 - (columns - 1) * gap) / columns);

	Rect tileAt(int index) => Rect.fromLTWH(
		left + (index % columns) * (tile + gap),
		top + (index ~/ columns) * (tile + _caption + gap),
		tile,
		tile,
	);

	/// Inset from the swatch so the crop stays visible around the glass.
	Rect glassAt(int index) => tileAt(index).deflate(tile * 0.16);
}

/// A fixed-size render of the photo, cropped by the surrounding box.
class _Crop extends StatelessWidget {
	const _Crop({required this.width, required this.height, required this.focus});

	final double width;
	final double height;
	final Alignment focus;

	@override
	Widget build(BuildContext context) {
		return OverflowBox(
			maxWidth: width,
			maxHeight: height,
			alignment: focus,
			child: SizedBox(
				width: width,
				height: height,
				child: Image.asset(_photo, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
			),
		);
	}
}

/// What the glass refracts: the photo, its caption, and a strip of crops.
class _Gallery extends StatelessWidget {
	const _Gallery({required this.pan, required this.dockTop});

	final Animation<double> pan;
	/// Top edge of the dock capsule; the strip tucks under it.
	final double dockTop;

	@override
	Widget build(BuildContext context) {
		return Stack(
			fit: StackFit.expand,
			children: [
				AnimatedBuilder(
					animation: pan,
					builder: (context, child) {
						final t = Curves.easeInOut.transform(pan.value);
						return Transform.scale(
							scale: 1.14,
							child: Image.asset(
								_photo,
								fit: BoxFit.cover,
								alignment: Alignment(-0.35 + t * 0.7, 0.4 - t * 0.5),
								filterQuality: FilterQuality.medium,
							),
						);
					},
				),
				const DecoratedBox(
					decoration: BoxDecoration(
						gradient: LinearGradient(
							begin: Alignment.center,
							end: Alignment.bottomCenter,
							stops: [0, 0.55, 1],
							colors: [Color(0x00000000), Color(0x73000000), Color(0xE6000000)],
						),
					),
				),
				Positioned(
					left: 26,
					right: 26,
					top: dockTop - 138,
					child: const Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								'Lakeshore Drive',
								style: TextStyle(
									color: Colors.white,
									fontSize: 30,
									fontWeight: FontWeight.w600,
									letterSpacing: -0.4,
									shadows: _chromeShadow,
								),
							),
							SizedBox(height: 4),
							Text(
								'30 s · f/11 · ISO 64 — 18 frames',
								style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4, shadows: _chromeShadow),
							),
						],
					),
				),
				Positioned(
					left: 26,
					right: 26,
					top: dockTop - 46,
					height: 66,
					child: const _Strip(),
				),
			],
		);
	}
}

/// Hard-edged thumbnails: what makes the refraction at the dock readable.
class _Strip extends StatelessWidget {
	const _Strip();

	static const _focus = [
		Alignment(-0.6, -0.1),
		Alignment(-0.25, 0.35),
		Alignment(0.1, -0.45),
		Alignment(0.45, 0.2),
		Alignment(0.8, -0.3),
	];

	@override
	Widget build(BuildContext context) {
		return Row(
			children: [
				for (final focus in _focus)
					Expanded(
						child: Padding(
							padding: const EdgeInsets.only(right: 8),
							child: ClipRRect(
								borderRadius: BorderRadius.circular(10),
								child: _Crop(width: 300, height: 400, focus: focus),
							),
						),
					),
			],
		);
	}
}

/// Chrome reads against blown-out highlights only if it carries its own shadow;
/// a tint dark enough to do the same job flattens the refraction everywhere else.
const _chromeShadow = [Shadow(color: Color(0xCC000914), blurRadius: 10)];

class _SearchLabel extends StatelessWidget {
	const _SearchLabel();

	@override
	Widget build(BuildContext context) {
		return const IgnorePointer(
			child: Center(child: Icon(Icons.search, color: Colors.white, size: 20, shadows: _chromeShadow)),
		);
	}
}

class _DockLabel extends StatelessWidget {
	const _DockLabel();

	static const _icons = [
		Icons.photo_library_outlined,
		Icons.collections_bookmark_outlined,
		Icons.favorite_border,
		Icons.person_outline,
	];

	@override
	Widget build(BuildContext context) {
		return IgnorePointer(
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceEvenly,
				children: [
					for (var i = 0; i < _icons.length; i++)
						Icon(
							_icons[i],
							color: Colors.white,
							size: 22,
							shadows: _chromeShadow,
						),
				],
			),
		);
	}
}
