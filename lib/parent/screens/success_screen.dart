// success_screen.dart — Final Setup Confirmation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/providers/app_state.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),

                        // ── Success Icon ──
                        Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: KovaColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: KovaColors.primary,
                              size: 80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'KOVA is active on Alex\'s phone!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: KovaColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          'Setup is complete. Monitoring and protection are now running in the background.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: KovaColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Status list
                        _buildStatusItem(
                          Icons.chat_rounded,
                          'WhatsApp',
                          'Monitoring Active',
                        ),
                        _buildStatusItem(
                          Icons.music_note_rounded,
                          'TikTok',
                          'Monitoring Active',
                        ),
                        _buildStatusItem(
                          Icons.facebook_rounded,
                          'Facebook',
                          'Monitoring Active',
                        ),

                        const SizedBox(height: 40),

                        // Banner info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: KovaColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: KovaColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility_off_rounded,
                                color: KovaColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'KOVA is now invisible on your child\'s device to ensure continuous safety.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: KovaColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ── Dashboard Button ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.read<AppState>().markLoggedIn();
                    if (!context.mounted) return;
                    context.go(AppRoutes.parentDashboard);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KovaColors.primary,
                    foregroundColor: KovaColors.textOnDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Go to Dashboard',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String title, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: KovaColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: KovaColors.textPrimary,
              ),
            ),
          ),
          Text(
            status,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }
}
