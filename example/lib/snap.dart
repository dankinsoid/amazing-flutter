// @ai-generated(solo)

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Screenshot hook: a non-empty directory writes `snap_<name>.png` from inside the app.
///
/// The macOS sandbox only allows the app container, so pass something under
/// `~/Library/Containers/`, and `systemTemp` is that container's tmp.
const snapPath = '';

final snapKey = GlobalKey();

Timer? _pump;

/// A hidden window gets no frames and its tickers stall; force them while capturing.
void startSnapPump() {
	if (snapPath.isEmpty || _pump != null) return;
	_pump = Timer.periodic(const Duration(milliseconds: 16), (_) {
		WidgetsBinding.instance.scheduleForcedFrame();
	});
}

void stopSnapPump() {
	_pump?.cancel();
	_pump = null;
}

/// Reads the rendered frame rather than the window, so an occluded window still captures.
Future<void> writeSnap(String name, double pixelRatio) async {
	if (snapPath.isEmpty) return;
	final boundary = snapKey.currentContext?.findRenderObject();
	if (boundary is! RenderRepaintBoundary) return;
	final image = await boundary.toImage(pixelRatio: pixelRatio);
	final data = await image.toByteData(format: ui.ImageByteFormat.png);
	image.dispose();
	if (data == null) return;
	final dir = snapPath == 'systemTemp' ? Directory.systemTemp.path : snapPath;
	final file = File('$dir/snap_$name.png');
	await file.writeAsBytes(data.buffer.asUint8List());
	debugPrint('snap written: ${file.path}');
}
