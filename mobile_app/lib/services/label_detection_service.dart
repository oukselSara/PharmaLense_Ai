import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Service for automatic medicine label detection using YOLO backend
class YoloLabelDetectionService {
  // Update this to your computer's IP address
  // Find it using: ipconfig (Windows) or ifconfig (Mac/Linux)
  static const String baseUrl = "http://192.168.1.7:8000";
  
  bool _isProcessing = false;

  /// Detect label in camera frame (lightweight for real-time)
  Future<DetectionResult?> detectLive(CameraImage cameraImage) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      // Store camera image dimensions for coordinate mapping
      final imageWidth = cameraImage.width;
      final imageHeight = cameraImage.height;

      // Convert CameraImage to JPEG
      final jpegBytes = await _convertCameraImageToJpeg(cameraImage);
      if (jpegBytes == null) return null;

      // Send to backend
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-live'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          jpegBytes,
          filename: 'frame.jpg',
        ),
      );

      // Set timeout for real-time performance (increased for CPU backend)
      final response = await request.send().timeout(
        const Duration(milliseconds: 2000), // Increased from 500ms for CPU processing
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⏱️ Detection timeout after 2000ms');
          }
          throw TimeoutException('Detection timeout');
        },
      );

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);

        if (data["detected"] == true && data["box"] != null) {
          final box = List<int>.from(data["box"]);

          // CRITICAL: Extract cropped image from response
          // This contains ONLY pixels within the detection bounding box
          File? croppedFile;
          if (data["cropped_image"] != null) {
            try {
              final croppedBytes = base64.decode(data["cropped_image"]);
              final tempDir = Directory.systemTemp;
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              croppedFile = File('${tempDir.path}/cropped_label_$timestamp.jpg');
              await croppedFile.writeAsBytes(croppedBytes);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error saving cropped image: $e');
              }
            }
          }

          return DetectionResult(
            box: BoundingBox(
              x1: box[0],
              y1: box[1],
              x2: box[2],
              y2: box[3],
            ),
            confidence: (data["confidence"] ?? 0.0).toDouble(),
            croppedImageFile: croppedFile,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          );
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in live detection: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
      }
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Detect and crop label from image file (for final capture)
  Future<CroppedLabelResult?> detectAndCrop(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-and-crop'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);

        if (data["detected"] == true) {
          // Decode base64 images
          final croppedBytes = base64.decode(data["cropped_image"]);
          final enhancedBytes = base64.decode(data["enhanced_image"]);

          return CroppedLabelResult(
            croppedImage: croppedBytes,
            enhancedImage: enhancedBytes,
            confidence: (data["confidence"] ?? 0.0).toDouble(),
          );
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error in detect and crop: $e');
      }
      return null;
    }
  }

  /// Check if backend server is available
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Server connection failed: $e');
      }
      return false;
    }
  }

  /// Convert CameraImage to JPEG bytes
  Future<Uint8List?> _convertCameraImageToJpeg(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final img.Image image = img.Image(width: width, height: height);

      final bytesY = cameraImage.planes[0].bytes;
      final bytesU = cameraImage.planes.length > 1 
          ? cameraImage.planes[1].bytes 
          : null;
      final bytesV = cameraImage.planes.length > 2 
          ? cameraImage.planes[2].bytes 
          : null;

      final int rowStrideY = cameraImage.planes[0].bytesPerRow;
      final int rowStrideU = cameraImage.planes.length > 1 
          ? cameraImage.planes[1].bytesPerRow 
          : 0;
      final int pixelStrideU = cameraImage.planes.length > 1
          ? (cameraImage.planes[1].bytesPerPixel ?? 1)
          : 1;

      // YUV to RGB conversion
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (x ~/ 2) * pixelStrideU + (y ~/ 2) * rowStrideU;
          final int yIndex = y * rowStrideY + x;

          final int Y = bytesY[yIndex];
          final int U = bytesU != null ? bytesU[uvIndex] : 128;
          final int V = bytesV != null ? bytesV[uvIndex] : 128;

          int r = (Y + (1.370705 * (V - 128))).round().clamp(0, 255);
          int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128)))
              .round()
              .clamp(0, 255);
          int b = (Y + (1.732446 * (U - 128))).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      // Encode to JPEG with quality 85 (good balance)
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      if (kDebugMode) {
        print('Error converting camera image: $e');
      }
      return null;
    }
  }
}

/// Model classes
class BoundingBox {
  final int x1, y1, x2, y2;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  int get width => x2 - x1;
  int get height => y2 - y1;
  
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
}

class DetectionResult {
  final BoundingBox box;
  final double confidence;
  final File? croppedImageFile; // CRITICAL: Pre-cropped image containing ONLY label pixels
  final int imageWidth;  // Original camera image width
  final int imageHeight; // Original camera image height

  DetectionResult({
    required this.box,
    required this.confidence,
    this.croppedImageFile,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class CroppedLabelResult {
  final Uint8List croppedImage;
  final Uint8List enhancedImage;
  final double confidence;

  CroppedLabelResult({
    required this.croppedImage,
    required this.enhancedImage,
    required this.confidence,
  });
}