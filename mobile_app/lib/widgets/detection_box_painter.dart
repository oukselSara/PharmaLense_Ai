import 'package:flutter/material.dart';

class DetectionBoxPainter extends CustomPainter {
  final List<int>? box;
  final Size imageSize;

  DetectionBoxPainter({
    required this.box,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (box == null) return;

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    // Calculate original box dimensions
    final originalLeft = box![0] * scaleX;
    final originalTop = box![1] * scaleY;
    final originalRight = box![2] * scaleX;
    final originalBottom = box![3] * scaleY;

    // Calculate center of detected region
    final centerX = (originalLeft + originalRight) / 2;
    final centerY = (originalTop + originalBottom) / 2;

    // Real label dimensions: 2cm width x 4cm height (ratio 1:2)
    // Use a fixed aspect ratio matching the real label
    const labelWidthCm = 2.0;
    const labelHeightCm = 4.0;
    const aspectRatio = labelWidthCm / labelHeightCm; // 0.5

    // Base the box size on the detected region, scaled down
    final originalWidth = originalRight - originalLeft;
    final originalHeight = originalBottom - originalTop;
    final scaleFactor = 0.55;

    // Calculate new dimensions maintaining the 2:4 aspect ratio
    final baseSize = (originalWidth + originalHeight) / 2 * scaleFactor;
    final newWidth = baseSize * aspectRatio;  // narrower (2cm)
    final newHeight = baseSize;                // taller (4cm)

    // Create new rect with fixed aspect ratio centered at detected position
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: newWidth,
      height: newHeight,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
