import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../models/scanned_label.dart';
import '../widgets/camera_preview_widget.dart';
import 'confirmation_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraService = context.read<CameraService>();
    
    if (state == AppLifecycleState.inactive) {
      cameraService.pause();
    } else if (state == AppLifecycleState.resumed) {
      cameraService.resume();
    }
  }

  Future<void> _initializeCamera() async {
    final cameraService = context.read<CameraService>();
    
    final initialized = await cameraService.initialize();
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });

      if (initialized) {
        _startScanning();
      }
    }
  }

  void _startScanning() {
    final cameraService = context.read<CameraService>();
    cameraService.startScanning(_onLabelDetected);
  }

  void _onLabelDetected(ScannedLabel label) {
    // Navigate to confirmation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmationScreen(
          scannedLabel: label,
          onConfirm: _onConfirm,
          onRetry: _onRetry,
        ),
      ),
    );
  }

  void _onConfirm(ScannedLabel label) {
    // Handle confirmation
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Label saved: ${label.text.substring(0, label.text.length > 30 ? 30 : label.text.length)}...'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Resume scanning after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startScanning();
      }
    });
  }

  void _onRetry() {
    // Go back and resume scanning
    Navigator.pop(context);
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Scan Medicine Label',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to Scan'),
                  content: const Text(
                    '1. Point camera at medicine label\n'
                    '2. Keep label within the frame\n'
                    '3. Hold steady for clear capture\n'
                    '4. App will auto-detect text',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : Consumer<CameraService>(
              builder: (context, cameraService, child) {
                if (!cameraService.isInitialized) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          cameraService.statusMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _initializeCamera,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return CameraPreviewWidget(
                  cameraController: cameraService.cameraController!,
                  isScanning: cameraService.isScanning,
                  statusMessage: cameraService.statusMessage,
                );
              },
            ),
    );
  }
}