import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/parent/services/app_control_service.dart';
import 'package:kova/shared/services/local_storage.dart';

class AppControlScreen extends StatefulWidget {
  final bool isEmbedded;

  const AppControlScreen({super.key, this.isEmbedded = false});

  @override
  State<AppControlScreen> createState() => _AppControlScreenState();
}

class _AppControlScreenState extends State<AppControlScreen> {
  // Local mutable state for sensitivity and blocking (persisted via LocalStorage)
  final Map<String, int> _sensitivity = {};
  final Map<String, int> _blocking = {};

  // Static app metadata (icons & colors)
  static final _appMeta = <String, _AppMeta>{
    'x': const _AppMeta(
      name: 'X',
      icon: Icons.close_rounded,
      color: Color(0xFF000000),
    ),
    'tiktok': const _AppMeta(
      name: 'TikTok',
      icon: Icons.music_note_rounded,
      color: Color(0xFF010101),
    ),
    'instagram': const _AppMeta(
      name: 'Instagram',
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFE4405F),
    ),
    'whatsapp': const _AppMeta(
      name: 'WhatsApp',
      icon: Icons.chat_rounded,
      color: Color(0xFF25D366),
    ),
    'facebook': const _AppMeta(
      name: 'Facebook',
      icon: Icons.facebook_rounded,
      color: Color(0xFF1877F2),
    ),
    'sms': const _AppMeta(
      name: 'SMS',
      icon: Icons.sms_rounded,
      color: Color(0xFF34C759),
    ),
  };

  @override
  void initState() {
    super.initState();
    // Load persisted sensitivity/blocking values from SharedPreferences
    for (final key in _appMeta.keys) {
      _sensitivity[key] =
          LocalStorage.getInt('app_sensitivity_$key', 1);
      _blocking[key] =
          LocalStorage.getInt('app_blocking_$key', 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppControlService>().loadAppControls();
    });
  }

  void _saveSensitivity(String appKey, int value) {
    setState(() => _sensitivity[appKey] = value);
    LocalStorage.setInt('app_sensitivity_$appKey', value);
  }

  void _saveBlocking(String appKey, int value) {
    setState(() => _blocking[appKey] = value);
    LocalStorage.setInt('app_blocking_$appKey', value);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppControlService>();

    // Ordered keys for display
    final orderedKeys = ['x', 'tiktok', 'instagram', 'whatsapp', 'facebook', 'sms'];

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
                  Icons.arrow_back,
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

          if (service.loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            const SizedBox(height: 22),

            // ── App cards ──
            ...orderedKeys.map((key) {
              final meta = _appMeta[key]!;
              final data = service.appData[key];
              final alerts = data?.alerts ?? 0;
              final blocks = data?.blocks ?? 0;
              final enabled = data?.enabled ?? true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAppCard(
                  appKey: key,
                  name: meta.name,
                  icon: meta.icon,
                  color: meta.color,
                  alerts: alerts,
                  blocks: blocks,
                  enabled: enabled,
                  sensitivity: _sensitivity[key] ?? 1,
                  blocking: _blocking[key] ?? 0,
                  onToggle: (v) {
                    // Toggle for first child (or all children if only one)
                    final children = service.children;
                    if (children.isNotEmpty) {
                      service.toggleAppControl(children.first.id, key, v);
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  App Card
  // ═══════════════════════════════════════════
  Widget _buildAppCard({
    required String appKey,
    required String name,
    required IconData icon,
    required Color color,
    required int alerts,
    required int blocks,
    required bool enabled,
    required int sensitivity,
    required int blocking,
    required ValueChanged<bool> onToggle,
  }) {
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(width: 14),

              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: KovaColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$alerts alerts • $blocks blocks',
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
                  value: enabled,
                  onChanged: onToggle,
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
                _getSensitivityLabel(sensitivity),
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
            value: sensitivity,
            onChanged: (v) => _saveSensitivity(appKey, v),
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
              _buildManualBlockItem(appKey, blocking, 0, '30 min'),
              const SizedBox(width: 8),
              _buildManualBlockItem(appKey, blocking, 1, '1h'),
              const SizedBox(width: 8),
              _buildManualBlockItem(appKey, blocking, 2, '2h'),
              const SizedBox(width: 8),
              _buildManualBlockItem(appKey, blocking, 3, '∞'),
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
  Widget _buildManualBlockItem(
    String appKey,
    int currentBlocking,
    int itemValue,
    String label,
  ) {
    final isSelected = currentBlocking == itemValue;

    return Expanded(
      child: GestureDetector(
        onTap: () => _saveBlocking(appKey, itemValue),
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
          child: Icon(icon, color: KovaColors.textPrimary, size: 16),
        ),
      ),
    );
  }
}

/// Static app metadata
class _AppMeta {
  final String name;
  final IconData icon;
  final Color color;

  const _AppMeta({
    required this.name,
    required this.icon,
    required this.color,
  });
}
