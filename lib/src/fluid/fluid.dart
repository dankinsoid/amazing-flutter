// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../snapshot/snapshot.dart';
import 'config.dart';
import 'controller.dart';
import 'solver.dart';

/// Turns [child] into dye of a Stable Fluids sim: solid until touched, then flow.
class Fluid extends StatefulWidget {
	const Fluid({
		super.key,
		required this.child,
		this.config = const FluidConfig(),
		this.controller,
		this.onFinished,
		this.enabled = true,
	});

	final Widget child;
	final FluidConfig config;

	/// Null builds a private controller; pass one to drive the effect from outside.
	final FluidController? controller;

	final VoidCallback? onFinished;

	/// False leaves the child alone; a passed controller still drives it.
	final bool enabled;

	@override
	State<Fluid> createState() => _FluidState();
}

class _FluidState extends State<Fluid> with SingleTickerProviderStateMixin {
	final ChildSnapshot _snapshot = ChildSnapshot();
	final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

	late final Ticker _ticker = createTicker(_tick);
	FluidController? _private;
	FluidSolver? _solver;
	Duration _last = Duration.zero;

	FluidController get _effect => widget.controller ?? (_private ??= FluidController());

	@override
	void initState() {
		super.initState();
		_applyConfig();
		_effect.addListener(_onEffect);
		FluidShaders.load().then((shaders) {
			if (!mounted) {
				shaders.dispose();
				return;
			}
			setState(() => _solver = FluidSolver(shaders));
			// The programs resolve a few frames in; a gesture may already be running.
			_onEffect();
		});
	}

	@override
	void didUpdateWidget(Fluid oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.controller != widget.controller) {
			(oldWidget.controller ?? _private)?.removeListener(_onEffect);
			_effect.addListener(_onEffect);
		}
		_applyConfig();
	}

	@override
	void dispose() {
		_effect.removeListener(_onEffect);
		_ticker.dispose();
		_private?.dispose();
		_snapshot.dispose();
		final solver = _solver;
		if (solver != null) {
			solver.dispose();
			solver.shaders.dispose();
		}
		_repaint.dispose();
		super.dispose();
	}

	void _applyConfig() {
		_effect
			..lifetime = widget.config.lifetime
			..fadeOut = widget.config.fadeOut;
	}

	void _onEffect() {
		final solver = _solver;
		if (solver == null) return;
		if (!_effect.isActive) return;
		if (_snapshot.isFrozen) return;
		_snapshot.capture();
		final image = _snapshot.image;
		if (image == null) return;
		solver.begin(image, MediaQuery.devicePixelRatioOf(context), widget.config);
		_last = Duration.zero;
		if (!_ticker.isActive) _ticker.start();
	}

	void _tick(Duration elapsed) {
		final solver = _solver;
		if (solver == null || !solver.isReady) return;
		// Dobryakov's cap: a long frame must not let advection jump a whole cell.
		final raw = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
		final dt = raw.clamp(1 / 1000, 1 / 60);
		_last = elapsed;

		solver.beginFrame();
		for (final (at, delta) in _effect.takeSplats()) {
			solver.splat(at, delta);
		}
		solver.step(dt);
		_effect.passes = solver.passes;
		final alive = _effect.advance(dt);
		_repaint.value++;
		if (alive) return;
		_finish();
	}

	void _finish() {
		_ticker.stop();
		_solver?.end();
		_snapshot.release();
		widget.onFinished?.call();
	}

	ChildSnapshotPainter _painter(ui.Image snapshot, double spread) => _FluidPainter(
		snapshot: snapshot,
		spread: spread,
		solver: _solver,
		effect: _effect,
		repaint: _repaint,
	);

	void _onStart(DragStartDetails details) => _effect.begin(details.localPosition);

	void _onUpdate(DragUpdateDetails details) => _effect.move(details.localPosition);

	void _onEnd(DragEndDetails details) => _effect.end();

	@override
	Widget build(BuildContext context) {
		final host = SnapshotHost(
			controller: _snapshot,
			spread: widget.config.spread,
			painterBuilder: _painter,
			child: widget.child,
		);
		if (!widget.enabled) return host;
		return GestureDetector(
			onPanStart: _onStart,
			onPanUpdate: _onUpdate,
			onPanEnd: _onEnd,
			onPanCancel: _effect.end,
			child: host,
		);
	}
}

class _FluidPainter extends ChildSnapshotPainter {
	_FluidPainter({
		required super.snapshot,
		required super.spread,
		required this.solver,
		required this.effect,
		required Listenable repaint,
	}) : super(repaint: repaint);

	final FluidSolver? solver;
	final FluidController effect;

	@override
	void paint(Canvas canvas, Size size) {
		final solver = this.solver;
		if (solver == null || !solver.isReady) {
			// A frame or two before the programs resolve, or after the sim is torn down.
			canvas.drawImageRect(
				snapshot,
				Rect.fromLTWH(0, 0, snapshot.width.toDouble(), snapshot.height.toDouble()),
				childRect(size),
				Paint(),
			);
			return;
		}
		solver.paint(canvas, size, effect.opacity);
	}

	@override
	bool shouldRepaint(_FluidPainter old) => old.solver != solver || old.snapshot != snapshot;
}
