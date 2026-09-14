// @ai-generated(guided)

import 'dart:typed_data';
import 'dart:ui';

import '../elastic/elastic_body.dart';

/// Logical pixels in the [LiquidGlass] frame; overlapping shapes merge.
sealed class GlassShape {
	const GlassShape({this.deform = ShapeDeform.none});

	static const floatsPerShape = 16;

	final ShapeDeform deform;

	/// Packs (kind, radius, bend, pullRadius), (p0, p1), (p2, grab), (stretch, pull) —
	/// the layout `liquid_glass.frag` reads.
	void write(Float32List out, int offset, double dpr) {
		writeGeometry(out, offset, dpr);
		final d = deform;
		out[offset + 3] = d.pullRadius * dpr;
		out[offset + 10] = d.grab.dx * dpr;
		out[offset + 11] = d.grab.dy * dpr;
		out[offset + 12] = d.stretch.dx;
		out[offset + 13] = d.stretch.dy;
		out[offset + 14] = d.pull.dx * dpr;
		out[offset + 15] = d.pull.dy * dpr;
	}

	void writeGeometry(Float32List out, int offset, double dpr);

	/// Draws the same outline with the canvas, for the non-Impeller fallback.
	void paint(Canvas canvas, Paint paint);
}

final class GlassCircle extends GlassShape {
	const GlassCircle({required this.center, required this.radius, super.deform});

	final Offset center;
	final double radius;

	@override
	void writeGeometry(Float32List out, int offset, double dpr) {
		out[offset] = 1;
		out[offset + 1] = radius * dpr;
		out[offset + 4] = center.dx * dpr;
		out[offset + 5] = center.dy * dpr;
	}

	@override
	void paint(Canvas canvas, Paint paint) {
		canvas.drawCircle(center, radius, paint);
	}
}

final class GlassCapsule extends GlassShape {
	const GlassCapsule({required this.a, required this.b, required this.radius, super.deform});

	final Offset a;
	final Offset b;
	final double radius;

	@override
	void writeGeometry(Float32List out, int offset, double dpr) {
		out[offset] = 2;
		out[offset + 1] = radius * dpr;
		out[offset + 4] = a.dx * dpr;
		out[offset + 5] = a.dy * dpr;
		out[offset + 6] = b.dx * dpr;
		out[offset + 7] = b.dy * dpr;
	}

	@override
	void paint(Canvas canvas, Paint paint) {
		canvas.drawLine(a, b, _stroke(paint, radius));
	}
}

final class GlassRoundedBox extends GlassShape {
	const GlassRoundedBox({required this.rect, required this.cornerRadius, super.deform});

	final Rect rect;
	final double cornerRadius;

	@override
	void writeGeometry(Float32List out, int offset, double dpr) {
		out[offset] = 3;
		out[offset + 1] = cornerRadius * dpr;
		out[offset + 4] = rect.center.dx * dpr;
		out[offset + 5] = rect.center.dy * dpr;
		out[offset + 6] = rect.width / 2 * dpr;
		out[offset + 7] = rect.height / 2 * dpr;
	}

	@override
	void paint(Canvas canvas, Paint paint) {
		canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)), paint);
	}
}

/// A capsule swept along `a → corner → b`, the corner rounded by [bend].
final class GlassBentCapsule extends GlassShape {
	const GlassBentCapsule({
		required this.a,
		required this.corner,
		required this.b,
		required this.radius,
		required this.bend,
		super.deform,
	});

	final Offset a;
	final Offset corner;
	final Offset b;
	final double radius;
	final double bend;

	@override
	void writeGeometry(Float32List out, int offset, double dpr) {
		out[offset] = 4;
		out[offset + 1] = radius * dpr;
		out[offset + 2] = bend * dpr;
		out[offset + 4] = a.dx * dpr;
		out[offset + 5] = a.dy * dpr;
		out[offset + 6] = corner.dx * dpr;
		out[offset + 7] = corner.dy * dpr;
		out[offset + 8] = b.dx * dpr;
		out[offset + 9] = b.dy * dpr;
	}

	@override
	void paint(Canvas canvas, Paint paint) {
		final path = Path()
			..moveTo(a.dx, a.dy)
			..lineTo(corner.dx, corner.dy)
			..lineTo(b.dx, b.dy);
		canvas.drawPath(path, _stroke(paint, radius)..strokeJoin = StrokeJoin.round);
	}
}

Paint _stroke(Paint paint, double radius) => Paint()
	..color = paint.color
	..style = PaintingStyle.stroke
	..strokeWidth = radius * 2
	..strokeCap = StrokeCap.round;
