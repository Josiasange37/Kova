// splash_screen.dart — KOVA 2-Phase Animated Splash Flow
// Phase 1: Logo icon only (centered, fade+scale in)
// Phase 2: "OVA" text slides in, tagline fades up, logo shifts

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
  // Current phase: 0=initial, 1=logo only, 2=logo+OVA+tagline
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
    _ovaSlide = Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero)
        .animate(
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
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _brandCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
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

    // Wait for brand reveal to settle then navigate to Welcome
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(KovaRoutes.roleSelection);
  }

  @override
  void dispose() {
    _logoEntranceCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: KovaColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoEntranceCtrl, _brandCtrl]),
        builder: (context, _) {
          final logoY = screenHeight / 2;
          const logoIconSize = 72.0;

          return SizedBox.expand(
            child: Stack(
              children: [
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
                              SvgPicture.asset(
                                KovaAssets.logoSvg,
                                width: logoIconSize,
                                height: logoIconSize,
                                colorFilter: const ColorFilter.mode(
                                  KovaColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
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

                      // Tagline
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
              ],
            ),
          );
        },
      ),
    );
  }
}
