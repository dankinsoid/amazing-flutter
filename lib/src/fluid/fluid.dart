// @ai-generated(solo)

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'scene.dart';

/// Hands [child] to the nearest [FluidScene] as dye the moment a finger lands on it.
class Fluid extends StatefulWidget {
	const Fluid({
		super.key,
		required this.child,
		this.controller,
		this.onDismissed,
		this.enabled = true,
	});

	final Widget child;

	/// Null builds a private controller; pass one to stamp or play from outside.
	final FluidController? controller;

	/// Fires once the scene's dye is gone and the child is live again.
	final VoidCallback? onDismissed;

	/// False leaves the child alone; a passed controller still stamps it.
	final bool enabled;

	@override
	State<Fluid> createState() => _FluidState();
}

class _FluidState extends State<Fluid> {
	final GlobalKey _boundary = GlobalKey();

	FluidController? _private;
	FluidSceneState? _scene;
	bool _flowing = false;

	FluidController get _effect => widget.controller ?? (_private ??= FluidController());

	@override
	void initState() {
		super.initState();
		_effect.addListener(_onEffect);
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		final scene = FluidScene.of(context);
		assert(scene != null, 'Fluid needs a FluidScene ancestor to flow into');
		if (scene == _scene) return;
		if (_flowing) _scene?.detach(_onSceneEnd);
		_scene = scene;
		if (_flowing) scene?.attach(_onSceneEnd);
	}

	@override
	void didUpdateWidget(Fluid oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.controller == widget.controller) return;
		(oldWidget.controller ?? _private)?.removeListener(_onEffect);
		_effect.addListener(_onEffect);
	}

	@override
	void dispose() {
		if (_flowing) _scene?.detach(_onSceneEnd);
		_effect.removeListener(_onEffect);
		_private?.dispose();
		super.dispose();
	}

	void _onEffect() {
		final effect = _effect;
		if (effect.takeStamp()) _stamp();
		final play = effect.takePlay();
		if (play != null) _play(play);
	}

	void _onDown(PointerDownEvent event) {
		if (widget.enabled) _stamp();
	}

	Rect? _stamp() {
		final scene = _scene;
		if (scene == null || _flowing || !scene.canStamp) return null;
		final box = _boundary.currentContext?.findRenderObject();
		// toImageSync throws on a boundary that has never painted.
		if (box is! RenderRepaintBoundary || !box.hasSize) return null;
		final rect = scene.rectOf(box);
		if (rect == null) return null;
		final image = box.toImageSync(pixelRatio: scene.devicePixelRatio);
		if (!scene.stamp(image, rect)) {
			image.dispose();
			return null;
		}
		scene.attach(_onSceneEnd);
		setState(() => _flowing = true);
		_effect.report(FluidStatus.flowing);
		return rect;
	}

	void _play(({Offset? direction, Offset? origin, double speed}) request) {
		final scene = _scene;
		final box = _box();
		final rect = _stamp() ?? (box == null ? null : scene?.rectOf(box));
		if (scene == null || rect == null) return;
		final direction = request.direction ?? const Offset(1, 1);
		final unit = direction.distance > 1e-3 ? direction / direction.distance : const Offset(1, 0);
		final length = Offset(rect.width, rect.height).distance;
		final from = request.origin != null
			? rect.topLeft + request.origin!
			: rect.center - unit * (length / 2);
		scene.controller.stroke(FluidStroke(from: from, to: from + unit * length, speed: request.speed));
	}

	RenderBox? _box() {
		final box = _boundary.currentContext?.findRenderObject();
		return box is RenderBox ? box : null;
	}

	void _onSceneEnd() {
		if (!mounted) return;
		setState(() => _flowing = false);
		_effect.report(FluidStatus.dismissed);
		widget.onDismissed?.call();
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerDown: _onDown,
			child: Visibility(
				visible: !_flowing,
				maintainSize: true,
				maintainAnimation: true,
				maintainState: true,
				child: RepaintBoundary(key: _boundary, child: widget.child),
			),
		);
	}
}
