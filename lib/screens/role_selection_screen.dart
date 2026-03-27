import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KovaSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Who is using this device?',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: KovaColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Parent Option
              _buildRoleCard(
                context: context,
                title: 'I am a Parent',
                subtitle: 'Monitor and protect your child',
                icon: Icons.shield_outlined,
                onTap: () {
                  Navigator.of(context).pushNamed(KovaRoutes.welcome);
                },
              ),

              const SizedBox(height: 24),

              // Child Option
              _buildRoleCard(
                context: context,
                title: 'I am a Child',
                subtitle: 'Set up protection on this device',
                icon: Icons.child_care_outlined,
                onTap: () {
                  Navigator.of(context).pushNamed(KovaRoutes.childWelcome);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KovaRadius.card),
      child: Container(
        padding: const EdgeInsets.all(KovaSpacing.lg),
        decoration: BoxDecoration(
          color: KovaColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(KovaRadius.card),
          border: Border.all(
            color: KovaColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: KovaColors.primary, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: KovaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KovaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: KovaColors.primary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
