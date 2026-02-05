import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/label_detection_service.dart';
import '../widgets/camera_preview_widget.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const CameraScreen({super.key, this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isDetecting = false;
  bool _isScanning = false;
  String _statusMessage = "Initializing camera...";
  DateTime _lastRequest = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = widget.cameras ?? await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = "No cameras available";
          });
        }
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _statusMessage = "Ready to scan";
        });
        _startLiveDetection();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
        });
      }
      print('Camera initialization error: $e');
    }
  }

  void _startLiveDetection() {
    if (mounted) {
      setState(() {
        _isScanning = true;
      });
    }

    Future.doWhile(() async {
      if (!_controller.value.isInitialized) return true;

      if (_isDetecting) return true;
      if (DateTime.now().difference(_lastRequest).inMilliseconds < 500) {
        return true;
      }

      _isDetecting = true;
      _lastRequest = DateTime.now();

      try {
        final file = await _controller.takePicture();
        await LabelDetectionService.detectLive(File(file.path));
      } catch (_) {}

      _isDetecting = false;
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraPreviewWidget(
        cameraController: _controller,
        isScanning: _isScanning,
        statusMessage: _statusMessage,
      ),
    );
  }
}
