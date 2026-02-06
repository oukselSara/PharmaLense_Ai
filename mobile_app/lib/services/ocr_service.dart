import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' show InputImage;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show TextRecognizer, RecognizedText, TextBlock, TextRecognitionScript;

import '../models/scanned_label.dart';

/// Service class for handling OCR operations using Google ML Kit
class OcrService {
  late final TextRecognizer _textRecognizer;
  bool _isProcessing = false;

  OcrService() {
    // Initialize the text recognizer
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Process a camera image and extract text with color detection
  Future<ScannedLabel?> processImageWithColor(CameraImage cameraImage) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      // Convert CameraImage to img.Image for both OCR and color detection
      final image = await _convertCameraImageToImage(cameraImage);
      if (image == null) return null;

      // Save as temporary file for ML Kit
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(image));

      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(tempFile.path);

      // Perform text recognition
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract text
      final String extractedText = _extractTextFromBlocks(recognizedText);

      // Detect dominant color
      final String dominantColor = _detectDominantColor(image);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        print('Error deleting temp file: $e');
      }

      if (extractedText.trim().isEmpty) {
        return null;
      }

      // Create and return ScannedLabel model with color
      return ScannedLabel(
        text: extractedText,
        timestamp: DateTime.now(),
        dominantColor: dominantColor,
      );
    } catch (e) {
      print('Error processing image: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Process image without color detection (faster)
  Future<ScannedLabel?> processImage(CameraImage cameraImage) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      final image = await _convertCameraImageToImage(cameraImage);
      if (image == null) return null;

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(image));

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final String extractedText = _extractTextFromBlocks(recognizedText);

      try {
        await tempFile.delete();
      } catch (e) {
        print('Error deleting temp file: $e');
      }

      if (extractedText.trim().isEmpty) {
        return null;
      }

      return ScannedLabel(
        text: extractedText,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error processing image: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert CameraImage to img.Image
  Future<img.Image?> _convertCameraImageToImage(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final img.Image image = img.Image(width: width, height: height);

      final bytesY = cameraImage.planes[0].bytes;
      final bytesU =
          cameraImage.planes.length > 1 ? cameraImage.planes[1].bytes : null;
      final bytesV =
          cameraImage.planes.length > 2 ? cameraImage.planes[2].bytes : null;

      final int rowStrideY = cameraImage.planes[0].bytesPerRow;
      final int rowStrideU =
          cameraImage.planes.length > 1 ? cameraImage.planes[1].bytesPerRow : 0;
      final int pixelStrideU = cameraImage.planes.length > 1
          ? (cameraImage.planes[1].bytesPerPixel ?? 1)
          : 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (x ~/ 2) * pixelStrideU + (y ~/ 2) * rowStrideU;
          final int yIndex = y * rowStrideY + x;

          final int Y = bytesY[yIndex];
          final int U = bytesU != null ? bytesU[uvIndex] : 128;
          final int V = bytesV != null ? bytesV[uvIndex] : 128;

          // YUV to RGB conversion
          int r = (Y + (1.370705 * (V - 128))).round();
          int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round();
          int b = (Y + (1.732446 * (U - 128))).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return image;
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Detect dominant color in the image (green, red, or white)
  String _detectDominantColor(img.Image image) {
    try {
      // Sample pixels from center area (where label should be)
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final sampleSize = 50; // Sample 50x50 area

      int totalRed = 0;
      int totalGreen = 0;
      int totalBlue = 0;
      int pixelCount = 0;

      // Sample from center region
      for (int y = centerY - sampleSize; y < centerY + sampleSize; y++) {
        if (y < 0 || y >= image.height) continue;
        
        for (int x = centerX - sampleSize; x < centerX + sampleSize; x++) {
          if (x < 0 || x >= image.width) continue;

          final pixel = image.getPixel(x, y);
          totalRed += pixel.r.toInt();
          totalGreen += pixel.g.toInt();
          totalBlue += pixel.b.toInt();
          pixelCount++;
        }
      }

      if (pixelCount == 0) return 'unknown';

      // Calculate average RGB values
      final avgRed = totalRed / pixelCount;
      final avgGreen = totalGreen / pixelCount;
      final avgBlue = totalBlue / pixelCount;

      // Determine dominant color
      // White: All values high and similar
      if (avgRed > 200 && avgGreen > 200 && avgBlue > 200) {
        final diff = (avgRed - avgGreen).abs() + 
                    (avgGreen - avgBlue).abs() + 
                    (avgBlue - avgRed).abs();
        if (diff < 30) {
          return 'white';
        }
      }

      // Green: Green channel significantly higher than red
      if (avgGreen > avgRed + 20 && avgGreen > avgBlue + 20) {
        return 'green';
      }

      // Red: Red channel significantly higher than green
      if (avgRed > avgGreen + 20 && avgRed > avgBlue + 10) {
        return 'red';
      }

      // Check for light green (pale green)
      if (avgGreen > avgRed && avgGreen > 150 && avgRed > 120) {
        return 'light_green';
      }

      // Check for light red (pink/pale red)
      if (avgRed > avgGreen && avgRed > 150 && avgGreen > 120) {
        return 'light_red';
      }

      // Default: determine by which channel is highest
      if (avgGreen > avgRed && avgGreen > avgBlue) {
        return 'green';
      } else if (avgRed > avgGreen && avgRed > avgBlue) {
        return 'red';
      } else {
        return 'white';
      }
    } catch (e) {
      print('Error detecting color: $e');
      return 'unknown';
    }
  }

  /// Extract text from recognized text blocks
  String _extractTextFromBlocks(RecognizedText recognizedText) {
    final StringBuffer buffer = StringBuffer();

    // Iterate through text blocks and extract text
    for (TextBlock block in recognizedText.blocks) {
      // Filter out very small text blocks (likely noise)
      if (block.boundingBox.width < 20 || block.boundingBox.height < 10) {
        continue;
      }

      buffer.writeln(block.text);
    }

    return buffer.toString().trim();
  }

  /// Quick check if image contains text (lightweight detection)
  Future<bool> hasDetectableText(CameraImage cameraImage) async {
    try {
      // Quick lightweight check - just convert and check for high contrast areas
      // This is much faster than full OCR
      final image = await _convertCameraImageToImage(cameraImage);
      if (image == null) return false;

      // Sample center area for text-like patterns
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final sampleSize = 100;

      int highContrastPixels = 0;
      int totalSamples = 0;

      for (int y = centerY - sampleSize; y < centerY + sampleSize; y += 5) {
        if (y < 0 || y >= image.height) continue;
        
        for (int x = centerX - sampleSize; x < centerX + sampleSize; x += 5) {
          if (x < 0 || x >= image.width) continue;

          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3;
          
          // Check if pixel is dark enough to be text
          if (brightness < 100) {
            highContrastPixels++;
          }
          
          totalSamples++;
        }
      }

      // If more than 10% of sampled pixels are dark, likely contains text
      return totalSamples > 0 && (highContrastPixels / totalSamples) > 0.1;
    } catch (e) {
      print('Error in text detection: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}