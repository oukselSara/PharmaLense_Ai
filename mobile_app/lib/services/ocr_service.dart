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
    // Using default script (Latin) - can be configured for other languages
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Process a camera image and extract text
  /// Returns null if already processing or no text found
  Future<ScannedLabel?> processImage(CameraImage cameraImage) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      // Convert CameraImage to InputImage format for ML Kit
      final inputImage = await _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) return null;

      // Perform text recognition
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract all text from blocks
      final String extractedText = _extractTextFromBlocks(recognizedText);

      if (extractedText.trim().isEmpty) {
        return null;
      }

      // Create and return ScannedLabel model
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

  /// Convert CameraImage to InputImage for ML Kit by encoding to JPEG and returning an InputImage from file path
  Future<InputImage?> _convertCameraImageToInputImage(
      CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // Create an Image buffer from package:image (aliased as img)
      final img.Image frame = img.Image(width: width, height: height);

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

          frame.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      // Encode as JPEG
      final jpeg = img.encodeJpg(frame);

      // Write to temp file
      final tempDir = Directory.systemTemp;
      final file = await File(
              '${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg')
          .writeAsBytes(jpeg);

      return InputImage.fromFilePath(file.path);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
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
  /// Used for real-time feedback without full OCR processing
  Future<bool> hasDetectableText(CameraImage cameraImage) async {
    try {
      final inputImage = await _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) return false;

      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Return true if we found at least one substantial text block
      return recognizedText.blocks.any(
          (block) => block.text.length > 3 && block.boundingBox.width > 30);
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
