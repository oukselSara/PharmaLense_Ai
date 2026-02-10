import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/camera_service.dart';
import '../models/scanned_label.dart';
import '../widgets/camera_preview_widget.dart';
import 'confirmation_screen.dart';

/// Premium camera screen with luxury design
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isInitializing = true;
  bool _isFlashlightOn = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessingImage = false;

  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initializeCamera();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _buttonController.dispose();
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFFF9800),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Server Offline',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A4D3C),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The AI detection server is not available. The app will use manual positioning mode instead.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B8B7F),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await context.read<CameraService>().retryServerConnection();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF14B57F),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B57F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startScanning() {
    final cameraService = context.read<CameraService>();
    cameraService.startScanning(_onLabelDetected);
  }

  void _onLabelDetected(ScannedLabel label) {
    HapticFeedback.mediumImpact();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PremiumConfirmationScreen(
          scannedLabel: label,
          onConfirm: _onConfirm,
          onRetry: _onRetry,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onConfirm(ScannedLabel label) {
    Navigator.pop(context);
    
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Label saved successfully',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF14B57F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );

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

  Future<void> _toggleFlashlight() async {
    final cameraService = context.read<CameraService>();
    
    try {
      await cameraService.toggleFlashlight();
      HapticFeedback.lightImpact();
      setState(() {
        _isFlashlightOn = !_isFlashlightOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to toggle flashlight'),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        _isProcessingImage = true;
      });

      final cameraService = context.read<CameraService>();
      await cameraService.stopScanning();

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isProcessingImage = false;
        });
        _startScanning();
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Color(0xFF14B57F),
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Processing image...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A4D3C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final imageFile = File(image.path);
      final scannedLabel = await cameraService.processUploadedImage(imageFile);

      if (mounted) {
        Navigator.pop(context);
      }

      setState(() {
        _isProcessingImage = false;
      });

      if (scannedLabel != null && scannedLabel.hasValidText) {
        if (mounted) {
          _onLabelDetected(scannedLabel);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No text detected in image'),
              backgroundColor: const Color(0xFFFF9800),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error processing image'),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        _startScanning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Scan Medicine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        actions: [
          Consumer<CameraService>(
            builder: (context, cameraService, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cameraService.serverConnected
                          ? const Color(0xFF14B57F).withValues(alpha: 0.3)
                          : const Color(0xFFFF9800).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      cameraService.serverConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () async {
                    if (!cameraService.serverConnected) {
                      await cameraService.retryServerConnection();
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: _isInitializing
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A4D3C),
                    Color(0xFF14B57F),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Initializing AI detection...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Consumer<CameraService>(
              builder: (context, cameraService, child) {
                if (!cameraService.isInitialized) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0A4D3C),
                          Color(0xFF14B57F),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            cameraService.statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _initializeCamera,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A4D3C),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // Camera preview
                    PremiumCameraPreviewWidget(
                      cameraController: cameraService.cameraController!,
                      isScanning: cameraService.isScanning,
                      labelDetected: cameraService.labelDetected,
                      statusMessage: cameraService.statusMessage,
                    ),

                    // Control buttons
                    _buildControlButtons(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      right: 20,
      bottom: 40,
      child: Column(
        children: [
          // Upload button
          _PremiumActionButton(
            icon: Icons.photo_library_rounded,
            isActive: false,
            isProcessing: _isProcessingImage,
            onPressed: _isProcessingImage ? null : _pickImageFromGallery,
          ),

          const SizedBox(height: 16),

          // Flashlight button
          _PremiumActionButton(
            icon: _isFlashlightOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            isActive: _isFlashlightOn,
            onPressed: _toggleFlashlight,
          ),
        ],
      ),
    );
  }
}

/// Premium action button widget
class _PremiumActionButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final bool isProcessing;
  final VoidCallback? onPressed;

  const _PremiumActionButton({
    required this.icon,
    this.isActive = false,
    this.isProcessing = false,
    this.onPressed,
  });

  @override
  State<_PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<_PremiumActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFFFFC107)
                : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: Color(0xFF14B57F),
                    strokeWidth: 3,
                  ),
                )
              : Icon(
                  widget.icon,
                  color: widget.isActive
                      ? Colors.black87
                      : const Color(0xFF0A4D3C),
                  size: 28,
                ),
        ),
      ),
    );
  }
}