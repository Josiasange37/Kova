// splash_screen.dart — KOVA 3-Phase Animated Splash Flow
// Phase 1: Logo icon only (centered, fade+scale in)
// Phase 2: "OVA" text slides in, tagline fades up, logo shifts
// Phase 3: Logo moves to top, shield + features + button animate in

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Current phase: 0=initial, 1=logo only, 2=logo+OVA+tagline, 3=welcome
  int _phase = 0;

  // Phase 1: Logo entrance
  late final AnimationController _logoEntranceCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Phase 2: OVA text + tagline
  late final AnimationController _brandCtrl;
  late final Animation<double> _ovaFade;
  late final Animation<Offset> _ovaSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  // Phase 3: Transition to welcome
  late final AnimationController _welcomeCtrl;
  late final Animation<double> _welcomeProgress;

  // Phase 3 content staggered reveals
  late final AnimationController _contentCtrl;
  late final Animation<double> _shieldFade;
  late final Animation<double> _shieldScale;
  late final Animation<double> _feature1Fade;
  late final Animation<Offset> _feature1Slide;
  late final Animation<double> _feature2Fade;
  late final Animation<Offset> _feature2Slide;
  late final Animation<double> _feature3Fade;
  late final Animation<Offset> _feature3Slide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startPhaseSequence();
  }

  void _initAnimations() {
    // ── Phase 1: Logo entrance ──
    _logoEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoEntranceCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _logoEntranceCtrl, curve: Curves.easeOutBack),
    );

    // ── Phase 2: Brand reveal ──
    _brandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ovaFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _brandCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _ovaSlide = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _brandCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _brandCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _brandCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Phase 3: Welcome transition (logo moves to top) ──
    _welcomeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _welcomeProgress = CurvedAnimation(
      parent: _welcomeCtrl,
      curve: Curves.easeInOutCubic,
    );

    // ── Phase 3: Content staggered reveals ──
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Shield
    _shieldFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _shieldScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Feature 1
    _feature1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _feature1Slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    // Feature 2
    _feature2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _feature2Slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    // Feature 3
    _feature3Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );
    _feature3Slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    // Button
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _startPhaseSequence() async {
    // Phase 1: Logo icon appears
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _phase = 1);
    _logoEntranceCtrl.forward();

    // Wait for logo to settle
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Phase 2: Brand name + tagline
    setState(() => _phase = 2);
    _brandCtrl.forward();

    // Wait for brand reveal to settle
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Phase 3: Welcome screen
    setState(() => _phase = 3);
    _welcomeCtrl.forward();

    // Stagger the content after logo repositions
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _logoEntranceCtrl.dispose();
    _brandCtrl.dispose();
    _welcomeCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;


    return Scaffold(
      backgroundColor: KovaColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoEntranceCtrl,
          _brandCtrl,
          _welcomeCtrl,
          _contentCtrl,
        ]),
        builder: (context, _) {
          // ── Calculate logo position ──
          // In phases 1 & 2: centered on screen
          // In phase 3: animate to top area
          final centerY = screenHeight / 2;
          final topY = screenHeight * 0.14;
          final logoY =
              _phase >= 3
                  ? centerY + (topY - centerY) * _welcomeProgress.value
                  : centerY;

          // Logo size shrinks slightly in phase 3
          final logoIconSize =
              _phase >= 3 ? 72.0 + (80.0 - 72.0) * _welcomeProgress.value : 72.0;

          return SizedBox.expand(
            child: Stack(
              children: [
                // ── Logo + Brand (positioned) ──
                Positioned(
                  top: logoY - logoIconSize / 2 - 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo icon + "OVA" row
                      Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // K icon
                              SvgPicture.asset(
                                KovaAssets.logoSvg,
                                width: logoIconSize,
                                height: logoIconSize,
                                colorFilter: const ColorFilter.mode(
                                  KovaColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              // "OVA" text — only visible from phase 2+
                              if (_phase >= 2)
                                SlideTransition(
                                  position: _ovaSlide,
                                  child: Opacity(
                                    opacity: _ovaFade.value,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: Text(
                                        'OVA',
                                        style: GoogleFonts.nunito(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          color: KovaColors.primary,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Tagline — only visible from phase 2+
                      if (_phase >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SlideTransition(
                            position: _taglineSlide,
                            child: Opacity(
                              opacity: _taglineFade.value,
                              child: Text(
                                'Every parent is a chief',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: KovaColors.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Phase 3: Welcome Content ──
                if (_phase >= 3) ...[
                  // Shield icon
                  Positioned(
                    top: screenHeight * 0.38,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _shieldFade.value,
                      child: Transform.scale(
                        scale: _shieldScale.value,
                        child: _buildShieldIcon(),
                      ),
                    ),
                  ),

                  // Features list
                  Positioned(
                    top: screenHeight * 0.55,
                    left: KovaSpacing.lg,
                    right: KovaSpacing.lg,
                    child: Column(
                      children: [
                        // Feature 1
                        SlideTransition(
                          position: _feature1Slide,
                          child: Opacity(
                            opacity: _feature1Fade.value,
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
                          child: Opacity(
                            opacity: _feature2Fade.value,
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
                          child: Opacity(
                            opacity: _feature3Fade.value,
                            child: _buildFeatureRow(
                              icon: Icons.verified_outlined,
                              text: 'Total control from your own phone',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // "Start configuration" button
                  Positioned(
                    bottom: screenHeight * 0.08,
                    left: KovaSpacing.lg,
                    right: KovaSpacing.lg,
                    child: SlideTransition(
                      position: _buttonSlide,
                      child: Opacity(
                        opacity: _buttonFade.value,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed(
                                KovaRoutes.parentProfile,
                              );
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
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shield icon with circular light-blue background
  Widget _buildShieldIcon() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KovaColors.primary.withValues(alpha: 0.08),
        ),
        child: Center(
          child: Icon(
            Icons.shield_outlined,
            size: 48,
            color: KovaColors.primary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  /// Feature row with icon + text
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
