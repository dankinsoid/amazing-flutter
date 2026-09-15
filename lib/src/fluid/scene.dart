// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'controller.dart';
import 'solver.dart';

/// One Stable Fluids domain over the whole subtree; `Fluid` children stamp dye into it.
class FluidScene extends StatefulWidget {
	const FluidScene({
		super.key,
		required this.child,
		this.config = const FluidConfig(),
		this.controller,
		this.enabled = true,
	});

	final Widget child;
	final FluidConfig config;

	/// Null builds a private controller; pass one to drive the scene from outside.
	final FluidSceneController? controller;

	/// False stops pointers from stirring; a passed controller still drives it.
	final bool enabled;

	static FluidSceneState? of(BuildContext context) =>
		context.dependOnInheritedWidgetOfExactType<_SceneScope>()?.state;

	@override
	State<FluidScene> createState() => FluidSceneState();
}

class FluidSceneState extends State<FluidScene> with SingleTickerProviderStateMixin {
	final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
	final List<VoidCallback> _stamped = <VoidCallback>[];

	late final Ticker _ticker = createTicker(_tick);
	FluidSceneController? _private;
	FluidSolver? _solver;
	FluidConfig? _grid;
	Duration _last = Duration.zero;

	FluidSceneController get controller => widget.controller ?? (_private ??= FluidSceneController());

	/// True once the dye field exists; pointers only stir a scene that has dye.
	bool get isReady => _solver?.isReady ?? false;

	/// True once the programs have resolved; until then a stamp is refused.
	bool get canStamp => _solver != null;

	double get devicePixelRatio => MediaQuery.devicePixelRatioOf(context);

	@override
	void initState() {
		super.initState();
		_applyConfig();
		FluidShaders.load().then((shaders) {
			if (!mounted) {
				shaders.dispose();
				return;
			}
			setState(() => _solver = FluidSolver(shaders));
		});
	}

	@override
	void didUpdateWidget(FluidScene oldWidget) {
		super.didUpdateWidget(oldWidget);
		_applyConfig();
	}

	@override
	void dispose() {
		_ticker.dispose();
		_private?.dispose();
		final solver = _solver;
		if (solver != null) {
			solver.dispose();
			solver.shaders.dispose();
		}
		_repaint.dispose();
		super.dispose();
	}

	void _applyConfig() {
		controller
			..settleDelay = widget.config.settleDelay
			..settleRamp = widget.config.settleRamp
			..settleDecay = widget.config.settleDecay;
		_solver?.adopt(widget.config);
	}

	/// [box] in scene-local logical px; null while either box is unlaid.
	Rect? rectOf(RenderBox box) {
		final self = context.findRenderObject();
		if (self is! RenderBox || !self.hasSize || !box.hasSize || !box.attached) return null;
		return box.localToGlobal(Offset.zero, ancestor: self) & box.size;
	}

	/// Composites [snapshot] into the dye; the solver frees it. False leaves the child live.
	bool stamp(ui.Image snapshot, Rect rect) {
		final solver = _solver;
		final self = context.findRenderObject();
		if (solver == null || self is! RenderBox || !self.hasSize) return false;
		if (!solver.isReady) {
			solver.begin(self.size, devicePixelRatio, widget.config);
			_grid = widget.config;
		}
		solver.stamp(snapshot, rect);
		controller.wake();
		if (!_ticker.isActive) {
			_last = Duration.zero;
			_ticker.start();
		}
		setState(() {});
		return true;
	}

	/// Restores every stamped child when the field dies.
	void attach(VoidCallback onEnd) => _stamped.add(onEnd);

	void detach(VoidCallback onEnd) => _stamped.remove(onEnd);

	void _tick(Duration elapsed) {
		final solver = _solver;
		if (solver == null || !solver.isReady) return;
		final self = context.findRenderObject();
		// Geometry is baked into the buffers; a resize or a grid change restarts the field.
		if (self is! RenderBox ||
			!self.hasSize ||
			self.size != solver.sceneSize ||
			!(_grid?.sameGrid(widget.config) ?? true)) {
			_finish();
			return;
		}
		// Dobryakov's cap: a long frame must not let advection jump a whole cell.
		final raw = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
		_last = elapsed;
		final dt = raw.clamp(1 / 1000, 1 / 60);

		solver
			..adopt(widget.config)
			..beginFrame();
		// Settling is a real-time process; only the sim is slowed by the cap.
		final real = raw.clamp(1 / 1000, 0.1);
		final alive = controller.advance(real);
		for (final (at, delta) in controller.takeSplats()) {
			solver.splat(at, delta);
		}
		solver.step(dt, real, controller.settle);
		controller
			..passes = solver.passes
			..liveImages = solver.liveImages;
		_repaint.value++;
		if (alive) return;
		_finish();
	}

	void _finish() {
		_ticker.stop();
		_grid = null;
		_solver?.end();
		controller.reset();
		final stamped = List<VoidCallback>.of(_stamped);
		_stamped.clear();
		for (final onEnd in stamped) {
			onEnd();
		}
		if (mounted) setState(() {});
	}

	void _down(PointerDownEvent event) {
		if (!widget.enabled || !isReady) return;
		controller.down(event.pointer, _local(event.position));
	}

	void _move(PointerMoveEvent event) {
		if (!widget.enabled || !isReady) return;
		controller.moveTo(event.pointer, _local(event.position));
	}

	void _up(PointerEvent event) => controller.up(event.pointer);

	Offset _local(Offset global) {
		final self = context.findRenderObject();
		return self is RenderBox && self.hasSize ? self.globalToLocal(global) : global;
	}

	@override
	Widget build(BuildContext context) {
		final solver = _solver;
		return _SceneScope(
			state: this,
			child: Listener(
				// Translucent, or empty background between the cards never stirs the field.
				behavior: HitTestBehavior.translucent,
				onPointerDown: _down,
				onPointerMove: _move,
				onPointerUp: _up,
				onPointerCancel: _up,
				child: Stack(
					fit: StackFit.passthrough,
					children: [
						widget.child,
						if (solver != null && solver.isReady)
							Positioned.fill(
								child: IgnorePointer(
									child: CustomPaint(
										painter: _DyePainter(solver: solver, repaint: _repaint),
									),
								),
							),
					],
				),
			),
		);
	}
}

class _SceneScope extends InheritedWidget {
	const _SceneScope({required this.state, required super.child});

	final FluidSceneState state;

	@override
	bool updateShouldNotify(_SceneScope oldWidget) => oldWidget.state != state;
}

class _DyePainter extends CustomPainter {
	_DyePainter({required this.solver, required Listenable repaint}) : super(repaint: repaint);

	final FluidSolver solver;

	@override
	void paint(Canvas canvas, Size size) => solver.paint(canvas, size);

	@override
	bool shouldRepaint(_DyePainter old) => old.solver != solver;
}
