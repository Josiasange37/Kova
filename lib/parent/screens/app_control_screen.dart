import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class AppControlScreen extends StatefulWidget {
  final bool isEmbedded;

  const AppControlScreen({super.key, this.isEmbedded = false});

  @override
  State<AppControlScreen> createState() => _AppControlScreenState();
}

class _AppControlScreenState extends State<AppControlScreen> {
  // Per-app state
  late List<_AppControlData> _apps;

  @override
  void initState() {
    super.initState();
    _apps = [
      _AppControlData(
        name: 'X',
        icon: FontAwesomeIcons.xTwitter,
        color: const Color(0xFF000000),
        alerts: 5,
        blocks: 2,
        enabled: true,
        sensitivity: 1,
        blocking: 0,
      ),
      _AppControlData(
        name: 'TikTok',
        icon: FontAwesomeIcons.tiktok,
        color: const Color(0xFF010101),
        alerts: 12,
        blocks: 5,
        enabled: true,
        sensitivity: 2,
        blocking: 2,
      ),
      _AppControlData(
        name: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        color: const Color(0xFFE4405F),
        alerts: 0,
        blocks: 0,
        enabled: true,
        sensitivity: 1,
        blocking: 1,
      ),
      _AppControlData(
        name: 'WhatsApp',
        icon: FontAwesomeIcons.whatsapp,
        color: const Color(0xFF25D366),
        alerts: 0,
        blocks: 3,
        enabled: true,
        sensitivity: 1,
        blocking: 1,
      ),
      _AppControlData(
        name: 'Facebook',
        icon: FontAwesomeIcons.facebook,
        color: const Color(0xFF1877F2),
        alerts: 0,
        blocks: 3,
        enabled: true,
        sensitivity: 1,
        blocking: 0,
      ),
      _AppControlData(
        name: 'SMS',
        icon: FontAwesomeIcons.solidComment,
        color: const Color(0xFF34C759),
        alerts: 1,
        blocks: 0,
        enabled: true,
        sensitivity: 0,
        blocking: 0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: KovaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Header (Back + Title) ──
          Row(
            children: [
              if (!widget.isEmbedded)
                _headerButton(
                  context,
                  FontAwesomeIcons.arrowLeft,
                  onTap: () => context.pop(),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'App control',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KovaColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select apps to manage everything perfectly.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 44), // Spacer for centering
            ],
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 22),

          // ── App cards ──
          ...List.generate(_apps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAppCard(i),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  App Card
  // ═══════════════════════════════════════════
  Widget _buildAppCard(int index) {
    final app = _apps[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: KovaColors.divider.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + name + stats + toggle ──
          Row(
            children: [
              // App icon in squircle-like container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: app.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: app.color, size: 28),
                    child: FaIcon(app.icon),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: KovaColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.alerts} alerts • ${app.blocks} blocks',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: app.enabled,
                  onChanged: (v) => setState(() => app.enabled = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: KovaColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE8E8E8),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 20),

          // ── Sensitivity Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sensitivity',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KovaColors.textPrimary,
                ),
              ),
              Text(
                _getSensitivityLabel(app.sensitivity),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: KovaColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSlider(
            value: app.sensitivity,
            onChanged: (v) => setState(() => app.sensitivity = v),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 20),

          // ── Manual block Section ──
          Text(
            'Manual block',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: KovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildManualBlockItem(index, 0, '30 min'),
              const SizedBox(width: 8),
              _buildManualBlockItem(index, 1, '1h'),
              const SizedBox(width: 8),
              _buildManualBlockItem(index, 2, '2h'),
              const SizedBox(width: 8),
              _buildManualBlockItem(index, 3, '∞'),
            ],
          ),
        ],
      ),
    );
  }

  String _getSensitivityLabel(int value) {
    switch (value) {
      case 0:
        return 'Strict';
      case 2:
        return 'Permissive';
      case 1:
      default:
        return 'Balanced';
    }
  }

  // ═══════════════════════════════════════════
  // ──  Custom 3-point Slider
  // ═══════════════════════════════════════════
  Widget _buildSlider({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    const labels = ['Strict', 'Balanced', 'Permissive'];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const dotSize = 10.0;
            const activeDotSize = 18.0;

            return SizedBox(
              height: activeDotSize,
              width: width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Track
                  Container(
                    height: 2,
                    width: width - activeDotSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  // Dots and Thumb
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (i) {
                      final isThumb = value == i;

                      return GestureDetector(
                        onTap: () => onChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: activeDotSize,
                          height: activeDotSize,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              width: isThumb ? activeDotSize : dotSize,
                              height: isThumb ? activeDotSize : dotSize,
                              decoration: BoxDecoration(
                                color: isThumb
                                    ? KovaColors.primary
                                    : const Color(0xFFD0D0D0),
                                shape: BoxShape.circle,
                                border: isThumb
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isThumb
                                    ? [
                                        BoxShadow(
                                          color: KovaColors.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final isSelected = value == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == 2 ? TextAlign.right : TextAlign.center),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? KovaColors.textPrimary
                        : KovaColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ──  Manual Block Button
  // ═══════════════════════════════════════════
  Widget _buildManualBlockItem(int appIndex, int itemValue, String label) {
    final app = _apps[appIndex];
    final isSelected = app.blocking == itemValue;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => app.blocking = itemValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? KovaColors.primary : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: KovaColors.primary.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: isSelected ? Colors.white : KovaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerButton(
    BuildContext context,
    dynamic icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Center(
          child: FaIcon(icon, color: KovaColors.textPrimary, size: 16),
        ),
      ),
    );
  }
}

/// Mutable app control data
class _AppControlData {
  final String name;
  final dynamic icon;
  final Color color;
  final int alerts;
  final int blocks;
  bool enabled;
  int sensitivity; // 0=Minimal, 1=Balanced, 2=Strict
  int blocking; // 0=Minimal, 1=Balanced, 2=Strict

  _AppControlData({
    required this.name,
    required this.icon,
    required this.color,
    required this.alerts,
    required this.blocks,
    required this.enabled,
    required this.sensitivity,
    required this.blocking,
  });
}
