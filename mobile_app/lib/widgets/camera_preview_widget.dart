import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import '../services/label_detection_service.dart';

/// Camera preview widget with animated YOLO detection overlay
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

        // YOLO detection overlay with animations
        if (detectionBox != null)
          AnimatedDetectionOverlay(
            detectionBox: detectionBox!,
            labelDetected: labelDetected,
          ),

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

/// Animated detection overlay with QR-code-style effects
class AnimatedDetectionOverlay extends StatefulWidget {
  final DetectionResult detectionBox;
  final bool labelDetected;

  const AnimatedDetectionOverlay({
    super.key,
    required this.detectionBox,
    required this.labelDetected,
  });

  @override
  State<AnimatedDetectionOverlay> createState() => _AnimatedDetectionOverlayState();
}

class _AnimatedDetectionOverlayState extends State<AnimatedDetectionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _cornerController;
  late AnimationController _particleController;

  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _cornerAnimation;

  @override
  void initState() {
    super.initState();

    // Scanning line animation (top to bottom)
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanLineController,
        curve: Curves.easeInOut,
      ),
    );

    // Pulse animation for corners
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Glow animation for detected state
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Corner expand animation
    _cornerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _cornerAnimation = Tween<double>(begin: 20.0, end: 35.0).animate(
      CurvedAnimation(
        parent: _cornerController,
        curve: Curves.easeInOut,
      ),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _cornerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scanLineController,
        _pulseController,
        _glowController,
        _cornerController,
        _particleController,
      ]),
      builder: (context, child) {
        return CustomPaint(
          painter: AnimatedDetectionPainter(
            detectionBox: widget.detectionBox,
            labelDetected: widget.labelDetected,
            scanLineProgress: _scanLineAnimation.value,
            pulseValue: _pulseAnimation.value,
            glowValue: _glowAnimation.value,
            cornerLength: _cornerAnimation.value,
            particleProgress: _particleController.value,
          ),
        );
      },
    );
  }
}

/// Custom painter with all the animations
class AnimatedDetectionPainter extends CustomPainter {
  final DetectionResult detectionBox;
  final bool labelDetected;
  final double scanLineProgress;
  final double pulseValue;
  final double glowValue;
  final double cornerLength;
  final double particleProgress;

  AnimatedDetectionPainter({
    required this.detectionBox,
    required this.labelDetected,
    required this.scanLineProgress,
    required this.pulseValue,
    required this.glowValue,
    required this.cornerLength,
    required this.particleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      detectionBox.box.x1.toDouble(),
      detectionBox.box.y1.toDouble(),
      detectionBox.box.x2.toDouble(),
      detectionBox.box.y2.toDouble(),
    );

    // Draw glow effect (background)
    if (labelDetected) {
      _drawGlowEffect(canvas, rect);
    }

    // Draw highlight overlay
    _drawHighlightOverlay(canvas, rect);

    // Draw scanning line (only when not detected)
    if (!labelDetected) {
      _drawScanningLine(canvas, rect);
    }

    // Draw main border box
    _drawMainBorder(canvas, rect);

    // Draw animated corners
    _drawAnimatedCorners(canvas, rect);

    // Draw particles (when detected)
    if (labelDetected) {
      _drawParticles(canvas, rect);
    }

    // Draw confidence badge
    if (labelDetected) {
      _drawConfidenceBadge(canvas, rect);
    }

    // Draw detection icon
    if (labelDetected) {
      _drawDetectionIcon(canvas, rect);
    }
  }

  /// Draw glowing effect around the detection box
  void _drawGlowEffect(Canvas canvas, Rect rect) {
    final glowPaint = Paint()
      ..color = Colors.green.withOpacity(0.15 * glowValue)
      ..style = PaintingStyle.fill;

    // Multiple layers for smooth glow
    for (int i = 3; i > 0; i--) {
      final expandedRect = rect.inflate(i * 8.0 * glowValue);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          expandedRect,
          Radius.circular(12 + i * 4.0),
        ),
        glowPaint,
      );
    }

    // Inner glow
    final innerGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.1 * glowValue)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      innerGlowPaint,
    );
  }

  /// Draw highlight overlay inside the box
  void _drawHighlightOverlay(Canvas canvas, Rect rect) {
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (labelDetected ? Colors.green : Colors.orange).withOpacity(0.15),
          (labelDetected ? Colors.green : Colors.orange).withOpacity(0.05),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      overlayPaint,
    );
  }

  /// Draw animated scanning line
  void _drawScanningLine(Canvas canvas, Rect rect) {
    final scanY = rect.top + (rect.height * scanLineProgress);

    // Glow above the line
    final glowGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.orange.withOpacity(0.3),
          Colors.orange.withOpacity(0.6),
          Colors.orange.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(
        Rect.fromLTWH(rect.left, scanY - 40, rect.width, 80),
      );

    canvas.drawRect(
      Rect.fromLTWH(rect.left, scanY - 40, rect.width, 80),
      glowGradient,
    );

    // Main scanning line
    final linePaint = Paint()
      ..color = Colors.orange.withOpacity(0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(rect.left, scanY),
      Offset(rect.right, scanY),
      linePaint,
    );

    // Bright center of scanning line
    final brightLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(rect.left, scanY),
      Offset(rect.right, scanY),
      brightLinePaint,
    );
  }

  /// Draw main border box
  void _drawMainBorder(Canvas canvas, Rect rect) {
    final borderPaint = Paint()
      ..color = labelDetected ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Inner border for depth
    final innerBorderPaint = Paint()
      ..color = (labelDetected ? Colors.green : Colors.orange).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(2),
        const Radius.circular(6),
      ),
      innerBorderPaint,
    );
  }

  /// Draw animated corners
  void _drawAnimatedCorners(Canvas canvas, Rect rect) {
    final cornerPaint = Paint()
      ..color = (labelDetected ? Colors.green : Colors.orange)
          .withOpacity(pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (int i = 0; i < corners.length; i++) {
      final point = corners[i];
      final isTop = i < 2;
      final isLeft = i % 2 == 0;

      // Horizontal line
      canvas.drawLine(
        point,
        Offset(
          point.dx + (isLeft ? cornerLength : -cornerLength),
          point.dy,
        ),
        cornerPaint,
      );

      // Vertical line
      canvas.drawLine(
        point,
        Offset(
          point.dx,
          point.dy + (isTop ? cornerLength : -cornerLength),
        ),
        cornerPaint,
      );

      // Corner dots (pulsing)
      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(pulseValue)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, 4 * pulseValue, dotPaint);
    }
  }

  /// Draw floating particles when detected
  void _drawParticles(Canvas canvas, Rect rect) {

    // Create particles around the border
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * math.pi;
      final progress = (particleProgress + i * 0.05) % 1.0;
      
      // Particle position along the border
      final x = rect.center.dx + math.cos(angle) * (rect.width / 2) * (1 + progress * 0.3);
      final y = rect.center.dy + math.sin(angle) * (rect.height / 2) * (1 + progress * 0.3);
      
      final size = 3 * (1 - progress);
      final opacity = 0.8 * (1 - progress);

      final paint = Paint()
        ..color = Colors.green.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), size, paint);
    }
  }

  /// Draw confidence badge
  void _drawConfidenceBadge(Canvas canvas, Rect rect) {
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

    final badgeRect = Rect.fromLTWH(
      rect.left,
      rect.top - 35,
      textPainter.width + 20,
      26,
    );

    // Badge background with glow
    final badgeGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.3 * glowValue)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect.inflate(2), const Radius.circular(6)),
      badgeGlowPaint,
    );

    // Main badge
    final badgePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      badgePaint,
    );

    // Badge border
    final badgeBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      badgeBorderPaint,
    );

    // Text
    textPainter.paint(
      canvas,
      Offset(rect.left + 10, rect.top - 33),
    );
  }

  /// Draw detection icon
  void _drawDetectionIcon(Canvas canvas, Rect rect) {
    const iconSize = 40.0;
    final iconRect = Rect.fromCenter(
      center: Offset(rect.right - 25, rect.top + 25),
      width: iconSize,
      height: iconSize,
    );

    // Icon background
    final iconBgPaint = Paint()
      ..color = Colors.green.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(iconRect.center, iconSize / 2, iconBgPaint);

    // Icon glow
    final iconGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.3 * glowValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(iconRect.center, (iconSize / 2) + 4, iconGlowPaint);

    // Draw checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final checkPath = Path();
    checkPath.moveTo(iconRect.center.dx - 8, iconRect.center.dy);
    checkPath.lineTo(iconRect.center.dx - 2, iconRect.center.dy + 6);
    checkPath.lineTo(iconRect.center.dx + 8, iconRect.center.dy - 6);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(AnimatedDetectionPainter oldDelegate) {
    return oldDelegate.scanLineProgress != scanLineProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.particleProgress != particleProgress ||
        oldDelegate.labelDetected != labelDetected;
  }
}