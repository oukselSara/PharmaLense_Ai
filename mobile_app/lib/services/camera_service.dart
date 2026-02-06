import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' show Offset;
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
  bool _isFocusLocked = false;
  String _statusMessage = 'Initializing...';

  Timer? _scanTimer;
  static const Duration _scanInterval = Duration(milliseconds: 800);
  
  CameraImage? _currentFrame;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isFocusLocked => _isFocusLocked;
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

      // Set focus mode to auto
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

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
    _isFocusLocked = false;
    _updateStatus('Scanning for labels...');
    notifyListeners();

    // Start image stream for continuous capture
    _startImageStream();

    // Start periodic processing
    _scanTimer = Timer.periodic(_scanInterval, (timer) async {
      if (_currentFrame != null && !_isProcessingFrame) {
        await _processFrame(_currentFrame!, onLabelDetected);
      }
    });
  }

  /// Start image stream
  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) {
        // Store the latest frame
        _currentFrame = image;
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  /// Stop image stream
  Future<void> _stopImageStream() async {
    if (_cameraController == null) return;

    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      print('Error stopping image stream: $e');
    }
    
    _currentFrame = null;
  }

  /// Stop scanning mode
  Future<void> stopScanning() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    
    await _stopImageStream();
    
    _isScanning = false;
    _isFocusLocked = false;
    _updateStatus('Ready to scan');
    notifyListeners();
  }

  /// Process a single camera frame
  Future<void> _processFrame(
    CameraImage image,
    Function(ScannedLabel) onLabelDetected,
  ) async {
    if (_isProcessingFrame) return;

    _isProcessingFrame = true;

    try {
      // First, check if there's detectable text
      final hasText = await _ocrService.hasDetectableText(image);

      if (hasText && !_isFocusLocked) {
        // Lock focus on detected text area
        await _lockFocusOnLabel();
        _updateStatus('Label detected! Locking focus...');
        notifyListeners();

        // Wait for focus to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (_isFocusLocked || hasText) {
        // Process the full image with OCR and color detection
        final scannedLabel = await _ocrService.processImageWithColor(image);

        if (scannedLabel != null && scannedLabel.hasValidText) {
          // Stop scanning and image stream
          _scanTimer?.cancel();
          await _stopImageStream();
          
          _isScanning = false;
          _updateStatus('Text extracted successfully!');
          notifyListeners();

          // Notify callback
          onLabelDetected(scannedLabel);
        }
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Lock focus on detected label area
  Future<void> _lockFocusOnLabel() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Lock focus at center of frame (where label should be)
      await _cameraController!.setFocusPoint(const Offset(0.5, 0.5));
      await _cameraController!.setFocusMode(FocusMode.locked);
      
      // Lock exposure
      await _cameraController!.setExposurePoint(const Offset(0.5, 0.5));
      await _cameraController!.setExposureMode(ExposureMode.locked);
      
      _isFocusLocked = true;
    } catch (e) {
      print('Error locking focus: $e');
    }
  }

  /// Unlock focus
  Future<void> unlockFocus() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      _isFocusLocked = false;
    } catch (e) {
      print('Error unlocking focus: $e');
    }
  }

  /// Update status message
  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  /// Pause camera (useful when navigating away)
  Future<void> pause() async {
    await stopScanning();
    await unlockFocus();
  }

  /// Resume camera operations
  Future<void> resume() async {
    if (_isInitialized) {
      await unlockFocus();
      _updateStatus('Ready to scan');
      notifyListeners();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _scanTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}