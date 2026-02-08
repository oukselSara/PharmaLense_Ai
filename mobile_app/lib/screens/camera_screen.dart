import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/camera_service.dart';
import '../models/scanned_label.dart';
import '../widgets/camera_preview_widget.dart';
import 'confirmation_screen.dart';

/// Camera screen with automatic YOLO-based label detection, flashlight, and image upload
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  bool _isInitializing = true;
  bool _isFlashlightOn = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessingImage = false;

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
        // Check if server is connected and show info
        if (!cameraService.serverConnected) {
          _showServerOfflineDialog();
        }
        
        _startScanning();
      }
    }
  }

  void _showServerOfflineDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Detection Server Offline'),
          ],
        ),
        content: const Text(
          'The AI detection server is not available. '
          'The app will use manual positioning mode instead.\n\n'
          'To enable automatic detection:\n'
          '1. Start the Python backend server\n'
          '2. Restart the app',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to reconnect
              await context.read<CameraService>().retryServerConnection();
            },
            child: const Text('Retry Connection'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Label saved: ${label.text.substring(0, label.text.length > 30 ? 30 : label.text.length)}...',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Resume scanning
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startScanning();
      }
    });
  }

  void _onRetry() {
    Navigator.pop(context);
    _startScanning();
  }

  /// Toggle flashlight on/off
  Future<void> _toggleFlashlight() async {
    final cameraService = context.read<CameraService>();
    
    try {
      await cameraService.toggleFlashlight();
      setState(() {
        _isFlashlightOn = !_isFlashlightOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle flashlight: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pick image from gallery and process it
  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        _isProcessingImage = true;
      });

      // Stop scanning while processing image
      final cameraService = context.read<CameraService>();
      await cameraService.stopScanning();

      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isProcessingImage = false;
        });
        // Resume scanning
        _startScanning();
        return;
      }

      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text('Processing image...'),
              ],
            ),
          ),
        );
      }

      // Process the image
      final imageFile = File(image.path);
      final scannedLabel = await cameraService.processUploadedImage(imageFile);

      // Close processing dialog
      if (mounted) {
        Navigator.pop(context);
      }

      setState(() {
        _isProcessingImage = false;
      });

      if (scannedLabel != null && scannedLabel.hasValidText) {
        // Show confirmation screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmationScreen(
                scannedLabel: scannedLabel,
                onConfirm: _onConfirm,
                onRetry: () {
                  Navigator.pop(context);
                  _pickImageFromGallery(); // Let user pick another image
                },
              ),
            ),
          );
        }
      } else {
        // No text found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text detected in image. Please try another photo.'),
              backgroundColor: Colors.orange,
            ),
          );
          _startScanning();
        }
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _startScanning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'AI Label Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Server status indicator
          Consumer<CameraService>(
            builder: (context, cameraService, child) {
              return IconButton(
                icon: Icon(
                  cameraService.serverConnected 
                      ? Icons.cloud_done 
                      : Icons.cloud_off,
                  color: cameraService.serverConnected 
                      ? Colors.white 
                      : Colors.orange,
                ),
                onPressed: () async {
                  if (!cameraService.serverConnected) {
                    await cameraService.retryServerConnection();
                  } else {
                    _showInfoDialog();
                  }
                },
                tooltip: cameraService.serverConnected 
                    ? 'AI Detection Active' 
                    : 'Server Offline - Tap to retry',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
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
                    'Initializing AI detection...',
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

                return Stack(
                  children: [
                    // Camera preview with detection
                    CameraPreviewWidget(
                      cameraController: cameraService.cameraController!,
                      isScanning: cameraService.isScanning,
                      labelDetected: cameraService.labelDetected,
                      statusMessage: cameraService.statusMessage,
                      detectionBox: cameraService.currentDetection,
                    ),

                    // Control buttons overlay
                    _buildControlButtons(),
                  ],
                );
              },
            ),
    );
  }

  /// Build control buttons (flashlight, upload)
  Widget _buildControlButtons() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // Upload image button
          FloatingActionButton(
            heroTag: 'upload',
            onPressed: _isProcessingImage ? null : _pickImageFromGallery,
            backgroundColor: Colors.blue,
            tooltip: 'Upload Image',
            child: _isProcessingImage 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.photo_library, size: 28),
          ),

          const SizedBox(height: 16),

          // Flashlight toggle button
          FloatingActionButton(
            heroTag: 'flashlight',
            onPressed: _toggleFlashlight,
            backgroundColor: _isFlashlightOn ? Colors.yellow : Colors.white,
            tooltip: _isFlashlightOn ? 'Turn off flashlight' : 'Turn on flashlight',
            child: Icon(
              _isFlashlightOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashlightOn ? Colors.black : Colors.grey[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    final cameraService = context.read<CameraService>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Label Scanner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.auto_awesome,
              title: 'Automatic Detection',
              description: 'AI finds labels automatically',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: cameraService.serverConnected 
                  ? Icons.cloud_done 
                  : Icons.cloud_off,
              title: cameraService.serverConnected 
                  ? 'Server Connected' 
                  : 'Server Offline',
              description: cameraService.serverConnected
                  ? 'YOLO detection is active'
                  : 'Using manual mode',
              iconColor: cameraService.serverConnected 
                  ? Colors.green 
                  : Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.flash_on,
              title: 'Flashlight',
              description: 'Toggle for better visibility',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.photo_library,
              title: 'Upload Image',
              description: 'Process saved photos',
            ),
          ],
        ),
        actions: [
          if (!cameraService.serverConnected)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await cameraService.retryServerConnection();
              },
              child: const Text('Retry Server'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
    Color? iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? Colors.green, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}