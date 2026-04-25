import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class MarkerService {
  // Cache for generated markers to avoid re-drawing them unnecessarily
  final Map<String, BitmapDescriptor> _markerCache = {};

  /// Creates a custom marker with a label (e.g., price) and a specific color.
  /// The marker is a rounded rectangle (pill shape) with the label text centered.
  /// When [isOptimal] is true, draws an amber/yellow border (best match for the user).
  Future<BitmapDescriptor> createCustomMarkerBitmap(
    String label,
    Color color, {
    double width = 100,
    double height = 50,
    bool isOptimal = false,
  }) async {
    final cacheKey =
        '${label}_${color.toARGB32()}_${width}_${height}_opt$isOptimal';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    // Draw pill shape background
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(25),
    );
    canvas.drawRRect(rRect, paint);

    // Draw triangle arrow at bottom to point to location
    final path = Path();
    path.moveTo(width / 2 - 10, height);
    path.lineTo(width / 2, height + 15);
    path.lineTo(width / 2 + 10, height);
    path.close();
    canvas.drawPath(path, paint);

    if (isOptimal) {
      const borderColor = EasyParkColors.mapMarkerOptimalBorder;
      final stroke = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round;
      canvas.drawRRect(rRect, stroke);
      canvas.drawPath(path, stroke);
    }

    // Draw text (label)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: EasyParkColors.onAccent,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    // Convert to image
    final imgHeight = (height + 15).toInt(); // +15 for the arrow
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), imgHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final bitmap = BitmapDescriptor.bytes(bytes);
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }
}
