import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scanned_label.dart';
import 'ocr_service.dart';
import 'label_detection_service.dart';

/// Enhanced camera service with automatic YOLO-based label detection
class CameraService extends ChangeNotifier {
  CameraController? _cameraController;
  final OcrService _ocrService = OcrService();
  final YoloLabelDetectionService _yoloService = YoloLabelDetectionService();

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isProcessingFrame = false;
  bool _labelDetected = false;
  bool _serverConnected = false;
  String _statusMessage = 'Initializing...';

  Timer? _scanTimer;
  static const Duration _scanInterval = Duration(milliseconds: 300); // Faster for YOLO
  
  CameraImage? _currentFrame;
  DetectionResult? _currentDetection;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get labelDetected => _labelDetected;
  bool get serverConnected => _serverConnected;
  String get statusMessage => _statusMessage;
  DetectionResult? get currentDetection => _currentDetection;

  /// Initialize camera and check server connection
  Future<bool> initialize() async {
    try {
      _updateStatus('Checking server connection...');

      // Check if YOLO backend is available
      _serverConnected = await _yoloService.checkServerConnection();
      
      if (!_serverConnected) {
        _updateStatus('⚠️ Detection server offline - using fallback mode');
        // Continue anyway - we can use OCR-only mode
      }

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

      // Use back camera
      final camera = cameras.first;

      // Initialize camera controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high, // Higher res for better YOLO detection
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Set focus and exposure modes
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      _isInitialized = true;
      
      if (_serverConnected) {
        _updateStatus('✅ Ready - AI detection active');
      } else {
        _updateStatus('⚠️ Ready - Manual mode (server offline)');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _updateStatus('Camera initialization failed: $e');
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
      return false;
    }
  }

  /// Start automatic scanning with YOLO detection
  void startScanning(Function(ScannedLabel) onLabelDetected) {
    if (!_isInitialized || _isScanning) return;

    _isScanning = true;
    _labelDetected = false;
    _currentDetection = null;
    
    if (_serverConnected) {
      _updateStatus('🔍 Scanning for labels...');
    } else {
      _updateStatus('📷 Position label in frame');
    }
    
    notifyListeners();

    // Start image stream
    _startImageStream();

    // Start periodic YOLO detection
    _scanTimer = Timer.periodic(_scanInterval, (timer) async {
      if (_currentFrame != null && !_isProcessingFrame) {
        await _processFrameWithYolo(_currentFrame!, onLabelDetected);
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
        _currentFrame = image;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error starting image stream: $e');
      }
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
      if (kDebugMode) {
        print('Error stopping image stream: $e');
      }
    }
    
    _currentFrame = null;
  }

  /// Process frame with YOLO detection
  Future<void> _processFrameWithYolo(
    CameraImage image,
    Function(ScannedLabel) onLabelDetected,
  ) async {
    if (_isProcessingFrame) return;

    _isProcessingFrame = true;

    try {
      if (_serverConnected) {
        // Use YOLO backend for detection
        final detection = await _yoloService.detectLive(image);

        if (detection != null) {
          // Label detected!
          _currentDetection = detection;
          _labelDetected = true;
          _updateStatus('✅ Label found! Hold steady...');
          notifyListeners();

          // Wait a moment for stabilization
          await Future.delayed(const Duration(milliseconds: 800));

          // Now perform OCR on the detected region
          await _performOcrOnDetection(image, onLabelDetected);
        } else {
          // No detection - keep scanning
          _currentDetection = null;
          _labelDetected = false;
          if (_isScanning) {
            _updateStatus('🔍 Scanning for labels...');
            notifyListeners();
          }
        }
      } else {
        // Fallback: Use OCR-based detection (slower)
        await _processFrameWithOcr(image, onLabelDetected);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing frame: $e');
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Perform OCR on detected label region
  Future<void> _performOcrOnDetection(
    CameraImage image,
    Function(ScannedLabel) onLabelDetected,
  ) async {
    try {
      _updateStatus('📝 Reading text...');
      notifyListeners();

      // Process with OCR and color detection
      final scannedLabel = await _ocrService.processImageWithColor(image);

      if (scannedLabel != null && scannedLabel.hasValidText) {
        // Success! Stop scanning
        _scanTimer?.cancel();
        await _stopImageStream();
        
        _isScanning = false;
        _updateStatus('✅ Text extracted successfully!');
        notifyListeners();

        // Notify callback
        onLabelDetected(scannedLabel);
      } else {
        // No text found, keep trying
        _updateStatus('⚠️ No text detected, repositioning...');
        _labelDetected = false;
        _currentDetection = null;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in OCR: $e');
      }
      _updateStatus('❌ OCR failed, retrying...');
      _labelDetected = false;
      _currentDetection = null;
      notifyListeners();
    }
  }

  /// Fallback OCR-based detection (when server offline)
  Future<void> _processFrameWithOcr(
    CameraImage image,
    Function(ScannedLabel) onLabelDetected,
  ) async {
    try {
      // Quick text detection check
      final hasText = await _ocrService.hasDetectableText(image);

      if (hasText) {
        _labelDetected = true;
        _updateStatus('📝 Text detected! Reading...');
        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 500));

        final scannedLabel = await _ocrService.processImageWithColor(image);

        if (scannedLabel != null && scannedLabel.hasValidText) {
          _scanTimer?.cancel();
          await _stopImageStream();
          
          _isScanning = false;
          _updateStatus('✅ Text extracted!');
          notifyListeners();

          onLabelDetected(scannedLabel);
        }
      } else {
        _labelDetected = false;
        if (_isScanning) {
          _updateStatus('📷 Position label in frame');
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in OCR fallback: $e');
      }
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    
    await _stopImageStream();
    
    _isScanning = false;
    _labelDetected = false;
    _currentDetection = null;
    _updateStatus('Ready to scan');
    notifyListeners();
  }

  /// Update status message
  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  /// Pause camera
  Future<void> pause() async {
    await stopScanning();
  }

  /// Resume camera
  Future<void> resume() async {
    if (_isInitialized) {
      _updateStatus(_serverConnected 
          ? '✅ Ready - AI detection active' 
          : '⚠️ Ready - Manual mode');
      notifyListeners();
    }
  }

  /// Retry server connection
  Future<void> retryServerConnection() async {
    _updateStatus('Checking server...');
    notifyListeners();
    
    _serverConnected = await _yoloService.checkServerConnection();
    
    if (_serverConnected) {
      _updateStatus('✅ Server connected!');
    } else {
      _updateStatus('⚠️ Server offline - using manual mode');
    }
    
    notifyListeners();
  }

  /// Toggle flashlight on/off
  Future<void> toggleFlashlight() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    try {
      final currentFlashMode = _cameraController!.value.flashMode;
      
      if (currentFlashMode == FlashMode.off) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      } else {
        await _cameraController!.setFlashMode(FlashMode.off);
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling flashlight: $e');
      }
      throw Exception('Failed to toggle flashlight');
    }
  }

  /// Get current flashlight state
  bool get isFlashlightOn {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }
    return _cameraController!.value.flashMode == FlashMode.torch;
  }

  /// Process uploaded image from gallery
  Future<ScannedLabel?> processUploadedImage(File imageFile) async {
    try {
      _updateStatus('Processing uploaded image...');
      notifyListeners();

      // Read image file and process with OCR
      final scannedLabel = await _ocrService.processImageFile(imageFile);

      if (scannedLabel != null && scannedLabel.hasValidText) {
        _updateStatus('Text extracted successfully!');
        return scannedLabel;
      } else {
        _updateStatus('No text found in image');
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing uploaded image: $e');
      }
      _updateStatus('Failed to process image');
      return null;
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