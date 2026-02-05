import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Widget that displays the camera preview with detection overlay
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isScanning;
  final String statusMessage;

  const CameraPreviewWidget({
    Key? key,
    required this.cameraController,
    required this.isScanning,
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
          statusMessage: statusMessage,
        ),
      ],
    );
  }
}

/// Overlay widget showing scanning frame and status
class DetectionOverlay extends StatelessWidget {
  final bool isScanning;
  final String statusMessage;

  const DetectionOverlay({
    Key? key,
    required this.isScanning,
    required this.statusMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isScanning ? Colors.green : Colors.white.withOpacity(0.5),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          // Semi-transparent overlay
          Container(
            color: Colors.black.withOpacity(0.2),
          ),

          // Scanning area indicator (center rectangle)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isScanning ? Colors.green : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  _buildCornerIndicator(Alignment.topLeft),
                  _buildCornerIndicator(Alignment.topRight),
                  _buildCornerIndicator(Alignment.bottomLeft),
                  _buildCornerIndicator(Alignment.bottomRight),

                  // Center instruction
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
                      child: Text(
                        'Position label in frame',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                  if (isScanning) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      statusMessage,
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
  Widget _buildCornerIndicator(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? BorderSide(
                    color: isScanning ? Colors.green : Colors.white, width: 4)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(
                    color: isScanning ? Colors.green : Colors.white, width: 4)
                : BorderSide.none,
            left: alignment.x < 0
                ? BorderSide(
                    color: isScanning ? Colors.green : Colors.white, width: 4)
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(
                    color: isScanning ? Colors.green : Colors.white, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
