import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/label_detection_service.dart';

/// Camera preview widget with YOLO detection overlay
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isScanning;
  final bool labelDetected;
  final String statusMessage;
  final DetectionResult? detectionBox;

  const CameraPreviewWidget({
    super.key,
    required this.cameraController,
    required this.isScanning,
    required this.labelDetected,
    required this.statusMessage,
    this.detectionBox,
  });

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        _buildCameraPreview(context),

        // YOLO detection overlay
        if (detectionBox != null)
          _buildDetectionOverlay(context),

        // Status and instructions
        _buildStatusOverlay(context),
      ],
    );
  }

  /// Build camera preview with proper aspect ratio
  Widget _buildCameraPreview(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cameraRatio = cameraController.value.aspectRatio;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width * cameraRatio,
            child: CameraPreview(cameraController),
          ),
        ),
      ),
    );
  }

  /// Build detection box overlay (YOLO bounding box)
  Widget _buildDetectionOverlay(BuildContext context) {
    return CustomPaint(
      painter: YoloDetectionPainter(
        detectionBox: detectionBox!,
        labelDetected: labelDetected,
      ),
    );
  }

  /// Build status overlay with instructions
  Widget _buildStatusOverlay(BuildContext context) {
    return Column(
      children: [
        // Top instruction banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isScanning && !labelDetected) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (labelDetected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              if (labelDetected) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Bottom help text (only when not detected)
        if (!labelDetected && isScanning)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(height: 8),
                Text(
                  'Point camera at medicine label\nDetection will happen automatically',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Custom painter for YOLO detection box
class YoloDetectionPainter extends CustomPainter {
  final DetectionResult detectionBox;
  final bool labelDetected;

  YoloDetectionPainter({
    required this.detectionBox,
    required this.labelDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw detection box
    final paint = Paint()
      ..color = labelDetected ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Convert YOLO coordinates to screen coordinates
    // Note: This assumes camera image and screen have same aspect ratio
    // You may need to adjust based on your camera resolution
    final rect = Rect.fromLTRB(
      detectionBox.box.x1.toDouble(),
      detectionBox.box.y1.toDouble(),
      detectionBox.box.x2.toDouble(),
      detectionBox.box.y2.toDouble(),
    );

    // Draw main box
    canvas.drawRect(rect, paint);

    // Draw corners for better visibility
    _drawCorner(canvas, rect.topLeft, true, true, paint);
    _drawCorner(canvas, rect.topRight, true, false, paint);
    _drawCorner(canvas, rect.bottomLeft, false, true, paint);
    _drawCorner(canvas, rect.bottomRight, false, false, paint);

    // Draw confidence label
    if (labelDetected) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(detectionBox.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 30,
        textPainter.width + 16,
        24,
      );

      final labelPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelPaint,
      );

      textPainter.paint(
        canvas,
        Offset(rect.left + 8, rect.top - 28),
      );
    }
  }

  void _drawCorner(Canvas canvas, Offset point, bool isTop, bool isLeft, Paint paint) {
    const cornerLength = 20.0;
    
    // Horizontal line
    canvas.drawLine(
      point,
      Offset(
        point.dx + (isLeft ? cornerLength : -cornerLength),
        point.dy,
      ),
      paint..strokeWidth = 4,
    );

    // Vertical line
    canvas.drawLine(
      point,
      Offset(
        point.dx,
        point.dy + (isTop ? cornerLength : -cornerLength),
      ),
      paint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(YoloDetectionPainter oldDelegate) {
    return oldDelegate.detectionBox != detectionBox ||
        oldDelegate.labelDetected != labelDetected;
  }
}