import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scanned_label.dart';
import 'ocr_service.dart';

/// Service class for managing camera operations and continuous scanning
class CameraService extends ChangeNotifier {
  CameraController? _cameraController;
  final OcrService _ocrService = OcrService();

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isProcessingFrame = false;
  String _statusMessage = 'Initializing...';

  Timer? _scanTimer;
  static const Duration _scanInterval = Duration(milliseconds: 500);

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  String get statusMessage => _statusMessage;

  /// Initialize camera and request permissions
  Future<bool> initialize() async {
    try {
      _updateStatus('Requesting camera permission...');

      // Request camera permission
      final permissionStatus = await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        _updateStatus('Camera permission denied');
        return false;
      }

      _updateStatus('Loading camera...');

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _updateStatus('No camera found');
        return false;
      }

      // Use back camera (index 0 is typically back camera)
      final camera = cameras.first;

      // Initialize camera controller with medium resolution for balance
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // For ML Kit compatibility
      );

      await _cameraController!.initialize();

      _isInitialized = true;
      _updateStatus('Ready to scan');

      notifyListeners();
      return true;
    } catch (e) {
      _updateStatus('Camera initialization failed: $e');
      print('Camera initialization error: $e');
      return false;
    }
  }

  /// Start continuous scanning mode
  void startScanning(Function(ScannedLabel) onLabelDetected) {
    if (!_isInitialized || _isScanning) return;

    _isScanning = true;
    _updateStatus('Scanning for labels...');
    notifyListeners();

    // Start periodic scanning
    _scanTimer = Timer.periodic(_scanInterval, (timer) async {
      await _processFrame(onLabelDetected);
    });
  }

  /// Stop scanning mode
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _isScanning = false;
    _updateStatus('Ready to scan');
    notifyListeners();
  }

  /// Process a single camera frame
  Future<void> _processFrame(Function(ScannedLabel) onLabelDetected) async {
    if (_isProcessingFrame ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessingFrame = true;

    try {
      // Capture the current frame
      await _cameraController!
          .startImageStream((CameraImage cameraImage) async {
        // Stop image stream immediately
        await _cameraController!.stopImageStream();

        // Process the image with OCR
        final scannedLabel = await _ocrService.processImage(cameraImage);

        if (scannedLabel != null && scannedLabel.hasValidText) {
          // Stop scanning when text is found
          stopScanning();

          // Notify callback
          onLabelDetected(scannedLabel);
        }
      });
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Alternative frame processing using single image capture
  Future<void> processCurrentFrame(
      Function(ScannedLabel) onLabelDetected) async {
    if (_isProcessingFrame || !_isInitialized) return;

    _isProcessingFrame = true;
    _updateStatus('Processing image...');
    notifyListeners();

    try {
      // Start and immediately process image stream
      await _cameraController!.startImageStream((CameraImage image) async {
        // Stop stream immediately after getting first frame
        await _cameraController!.stopImageStream();

        // Process the frame
        final scannedLabel = await _ocrService.processImage(image);

        if (scannedLabel != null && scannedLabel.hasValidText) {
          stopScanning();
          onLabelDetected(scannedLabel);
        } else {
          _updateStatus('No text detected, keep scanning...');
          notifyListeners();
        }

        _isProcessingFrame = false;
      });
    } catch (e) {
      print('Error in processCurrentFrame: $e');
      _updateStatus('Error processing frame');
      _isProcessingFrame = false;
      notifyListeners();
    }
  }

  /// Update status message
  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  /// Pause camera (useful when navigating away)
  void pause() {
    stopScanning();
  }

  /// Resume camera operations
  void resume() {
    if (_isInitialized) {
      _updateStatus('Ready to scan');
      notifyListeners();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    stopScanning();
    _cameraController?.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}
