import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_screen.dart';
import 'invoice_scan_screen.dart';

/// Premium home screen with luxury design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();
    
    // Card entrance animation
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );

    _cardController.forward();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FDFB), // Soft mint
              Color(0xFFFFFFFF), // White
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Premium header
              _buildPremiumHeader(),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Welcome section
                      _buildWelcomeSection(),

                      const SizedBox(height: 36),

                      // Scan options
                      _buildScanOptions(),

                      const SizedBox(height: 32),

                      // Features section
                      _buildFeaturesSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          // Logo - Bigger size for better visibility
          Container(
            width: 72,  // Increased from 48
            height: 72, // Increased from 48
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18), // Increased from 14
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B57F).withValues(alpha: 0.2),
                  blurRadius: 16, // Increased from 12
                  offset: const Offset(0, 6), // Increased from 4
                ),
              ],
            ),
            padding: const EdgeInsets.all(14), // Increased from 8
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 16), // Increased from 14

          // App name
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PharmaLens',
                  style: TextStyle(
                    fontSize: 24, // Increased from 22
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A4D3C),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Professional Scanner',
                  style: TextStyle(
                    fontSize: 13, // Increased from 12
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B8B7F),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Settings button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE8F5F1),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                size: 22,
                color: Color(0xFF0A4D3C),
              ),
              onPressed: () {
                // Settings action
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you\nlike to scan?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A4D3C),
            height: 1.2,
            letterSpacing: -1.0,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'AI-powered text extraction from medical documents',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B8B7F),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScanOptions() {
    return Column(
      children: [
        // Medicine Scanner - Primary action
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_cardAnimation),
          child: FadeTransition(
            opacity: _cardAnimation,
            child: _PremiumScanCard(
              icon: Icons.medication_rounded,
              title: 'Scan Medicine Label',
              subtitle: 'Extract text from medicine packaging',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A4D3C),
                  Color(0xFF14B57F),
                ],
              ),
              isPrimary: true,
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const CameraScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Invoice Scanner - Secondary action
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _cardAnimation,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _cardAnimation,
              curve: const Interval(0.2, 1.0),
            ),
            child: _PremiumScanCard(
              icon: Icons.receipt_long_rounded,
              title: 'Scan Invoice',
              subtitle: 'Extract data from invoices & receipts',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8FDFB),
                ],
              ),
              isPrimary: false,
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const InvoiceScanScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _cardAnimation,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _cardAnimation,
          curve: const Interval(0.4, 1.0),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A4D3C),
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI-Powered',
                    subtitle: 'Advanced OCR',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.speed_rounded,
                    title: 'Lightning Fast',
                    subtitle: '1-2 seconds',
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.shield_rounded,
                    title: 'Secure',
                    subtitle: 'On-device',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.offline_bolt_rounded,
                    title: 'Works Offline',
                    subtitle: 'No internet',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium scan card widget
class _PremiumScanCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PremiumScanCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_PremiumScanCard> createState() => _PremiumScanCardState();
}

class _PremiumScanCardState extends State<_PremiumScanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary
                    ? const Color(0xFF14B57F).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: widget.isPrimary ? 20 : 8,
                offset: Offset(0, widget.isPrimary ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isPrimary
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF0A4D3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: widget.isPrimary
                      ? Colors.white
                      : const Color(0xFF0A4D3C),
                ),
              ),

              const SizedBox(width: 18),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: widget.isPrimary
                            ? Colors.white
                            : const Color(0xFF0A4D3C),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.isPrimary
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF6B8B7F),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.isPrimary
                    ? Colors.white
                    : const Color(0xFF0A4D3C),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feature card widget
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8F5F1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A4D3C),
                  Color(0xFF14B57F),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A4D3C),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B8B7F),
            ),
          ),
        ],
      ),
    );
  }
}