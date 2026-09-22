// @ai-generated(solo)

import 'package:flutter/material.dart';

import 'disintegration_demo.dart';
import 'fluid_demo.dart';
import 'holo_demo.dart';
import 'liquid_glass_demo.dart';
import 'snap.dart';

void main() => runApp(RepaintBoundary(key: snapKey, child: const DemoApp()));

class DemoApp extends StatelessWidget {
	const DemoApp({super.key});

	@override
	Widget build(BuildContext context) {
		return const MaterialApp(
			debugShowCheckedModeBanner: false,
			home: Scaffold(body: _Home()),
		);
	}
}

class _Home extends StatefulWidget {
	const _Home();

	@override
	State<_Home> createState() => _HomeState();
}

/// Screenshot hook: which demo the app opens on.
const _debugTab = 0;

class _HomeState extends State<_Home> {
	static const _titles = ['Liquid glass', 'Disintegration', 'Fluid', 'Holo'];
	int _index = _debugTab;

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				Positioned.fill(
					child: IndexedStack(
						index: _index,
						children: const [LiquidGlassDemo(), DisintegrationDemo(), FluidDemo(), HoloDemo()],
					),
				),
				Positioned(top: 8, left: 8, child: SafeArea(child: _switcher())),
			],
		);
	}

	Widget _switcher() {
		return Container(
			decoration: BoxDecoration(
				color: const Color(0xCC101418),
				borderRadius: BorderRadius.circular(18),
			),
			padding: const EdgeInsets.all(4),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					for (var i = 0; i < _titles.length; i++)
						GestureDetector(
							onTap: () => setState(() => _index = i),
							child: Container(
								padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
								decoration: BoxDecoration(
									color: _index == i ? const Color(0x33FFFFFF) : Colors.transparent,
									borderRadius: BorderRadius.circular(14),
								),
								child: Text(
									_titles[i],
									style: TextStyle(
										color: _index == i ? Colors.white : Colors.white60,
										fontSize: 12,
									),
								),
							),
						),
				],
			),
		);
	}
}
