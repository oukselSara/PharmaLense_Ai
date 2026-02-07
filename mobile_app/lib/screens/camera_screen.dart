import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../models/scanned_label.dart';
import '../widgets/camera_preview_widget.dart';
import 'confirmation_screen.dart';

/// Camera screen with automatic YOLO-based label detection
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

                return CameraPreviewWidget(
                  cameraController: cameraService.cameraController!,
                  isScanning: cameraService.isScanning,
                  labelDetected: cameraService.labelDetected,
                  statusMessage: cameraService.statusMessage,
                  detectionBox: cameraService.currentDetection,
                );
              },
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
              icon: Icons.center_focus_strong,
              title: 'How it works',
              description: 'Just point at a medicine label',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.timer,
              title: 'Fast & Accurate',
              description: 'Captures and reads automatically',
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