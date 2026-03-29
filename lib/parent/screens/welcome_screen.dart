import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _contentCtrl;

  // Logo header
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Shield
  late final Animation<double> _shieldFade;
  late final Animation<double> _shieldScale;

  // Features
  late final Animation<double> _feature1Fade;
  late final Animation<Offset> _feature1Slide;
  late final Animation<double> _feature2Fade;
  late final Animation<Offset> _feature2Slide;
  late final Animation<double> _feature3Fade;
  late final Animation<Offset> _feature3Slide;

  // Button
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _contentCtrl.forward();
  }

  void _initAnimations() {
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Logo header
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
    );

    // Shield
    _shieldFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _shieldScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOutBack),
      ),
    );

    // Feature 1
    _feature1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.3, 0.55, curve: Curves.easeOut),
      ),
    );
    _feature1Slide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.3, 0.55, curve: Curves.easeOut),
          ),
        );

    // Feature 2
    _feature2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.42, 0.67, curve: Curves.easeOut),
      ),
    );
    _feature2Slide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.42, 0.67, curve: Curves.easeOut),
          ),
        );

    // Feature 3
    _feature3Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.54, 0.79, curve: Curves.easeOut),
      ),
    );
    _feature3Slide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.54, 0.79, curve: Curves.easeOut),
          ),
        );

    // Button
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentCtrl,
            curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
          ),
        );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _contentCtrl,
          builder: (context, _) {
            return Column(
              children: [
                // ── Top section: Logo + Tagline + Shield ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Logo row: K icon + "OVA"
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                KovaAssets.logoSvg,
                                width: 52,
                                height: 52,
                                colorFilter: const ColorFilter.mode(
                                  KovaColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  'OVA',
                                  style: GoogleFonts.nunito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: KovaColors.primary,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      FadeTransition(
                        opacity: _logoFade,
                        child: Text(
                          'Every parent is a chief',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: KovaColors.primary.withValues(alpha: 0.55),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Shield icon
                      FadeTransition(
                        opacity: _shieldFade,
                        child: ScaleTransition(
                          scale: _shieldScale,
                          child: _buildShieldIcon(),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Features list ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KovaSpacing.lg,
                        ),
                        child: Column(
                          children: [
                            // Feature 1
                            SlideTransition(
                              position: _feature1Slide,
                              child: FadeTransition(
                                opacity: _feature1Fade,
                                child: _buildFeatureRow(
                                  icon: Icons.phone_android_rounded,
                                  text:
                                      'Real-time monitoring on WhatsApp,\nTikTok, Facebook',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Feature 2
                            SlideTransition(
                              position: _feature2Slide,
                              child: FadeTransition(
                                opacity: _feature2Fade,
                                child: _buildFeatureRow(
                                  icon: Icons.notifications_outlined,
                                  text:
                                      'Instant alerts when dangerous content\nis detected',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Feature 3
                            SlideTransition(
                              position: _feature3Slide,
                              child: FadeTransition(
                                opacity: _feature3Fade,
                                child: _buildFeatureRow(
                                  icon: Icons.verified_outlined,
                                  text: 'Total control from your own phone',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom: "Start configuration" button ──
                Padding(
                  padding: EdgeInsets.only(
                    left: KovaSpacing.lg,
                    right: KovaSpacing.lg,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            context.go(AppRoutes.parentProfile);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KovaColors.primary,
                            foregroundColor: KovaColors.textOnDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                KovaRadius.pill,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Start configuration',
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

  Widget _buildShieldIcon() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KovaColors.primary.withValues(alpha: 0.06),
        ),
        child: Center(
          child: Icon(
            Icons.shield_outlined,
            size: 56,
            color: KovaColors.primary.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: KovaColors.primary.withValues(alpha: 0.06),
          ),
          child: Icon(icon, size: 20, color: KovaColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: KovaColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
