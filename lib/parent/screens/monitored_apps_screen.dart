// monitored_apps_screen.dart — KOVA Monitored Apps List
// Shows all monitored apps with their connection status
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';

class MonitoredAppsScreen extends StatefulWidget {
  const MonitoredAppsScreen({super.key});

  @override
  State<MonitoredAppsScreen> createState() => _MonitoredAppsScreenState();
}

class _MonitoredAppsScreenState extends State<MonitoredAppsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;

  // App data
  static const _apps = [
    _AppData(
      name: 'WhatsApp',
      subtitle: '',
      iconData: Icons.chat_rounded,
      iconColor: Color(0xFF25D366),
      badgeText: 'Connected',
      badgeColor: Color(0xFF2ECC71),
      badgeIcon: Icons.check_circle_rounded,
    ),
    _AppData(
      name: 'TikTok',
      subtitle: 'No action needed',
      iconData: Icons.music_note_rounded,
      iconColor: Color(0xFF010101),
      badgeText: 'Automatic',
      badgeColor: Color(0xFF7C4DFF),
      badgeIcon: Icons.auto_awesome_rounded,
    ),
    _AppData(
      name: 'Facebook',
      subtitle: 'No action needed',
      iconData: Icons.facebook_rounded,
      iconColor: Color(0xFF1877F2),
      badgeText: 'Automatic',
      badgeColor: Color(0xFF7C4DFF),
      badgeIcon: Icons.auto_awesome_rounded,
    ),
    _AppData(
      name: 'Instagram',
      subtitle: 'No action needed',
      iconData: Icons.camera_alt_rounded,
      iconColor: Color(0xFFE4405F),
      badgeText: 'Automatic',
      badgeColor: Color(0xFF7C4DFF),
      badgeIcon: Icons.auto_awesome_rounded,
    ),
    _AppData(
      name: 'SMS',
      subtitle: 'No action needed',
      iconData: Icons.sms_rounded,
      iconColor: Color(0xFF7C4DFF),
      badgeText: 'Automatic',
      badgeColor: Color(0xFF7C4DFF),
      badgeIcon: Icons.auto_awesome_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Animation<double> _itemFade(int index) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _itemSlide(int index) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _onContinue() {
    // Navigate to connect child screen
    context.go(AppRoutes.parentConnectChild);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _staggerCtrl,
          builder: (context, _) {
            return Column(
              children: [
                // ── Back button ──
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 24, top: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: KovaColors.textPrimary,
                        iconSize: 20,
                        onPressed: () => context.pop(),
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

                        // Title
                        SlideTransition(
                          position: _itemSlide(0),
                          child: Opacity(
                            opacity: _itemFade(0).value,
                            child: Text(
                              'Monitored apps',
                              style: GoogleFonts.nunito(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: KovaColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        SlideTransition(
                          position: _itemSlide(0),
                          child: Opacity(
                            opacity: _itemFade(0).value,
                            child: Text(
                              'These apps are now being monitored for your child\'s safety.',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: KovaColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // App list
                        ...List.generate(_apps.length, (i) {
                          return SlideTransition(
                            position: _itemSlide(i + 1),
                            child: Opacity(
                              opacity: _itemFade(i + 1).value,
                              child: _buildAppCard(_apps[i]),
                            ),
                          );
                        }),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Continue button ──
                Padding(
                  padding: const EdgeInsets.all(KovaSpacing.lg),
                  child: SlideTransition(
                    position: _itemSlide(_apps.length + 1),
                    child: Opacity(
                      opacity: _itemFade(_apps.length + 1).value,
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KovaColors.primary,
                            foregroundColor: KovaColors.textOnDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Continue',
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

  Widget _buildAppCard(_AppData app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KovaColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: KovaColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: app.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(app.iconData, color: app.iconColor, size: 24),
          ),
          const SizedBox(width: 14),

          // App name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KovaColors.textPrimary,
                  ),
                ),
                if (app.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    app.subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: KovaColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: app.badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(app.badgeIcon, size: 13, color: app.badgeColor),
                const SizedBox(width: 4),
                Text(
                  app.badgeText,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: app.badgeColor,
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

// ── App data model ──
class _AppData {
  final String name;
  final String subtitle;
  final IconData iconData;
  final Color iconColor;
  final String badgeText;
  final Color badgeColor;
  final IconData badgeIcon;

  const _AppData({
    required this.name,
    required this.subtitle,
    required this.iconData,
    required this.iconColor,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeIcon,
  });
}
