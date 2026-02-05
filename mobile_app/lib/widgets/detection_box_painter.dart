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

    final rect = Rect.fromLTRB(
      box![0] * scaleX,
      box![1] * scaleY,
      box![2] * scaleX,
      box![3] * scaleY,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
