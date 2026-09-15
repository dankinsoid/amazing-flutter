// @ai-generated(solo)

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Painter over a frozen child, on a canvas grown by [spread] on every side.
abstract class ChildSnapshotPainter extends CustomPainter {
	ChildSnapshotPainter({required this.snapshot, required this.spread, super.repaint});

	/// Device-resolution copy of the child; owned by the host.
	final ui.Image snapshot;

	/// Margin added on every side of the child, logical px.
	final double spread;

	/// Where the child sits inside the enlarged canvas.
	Rect childRect(Size size) => Rect.fromLTWH(spread, spread, size.width - 2 * spread, size.height - 2 * spread);
}

/// Freezes the child of a [SnapshotHost] and hides it while frozen.
class ChildSnapshot extends ChangeNotifier {
	ui.Image? _image;
	ui.Image? Function()? _grab;

	ui.Image? get image => _image;
	bool get isFrozen => _image != null;

	/// Catches the last frame the child painted, so a live child lags by one.
	void capture() {
		if (_image != null) return;
		final image = _grab?.call();
		if (image == null) return;
		_image = image;
		notifyListeners();
	}

	/// Shows the child again and drops the snapshot.
	void release() {
		final image = _image;
		if (image == null) return;
		_image = null;
		image.dispose();
		notifyListeners();
	}

	@override
	void dispose() {
		_image?.dispose();
		_image = null;
		_grab = null;
		super.dispose();
	}
}

/// Paints [painterBuilder] over the child while [controller] holds a snapshot.
class SnapshotHost extends StatefulWidget {
	const SnapshotHost({
		super.key,
		required this.controller,
		required this.painterBuilder,
		required this.child,
		this.spread = 0,
	});

	final ChildSnapshot controller;

	/// Built once per rebuild; drive repaints through [CustomPainter.repaint].
	final ChildSnapshotPainter Function(ui.Image snapshot, double spread) painterBuilder;

	/// Margin the painter may draw into on every side, logical px.
	final double spread;

	final Widget child;

	@override
	State<SnapshotHost> createState() => _SnapshotHostState();
}

class _SnapshotHostState extends State<SnapshotHost> {
	final _boundary = GlobalKey();

	@override
	void initState() {
		super.initState();
		_attach(widget.controller);
	}

	@override
	void didUpdateWidget(SnapshotHost oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.controller != widget.controller) {
			_detach(oldWidget.controller);
			_attach(widget.controller);
		}
	}

	@override
	void dispose() {
		_detach(widget.controller);
		super.dispose();
	}

	void _attach(ChildSnapshot controller) {
		controller._grab = _grab;
		controller.addListener(_onFrozen);
	}

	void _detach(ChildSnapshot controller) {
		if (controller._grab == _grab) controller._grab = null;
		controller.removeListener(_onFrozen);
	}

	void _onFrozen() => setState(() {});

	ui.Image? _grab() {
		final boundary = _boundary.currentContext?.findRenderObject();
		// toImageSync throws on a boundary that has never painted.
		if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
		return boundary.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
	}

	@override
	Widget build(BuildContext context) {
		final image = widget.controller.image;
		return Stack(
			clipBehavior: Clip.none,
			children: [
				Visibility(
					visible: image == null,
					maintainSize: true,
					maintainAnimation: true,
					maintainState: true,
					child: RepaintBoundary(key: _boundary, child: widget.child),
				),
				if (image != null)
					Positioned(
						left: -widget.spread,
						top: -widget.spread,
						right: -widget.spread,
						bottom: -widget.spread,
						child: IgnorePointer(
							child: CustomPaint(painter: widget.painterBuilder(image, widget.spread)),
						),
					),
			],
		);
	}
}

/// Takes pointers up to [margin] outside [child]; a box is otherwise hit only inside its size.
///
/// Wrap it around the gesture detector, not inside it: an ancestor that fails its
/// own bounds check never calls down — which is also why a tight parent layout
/// still clips the margin away, and why a neighbour's margin can claim a pointer.
class SpreadHitTest extends SingleChildRenderObjectWidget {
	const SpreadHitTest({super.key, required this.margin, required this.enabled, required super.child});

	final double margin;
	final bool enabled;

	@override
	RenderSpreadHitTest createRenderObject(BuildContext context) =>
		RenderSpreadHitTest(margin: margin, enabled: enabled);

	@override
	void updateRenderObject(BuildContext context, covariant RenderSpreadHitTest renderObject) {
		renderObject
			..margin = margin
			..enabled = enabled;
	}
}

class RenderSpreadHitTest extends RenderProxyBox {
	RenderSpreadHitTest({required double margin, required bool enabled})
		: _margin = margin,
		  _enabled = enabled;

	double _margin;
	bool _enabled;

	set margin(double value) => _margin = value;

	set enabled(bool value) => _enabled = value;

	@override
	bool hitTest(BoxHitTestResult result, {required Offset position}) {
		if (!_enabled) return super.hitTest(result, position: position);
		if (!(Offset.zero & size).inflate(_margin).contains(position)) return false;
		// Hit the child at its nearest edge; the event keeps its real position.
		final inside = Offset(position.dx.clamp(0.0, size.width), position.dy.clamp(0.0, size.height));
		return super.hitTest(result, position: inside);
	}
}
