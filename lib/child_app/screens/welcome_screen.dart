import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/kova_theme.dart';
import '../widgets/kova_logo.dart';
import 'accessibility_setup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Logo
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const KovaLogo(
                        width: 80,
                        height: 64,
                        color: KovaTheme.primaryBlue,
                      ),
                      Text(
                        "OVA",
                        style: GoogleFonts.audiowide(
                          fontSize: 44,
                          color: KovaTheme.primaryBlue,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Every parent is a chief",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: KovaTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              // Center Graphic
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: KovaTheme.primaryBlue.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 80,
                    color: KovaTheme.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Features List
              const Column(
                children: [
                  _FeatureItem(
                    icon: Icons.smartphone_rounded,
                    text: "Real-time monitoring on WhatsApp, TikTok, Facebook",
                  ),
                  SizedBox(height: 24),
                  _FeatureItem(
                    icon: Icons.notifications_none_rounded,
                    text: "Instant alerts when dangerous content is detected",
                  ),
                  SizedBox(height: 24),
                  _FeatureItem(
                    icon: Icons.check_circle_outline_rounded,
                    text: "Total control from your own phone",
                  ),
                ],
              ),

              const Spacer(),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccessibilitySetupScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KovaTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Start configuration",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: KovaTheme.primaryBlue, size: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1E293B), // Slate 800
            ),
          ),
        ),
      ],
    );
  }
}
