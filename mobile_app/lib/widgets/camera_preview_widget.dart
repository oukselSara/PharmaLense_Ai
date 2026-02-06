import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Widget that displays the camera preview with detection overlay
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isScanning;
  final bool isFocusLocked;
  final String statusMessage;

  const CameraPreviewWidget({
    Key? key,
    required this.cameraController,
    required this.isScanning,
    this.isFocusLocked = false,
    required this.statusMessage,
  }) : super(key: key);

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

    final size = MediaQuery.of(context).size;
    final cameraRatio = cameraController.value.aspectRatio;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRect(
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
        ),

        // Detection overlay
        DetectionOverlay(
          isScanning: isScanning,
          isFocusLocked: isFocusLocked,
          statusMessage: statusMessage,
        ),
      ],
    );
  }
}

/// Overlay widget showing scanning frame and status
class DetectionOverlay extends StatefulWidget {
  final bool isScanning;
  final bool isFocusLocked;
  final String statusMessage;

  const DetectionOverlay({
    Key? key,
    required this.isScanning,
    required this.isFocusLocked,
    required this.statusMessage,
  }) : super(key: key);

  @override
  State<DetectionOverlay> createState() => _DetectionOverlayState();
}

class _DetectionOverlayState extends State<DetectionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
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
    final borderColor = widget.isFocusLocked
        ? Colors.orange
        : (widget.isScanning ? Colors.green : Colors.white);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor.withOpacity(0.5),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          // Semi-transparent overlay
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // Scanning area indicator (center rectangle)
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isFocusLocked ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.4,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: borderColor,
                        width: widget.isFocusLocked ? 3 : 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: widget.isFocusLocked
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        _buildCornerIndicator(Alignment.topLeft, borderColor),
                        _buildCornerIndicator(Alignment.topRight, borderColor),
                        _buildCornerIndicator(
                            Alignment.bottomLeft, borderColor),
                        _buildCornerIndicator(
                            Alignment.bottomRight, borderColor),

                        // Center instruction or focus lock indicator
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: widget.isFocusLocked
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.center_focus_strong,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Focus Locked - Scanning...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Position label in frame',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),

                        // Focus lock icon in corner when locked
                        if (widget.isFocusLocked)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Status message at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isScanning && !widget.isFocusLocked) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (widget.isFocusLocked)
                    const Icon(
                      Icons.center_focus_strong,
                      color: Colors.orange,
                      size: 20,
                    ),
                  if (widget.isFocusLocked) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.statusMessage,
                      style: TextStyle(
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
          ),
        ],
      ),
    );
  }

  /// Build corner indicator for scanning frame
  Widget _buildCornerIndicator(Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            left: alignment.x < 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}