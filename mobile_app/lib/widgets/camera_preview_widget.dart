import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import '../services/label_detection_service.dart';

/// Premium camera preview widget with luxury design
class PremiumCameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isScanning;
  final bool labelDetected;
  final String statusMessage;
  final DetectionResult? detectionBox;

  const PremiumCameraPreviewWidget({
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
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        _buildCameraPreview(context),

        // Detection overlay
        if (detectionBox != null)
          _PremiumDetectionOverlay(
            detectionBox: detectionBox!,
            labelDetected: labelDetected,
            cameraController: cameraController,
          ),

        // Status overlay
        _buildStatusOverlay(context),

        // Scanning guide
        if (!labelDetected && isScanning)
          _buildScanningGuide(context),
      ],
    );
  }

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

  Widget _buildStatusOverlay(BuildContext context) {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning && !labelDetected) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF14B57F),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (labelDetected) ...[
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF14B57F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningGuide(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 140,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B57F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: Color(0xFF14B57F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Point at medicine label',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium detection overlay with animations
class _PremiumDetectionOverlay extends StatefulWidget {
  final DetectionResult detectionBox;
  final bool labelDetected;
  final CameraController cameraController;

  const _PremiumDetectionOverlay({
    required this.detectionBox,
    required this.labelDetected,
    required this.cameraController,
  });

  @override
  State<_PremiumDetectionOverlay> createState() =>
      _PremiumDetectionOverlayState();
}

class _PremiumDetectionOverlayState extends State<_PremiumDetectionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          painter: _PremiumDetectionPainter(
            detectionBox: widget.detectionBox,
            labelDetected: widget.labelDetected,
            pulseValue: _pulseAnimation.value,
            cameraController: widget.cameraController,
          ),
        );
      },
    );
  }
}

/// Custom painter for premium detection box
class _PremiumDetectionPainter extends CustomPainter {
  final DetectionResult detectionBox;
  final bool labelDetected;
  final double pulseValue;
  final CameraController cameraController;

  _PremiumDetectionPainter({
    required this.detectionBox,
    required this.labelDetected,
    required this.pulseValue,
    required this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final box = detectionBox.box;

    // CRITICAL FIX: Use actual camera image dimensions from detection result
    // These are the dimensions of the image that was sent to the backend
    final double capturedImageWidth = detectionBox.imageWidth.toDouble();
    final double capturedImageHeight = detectionBox.imageHeight.toDouble();

    // Get screen preview dimensions
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // Calculate how the image is scaled to fit the screen (cover mode)
    // The preview uses BoxFit.cover, so we scale to fill and crop
    final double scaleX = screenWidth / capturedImageWidth;
    final double scaleY = screenHeight / capturedImageHeight;
    final double scale = math.max(scaleX, scaleY);  // Use max for cover mode

    // Calculate the scaled image size and centering offset
    final double scaledImageWidth = capturedImageWidth * scale;
    final double scaledImageHeight = capturedImageHeight * scale;

    // The image might extend beyond screen bounds, calculate the visible portion offset
    final double offsetX = (screenWidth - scaledImageWidth) / 2;
    final double offsetY = (screenHeight - scaledImageHeight) / 2;

    // Transform bounding box coordinates from image space to screen space
    final double screenX1 = (box.x1 * scale) + offsetX;
    final double screenY1 = (box.y1 * scale) + offsetY;
    final double screenX2 = (box.x2 * scale) + offsetX;
    final double screenY2 = (box.y2 * scale) + offsetY;

    final screenRect = Rect.fromLTRB(screenX1, screenY1, screenX2, screenY2);

    // Clamp to visible screen bounds (in case box extends beyond)
    final clampedRect = Rect.fromLTRB(
      screenRect.left.clamp(0.0, screenWidth),
      screenRect.top.clamp(0.0, screenHeight),
      screenRect.right.clamp(0.0, screenWidth),
      screenRect.bottom.clamp(0.0, screenHeight),
    );

    // Draw detection box with premium style
    _drawPremiumBox(canvas, clampedRect);

    if (labelDetected) {
      _drawConfidenceBadge(canvas, clampedRect);
      _drawSuccessIndicator(canvas, clampedRect);
    }
  }

  void _drawPremiumBox(Canvas canvas, Rect rect) {
    final color = labelDetected ? const Color(0xFF14B57F) : const Color(0xFFFF9800);
    
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(10), const Radius.circular(16)),
      glowPaint,
    );

    // Main border with gradient
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: pulseValue),
          color.withValues(alpha: pulseValue * 0.8),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      gradientPaint,
    );

    // Corner accents
    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0 * pulseValue;

    // Draw all four corners
    final corners = [
      (rect.topLeft, [0.0, cornerLength], [cornerLength, 0.0]),
      (rect.topRight, [0.0, cornerLength], [-cornerLength, 0.0]),
      (rect.bottomLeft, [0.0, -cornerLength], [cornerLength, 0.0]),
      (rect.bottomRight, [0.0, -cornerLength], [-cornerLength, 0.0]),
    ];

    for (final corner in corners) {
      final point = corner.$1;
      final vertical = corner.$2;
      final horizontal = corner.$3;

      canvas.drawLine(
        point,
        Offset(point.dx + horizontal[0], point.dy + horizontal[1]),
        cornerPaint,
      );
      canvas.drawLine(
        point,
        Offset(point.dx + vertical[0], point.dy + vertical[1]),
        cornerPaint,
      );
    }

    // Inner fill
    if (labelDetected) {
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.08 * pulseValue)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        fillPaint,
      );
    }
  }

  void _drawConfidenceBadge(Canvas canvas, Rect rect) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(detectionBox.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final badgeRect = Rect.fromLTWH(
      rect.left,
      rect.top - 34,
      textPainter.width + 18,
      26,
    );

    // Badge background
    final badgePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF14B57F),
          Color(0xFF0F9A6A),
        ],
      ).createShader(badgeRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(13)),
      badgePaint,
    );

    // Badge border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(13)),
      borderPaint,
    );

    // Text
    textPainter.paint(
      canvas,
      Offset(rect.left + 9, rect.top - 31),
    );
  }

  void _drawSuccessIndicator(Canvas canvas, Rect rect) {
    // Success checkmark circle
    final indicatorCenter = Offset(rect.right - 20, rect.top + 20);
    
    final circlePaint = Paint()
      ..color = const Color(0xFF14B57F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(indicatorCenter, 16 * pulseValue, circlePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(indicatorCenter, 16 * pulseValue, borderPaint);

    // Checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final checkPath = Path();
    checkPath.moveTo(indicatorCenter.dx - 6, indicatorCenter.dy);
    checkPath.lineTo(indicatorCenter.dx - 2, indicatorCenter.dy + 4);
    checkPath.lineTo(indicatorCenter.dx + 6, indicatorCenter.dy - 4);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(_PremiumDetectionPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.labelDetected != labelDetected;
  }
}