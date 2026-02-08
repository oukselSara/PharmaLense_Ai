import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' show InputImage;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show TextRecognizer, RecognizedText, TextBlock, TextRecognitionScript;

import '../models/scanned_label.dart';

/// Optimized OCR service - fast and doesn't freeze
class OcrService {
  late final TextRecognizer _textRecognizer;
  bool _isProcessing = false;

  OcrService() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Process an image file with lightweight preprocessing
  Future<ScannedLabel?> processImageFile(File imageFile) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) return null;

      // Try only 2 methods to avoid freezing
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final results = <_OcrResult>[];

      // Method 1: Original with light enhancement
      final enhanced = _lightEnhance(image);
      final enhancedFile = File('${tempDir.path}/enhanced_$timestamp.jpg');
      await enhancedFile.writeAsBytes(img.encodeJpg(enhanced, quality: 90));
      
      final result1 = await _performOcr(enhancedFile.path);
      if (result1 != null) results.add(result1);
      
      // Method 2: High contrast
      final contrasted = _highContrast(image);
      final contrastFile = File('${tempDir.path}/contrast_$timestamp.jpg');
      await contrastFile.writeAsBytes(img.encodeJpg(contrasted, quality: 90));
      
      final result2 = await _performOcr(contrastFile.path);
      if (result2 != null) results.add(result2);

      // Cleanup
      try {
        await enhancedFile.delete();
        await contrastFile.delete();
      } catch (e) {
        if (kDebugMode) print('Error deleting temp files: $e');
      }

      if (results.isEmpty) return null;

      // Pick best result
      results.sort((a, b) => b.text.length.compareTo(a.text.length));
      final bestResult = results.first;

      if (bestResult.text.trim().isEmpty) return null;

      // Detect color
      final String dominantColor = _detectDominantColor(image);

      return ScannedLabel(
        text: bestResult.text,
        timestamp: DateTime.now(),
        imagePath: imageFile.path,
        dominantColor: dominantColor,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image file: $e');
      }
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Process camera image - FAST method to avoid freezing
  Future<ScannedLabel?> processImageWithColor(CameraImage cameraImage) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      final image = await _convertCameraImageToImage(cameraImage);
      if (image == null) return null;

      // Save temporary file - only ONE preprocessing method
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Use only light enhancement to avoid freezing
      final enhanced = _lightEnhance(image);
      final tempFile = File('${tempDir.path}/frame_$timestamp.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(enhanced, quality: 85));

      // Perform OCR
      final result = await _performOcr(tempFile.path);

      // Cleanup
      try {
        await tempFile.delete();
      } catch (e) {
        if (kDebugMode) print('Error deleting temp file: $e');
      }

      if (result == null || result.text.trim().isEmpty) return null;

      // Detect color
      final String dominantColor = _detectDominantColor(image);

      return ScannedLabel(
        text: result.text,
        timestamp: DateTime.now(),
        dominantColor: dominantColor,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error processing camera image: $e');
      }
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Perform OCR on a file path
  Future<_OcrResult?> _performOcr(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final text = _extractTextFromBlocks(recognizedText);
      final confidence = _calculateConfidence(recognizedText);

      if (text.trim().isEmpty) return null;

      return _OcrResult(text: text, confidence: confidence);
    } catch (e) {
      if (kDebugMode) print('OCR error: $e');
      return null;
    }
  }

  /// Extract text from blocks with filtering
  String _extractTextFromBlocks(RecognizedText recognizedText) {
    final lines = <String>[];
    final seenTexts = <String>{};

    for (TextBlock block in recognizedText.blocks) {
      // Filter out very small blocks
      if (block.boundingBox.width < 15 || block.boundingBox.height < 8) {
        continue;
      }

      final text = block.text.trim();
      
      // Skip empty or very short texts
      if (text.isEmpty || text.length < 2) continue;

      // Skip duplicates
      final normalizedText = text.toLowerCase();
      if (seenTexts.contains(normalizedText)) continue;
      seenTexts.add(normalizedText);

      // Clean up the text
      final cleanedText = _cleanText(text);
      if (cleanedText.isNotEmpty) {
        lines.add(cleanedText);
      }
    }

    return lines.join('\n');
  }

  /// Clean extracted text
  String _cleanText(String text) {
    // Remove multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove leading/trailing spaces
    text = text.trim();
    
    // Fix common OCR errors
    text = text.replaceAll(RegExp(r'[|l]{2,}'), 'II');
    text = text.replaceAll(RegExp(r'[oO](?=\d)'), '0');
    text = text.replaceAll(RegExp(r'(?<=\d)[oO]'), '0');
    
    return text;
  }

  /// Calculate confidence score
  double _calculateConfidence(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int blockCount = 0;

    for (TextBlock block in recognizedText.blocks) {
      final textLength = block.text.length;
      if (textLength > 3) {
        totalConfidence += 1.0;
        blockCount++;
      }
    }

    return blockCount > 0 ? totalConfidence / blockCount : 0.0;
  }

  /// Light enhancement - FAST
  img.Image _lightEnhance(img.Image src) {
    // Quick contrast and brightness adjustment
    return img.adjustColor(src, contrast: 1.2, brightness: 1.05);
  }

  /// High contrast - FAST
  img.Image _highContrast(img.Image src) {
    // Stronger contrast adjustment
    return img.adjustColor(src, contrast: 1.4, brightness: 1.1);
  }

  /// Simple color detection - samples center region only
  String _detectDominantColor(img.Image image) {
    try {
      // Sample only center region for speed
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      const sampleSize = 50;

      int totalRed = 0;
      int totalGreen = 0;
      int totalBlue = 0;
      int pixelCount = 0;

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

      final avgRed = totalRed / pixelCount;
      final avgGreen = totalGreen / pixelCount;
      final avgBlue = totalBlue / pixelCount;

      return _classifyColor(avgRed, avgGreen, avgBlue);
    } catch (e) {
      if (kDebugMode) print('Error detecting color: $e');
      return 'unknown';
    }
  }

  /// Classify color based on RGB values
  String _classifyColor(double r, double g, double b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    final diff = max - min;
    
    final saturation = max == 0 ? 0 : (diff / max) * 100;
    final brightness = max;

    // White/Light detection
    if (brightness > 200 && saturation < 15) {
      return 'white';
    }

    // Low saturation gray
    if (saturation < 20 && brightness < 200) {
      return 'white';
    }

    // Color detection
    if (g > r + 15 && g > b + 15) {
      if (brightness > 180) {
        return 'light_green';
      }
      return 'green';
    } else if (r > g + 15 && r > b + 10) {
      if (brightness > 180 || saturation < 35) {
        return 'light_red';
      }
      return 'red';
    }

    // Fallback
    if (g > r && g > b) {
      return brightness > 150 ? 'light_green' : 'green';
    } else if (r > g && r > b) {
      return brightness > 150 ? 'light_red' : 'red';
    }

    return 'white';
  }

  /// Convert CameraImage to img.Image - OPTIMIZED
  Future<img.Image?> _convertCameraImageToImage(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // Create image
      final img.Image image = img.Image(width: width, height: height);

      final bytesY = cameraImage.planes[0].bytes;
      final bytesU = cameraImage.planes.length > 1 ? cameraImage.planes[1].bytes : null;
      final bytesV = cameraImage.planes.length > 2 ? cameraImage.planes[2].bytes : null;

      final int rowStrideY = cameraImage.planes[0].bytesPerRow;
      final int rowStrideU = cameraImage.planes.length > 1 ? cameraImage.planes[1].bytesPerRow : 0;
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
          int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round().clamp(0, 255);
          int b = (Y + (1.732446 * (U - 128))).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return image;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting camera image: $e');
      }
      return null;
    }
  }

  /// Quick text detection - FAST
  Future<bool> hasDetectableText(CameraImage cameraImage) async {
    try {
      final image = await _convertCameraImageToImage(cameraImage);
      if (image == null) return false;

      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      const sampleSize = 80;

      int darkPixels = 0;
      int totalSamples = 0;

      // Quick sampling with larger steps for speed
      for (int y = centerY - sampleSize; y < centerY + sampleSize; y += 5) {
        if (y < 0 || y >= image.height) continue;
        
        for (int x = centerX - sampleSize; x < centerX + sampleSize; x += 5) {
          if (x < 0 || x >= image.width) continue;

          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3;
          
          if (brightness < 120) {
            darkPixels++;
          }
          
          totalSamples++;
        }
      }

      return totalSamples > 0 && (darkPixels / totalSamples) > 0.1;
    } catch (e) {
      if (kDebugMode) {
        print('Error in text detection: $e');
      }
      return false;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}

/// Internal class for OCR results
class _OcrResult {
  final String text;
  final double confidence;

  _OcrResult({required this.text, required this.confidence});
}