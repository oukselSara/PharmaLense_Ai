import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Premium camera preview widget with a simple scan area
class PremiumCameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isScanning;
  final bool labelDetected;
  final String statusMessage;

  const PremiumCameraPreviewWidget({
    super.key,
    required this.cameraController,
    required this.isScanning,
    required this.labelDetected,
    required this.statusMessage,
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

        // Fixed scan area overlay
        _ScanAreaOverlay(
          isScanning: isScanning,
          labelDetected: labelDetected,
        ),

        // Status overlay
        _buildStatusOverlay(context),
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
}

/// Fixed scan area overlay with animated corners
class _ScanAreaOverlay extends StatefulWidget {
  final bool isScanning;
  final bool labelDetected;

  const _ScanAreaOverlay({
    required this.isScanning,
    required this.labelDetected,
  });

  @override
  State<_ScanAreaOverlay> createState() => _ScanAreaOverlayState();
}

class _ScanAreaOverlayState extends State<_ScanAreaOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanAreaPainter(
            isScanning: widget.isScanning,
            labelDetected: widget.labelDetected,
            pulseValue: _pulseAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter for the scan area
class _ScanAreaPainter extends CustomPainter {
  final bool isScanning;
  final bool labelDetected;
  final double pulseValue;

  _ScanAreaPainter({
    required this.isScanning,
    required this.labelDetected,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scan area - centered square
    final double scanSize = size.width * 0.75;
    final double left = (size.width - scanSize) / 2;
    final double top = (size.height - scanSize) / 2 - 40; // Slightly above center
    final Rect scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    // Draw darkened overlay outside scan area
    _drawDarkOverlay(canvas, size, scanRect);

    // Draw scan frame
    _drawScanFrame(canvas, scanRect);

    // Draw corner brackets
    _drawCornerBrackets(canvas, scanRect);

    // Draw instruction text
    _drawInstructionText(canvas, scanRect);
  }

  void _drawDarkOverlay(Canvas canvas, Size size, Rect scanRect) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Create a path that covers the entire screen except the scan area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
  }

  void _drawScanFrame(Canvas canvas, Rect scanRect) {
    final color = labelDetected
        ? const Color(0xFF14B57F)
        : const Color(0xFF14B57F).withValues(alpha: pulseValue);

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect.inflate(5), const Radius.circular(20)),
      glowPaint,
    );

    // Main border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      borderPaint,
    );

    // Inner fill when detected
    if (labelDetected) {
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
        fillPaint,
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect scanRect) {
    final color = labelDetected
        ? const Color(0xFF14B57F)
        : Colors.white.withValues(alpha: pulseValue);

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 35.0;
    const cornerOffset = 8.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanRect.left - cornerOffset, scanRect.top + cornerLength),
      Offset(scanRect.left - cornerOffset, scanRect.top - cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left - cornerOffset, scanRect.top - cornerOffset),
      Offset(scanRect.left + cornerLength, scanRect.top - cornerOffset),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.top - cornerOffset),
      Offset(scanRect.right + cornerOffset, scanRect.top - cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right + cornerOffset, scanRect.top - cornerOffset),
      Offset(scanRect.right + cornerOffset, scanRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanRect.left - cornerOffset, scanRect.bottom - cornerLength),
      Offset(scanRect.left - cornerOffset, scanRect.bottom + cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left - cornerOffset, scanRect.bottom + cornerOffset),
      Offset(scanRect.left + cornerLength, scanRect.bottom + cornerOffset),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.bottom + cornerOffset),
      Offset(scanRect.right + cornerOffset, scanRect.bottom + cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right + cornerOffset, scanRect.bottom + cornerOffset),
      Offset(scanRect.right + cornerOffset, scanRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  void _drawInstructionText(Canvas canvas, Rect scanRect) {
    if (labelDetected) return;

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Place medicine label here',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final textOffset = Offset(
      scanRect.center.dx - textPainter.width / 2,
      scanRect.bottom + 30,
    );

    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(_ScanAreaPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.labelDetected != labelDetected ||
        oldDelegate.isScanning != isScanning;
  }
}
