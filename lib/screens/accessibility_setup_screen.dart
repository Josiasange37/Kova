// accessibility_setup_screen.dart — KOVA Accessibility Service Setup
// Step-by-step guide to enable KOVA accessibility service on the child's device.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class AccessibilitySetupScreen extends StatefulWidget {
  const AccessibilitySetupScreen({super.key});

  @override
  State<AccessibilitySetupScreen> createState() =>
      _AccessibilitySetupScreenState();
}

class _AccessibilitySetupScreenState extends State<AccessibilitySetupScreen>
    with SingleTickerProviderStateMixin {
  bool _isVerified = false;
  bool _isVerifying = false;

  // ── Entrance animations ──
  late AnimationController _entranceCtrl;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _step1Fade;
  late Animation<Offset> _step1Slide;
  late Animation<double> _step2Fade;
  late Animation<Offset> _step2Slide;
  late Animation<double> _step3Fade;
  late Animation<Offset> _step3Slide;
  late Animation<double> _step4Fade;
  late Animation<Offset> _step4Slide;
  late Animation<double> _bottomFade;
  late Animation<Offset> _bottomSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _entranceCtrl.forward();
  }

  void _initAnimations() {
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
          ),
        );

    _step1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.35, curve: Curves.easeOut),
      ),
    );
    _step1Slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.1, 0.35, curve: Curves.easeOutCubic),
          ),
        );

    _step2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _step2Slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
          ),
        );

    _step3Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _step3Slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _step4Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _step4Slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _bottomFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _bottomSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _onVerify() async {
    setState(() => _isVerifying = true);
    // Simulate verification delay
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _isVerified = true;
    });

    // Auto-navigate after success
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(KovaRoutes.success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, _) {
            return Column(
              children: [
                // ── Back button ──
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: KovaSpacing.lg,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: KovaColors.textPrimary,
                        iconSize: 20,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KovaSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),

                        // ── Title + subtitle ──
                        SlideTransition(
                          position: _titleSlide,
                          child: Opacity(
                            opacity: _titleFade.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Last step',
                                  style: GoogleFonts.nunito(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: KovaColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'To monitor TikTok and Facebook, enable KOVA in Android settings',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: KovaColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Step 1 ──
                        SlideTransition(
                          position: _step1Slide,
                          child: Opacity(
                            opacity: _step1Fade.value,
                            child: _buildStepCard(
                              number: 1,
                              icon: Icons.settings_rounded,
                              title: 'Open Android Settings',
                              subtitle:
                                  'Find the Settings app on your child\'s phone',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Step 2 ──
                        SlideTransition(
                          position: _step2Slide,
                          child: Opacity(
                            opacity: _step2Fade.value,
                            child: _buildStepCard(
                              number: 2,
                              icon: Icons.accessibility_new_rounded,
                              title: 'Tap Accessibility',
                              subtitle:
                                  'Look for Accessibility in Settings menu',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Step 3 ──
                        SlideTransition(
                          position: _step3Slide,
                          child: Opacity(
                            opacity: _step3Fade.value,
                            child: _buildStepCard(
                              number: 3,
                              icon: Icons.search_rounded,
                              title: 'Find KOVA in the list',
                              subtitle:
                                  'Scroll to find KOVA accessibility service',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Step 4 ──
                        SlideTransition(
                          position: _step4Slide,
                          child: Opacity(
                            opacity: _step4Fade.value,
                            child: _buildStepCard(
                              number: 4,
                              icon: Icons.toggle_on_rounded,
                              title: 'Enable the service',
                              subtitle: 'Toggle the switch to ON',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Success banner (only when verified) ──
                        if (_isVerified)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.scale(
                                  scale: 0.9 + (0.1 * value),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: KovaColors.success.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: KovaColors.success.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: KovaColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'KOVA accessibility service detected successfully!',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: KovaColors.success,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // ── Bottom: Verify button ──
                SlideTransition(
                  position: _bottomSlide,
                  child: Opacity(
                    opacity: _bottomFade.value,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: KovaSpacing.lg,
                        right: KovaSpacing.lg,
                        bottom: MediaQuery.of(context).padding.bottom + 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isVerifying || _isVerified)
                              ? null
                              : _onVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KovaColors.primary,
                            foregroundColor: KovaColors.textOnDark,
                            disabledBackgroundColor: KovaColors.primary
                                .withValues(alpha: 0.5),
                            disabledForegroundColor: KovaColors.textOnDark
                                .withValues(alpha: 0.7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                KovaRadius.pill,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifying
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: KovaColors.textOnDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Verifying...',
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'I\'ve enabled it — Verify',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a single numbered step card.
  Widget _buildStepCard({
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: KovaColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Step number
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KovaColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: KovaColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Icon
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KovaColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: KovaColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: KovaColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
