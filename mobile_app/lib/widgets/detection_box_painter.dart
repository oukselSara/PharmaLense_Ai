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
      ..color = const Color.fromARGB(255, 253, 253, 253)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    // Calculate original box dimensions
    final originalLeft = box![0] * scaleX;
    final originalTop = box![1] * scaleY;
    final originalRight = box![2] * scaleX;
    final originalBottom = box![3] * scaleY;

    // Calculate center and dimensions
    final centerX = (originalLeft + originalRight) / 2;
    final centerY = (originalTop + originalBottom) / 2;
    final originalWidth = originalRight - originalLeft;
    final originalHeight = originalBottom - originalTop;

    // Swap width and height, then scale down to 55%
    const scaleFactor = 0.55;
    final newWidth = originalHeight * scaleFactor;
    final newHeight = originalWidth * scaleFactor;

    // Create new rect with swapped dimensions centered at same point
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
