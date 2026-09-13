// @ai-generated(solo)

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';

import 'tuning_panel.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
	const DemoApp({super.key});

	@override
	Widget build(BuildContext context) {
		return const MaterialApp(
			debugShowCheckedModeBanner: false,
			home: Scaffold(body: LiquidGlassDemo()),
		);
	}
}

class LiquidGlassDemo extends StatefulWidget {
	const LiquidGlassDemo({super.key});

	@override
	State<LiquidGlassDemo> createState() => _LiquidGlassDemoState();
}

class _LiquidGlassDemoState extends State<LiquidGlassDemo> {
	static const _blobRadius = 70.0;

	Offset _blob = const Offset(200, 300);
	final _ripples = GlassRipples();
	bool _dragging = false;
	GlassMaterial _material = const GlassMaterial();
	bool _panel = true;

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				Positioned.fill(child: _scene(context)),
				if (_panel)
					Positioned(
						top: 0,
						right: 0,
						bottom: 0,
						child: TuningPanel(material: _material, onChanged: (m) => setState(() => _material = m)),
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

	Widget _scene(BuildContext context) {
		final size = MediaQuery.sizeOf(context);
		final barY = size.height - 60;
		return GestureDetector(
			onTapDown: (d) => setState(() => _ripples.tap(d.localPosition)),
			onPanStart: (d) => _dragging = (d.localPosition - _blob).distance < _blobRadius,
			onPanUpdate: (d) => setState(() {
				if (_dragging) {
					_blob += d.delta;
				} else {
					_ripples.drag(d.localPosition);
				}
			}),
			onPanEnd: (_) => _ripples.end(),
			child: LiquidGlass(
				shapes: [
					GlassCapsule(a: Offset(48, barY), b: Offset(size.width - 48, barY), radius: 32),
					GlassCircle(center: _blob, radius: _blobRadius),
					GlassRoundedBox(
						rect: Rect.fromCenter(center: Offset(size.width / 2, 140), width: 260, height: 90),
						cornerRadius: 28,
					),
				],
				touches: _ripples.touches,
				material: _material,
				child: const _Backdrop(),
			),
		);
	}
}

class _Backdrop extends StatelessWidget {
	const _Backdrop();

	@override
	Widget build(BuildContext context) {
		return DecoratedBox(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [Color(0xFF1E2A5A), Color(0xFF6A2C70), Color(0xFFF08A5D)],
				),
			),
			child: Stack(
				children: [
					for (var i = 0; i < 12; i++)
						Positioned(
							left: (i * 137) % 360 + 20.0,
							top: (i * 211) % 700 + 40.0,
							child: Container(
								width: 40 + (i % 4) * 20,
								height: 40 + (i % 4) * 20,
								decoration: BoxDecoration(
									color: Colors.primaries[i % Colors.primaries.length],
									shape: BoxShape.circle,
								),
							),
						),
					Padding(
						padding: const EdgeInsets.fromLTRB(24, 220, 24, 0),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								for (var i = 0; i < 9; i++)
									Padding(
										padding: const EdgeInsets.only(bottom: 10),
										child: Text(
											'Liquid glass over live content — line ${i + 1}',
											style: const TextStyle(color: Colors.white, fontSize: 18),
										),
									),
							],
						),
					),
				],
			),
		);
	}
}
