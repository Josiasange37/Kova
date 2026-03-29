import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kova/core/router.dart';

class MonitoredAppsScreen extends StatelessWidget {
  const MonitoredAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monitored apps',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2A5D),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'These apps are now being monitored for your child\'s safety',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildAppCard(
                      iconPath: 'assets/images/whatsapp_icon.svg',
                      title: 'WhatsApp',
                      subtitle: '',
                      status: AppStatus.connected,
                    ),
                    const SizedBox(height: 12),
                    _buildAppCard(
                      iconPath: 'assets/images/tiktok_icon.svg',
                      title: 'TikTok',
                      subtitle: 'No action needed',
                      status: AppStatus.automatic,
                    ),
                    const SizedBox(height: 12),
                    _buildAppCard(
                      iconPath: 'assets/images/facebook_icon.svg',
                      title: 'Facebook',
                      subtitle: 'No action needed',
                      status: AppStatus.automatic,
                    ),
                    const SizedBox(height: 12),
                    _buildAppCard(
                      iconPath: 'assets/images/instagram_icon.svg',
                      title: 'Instagram',
                      subtitle: 'No action needed',
                      status: AppStatus.automatic,
                    ),
                    const SizedBox(height: 12),
                    _buildAppCard(
                      iconPath: 'assets/images/sms_icon.svg',
                      title: 'SMS',
                      subtitle: 'No action needed',
                      status: AppStatus.automatic,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to parent connection screen
                    context.go(AppRoutes.childParentConnection);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2A5D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildAppCard({
    required String iconPath,
    required String title,
    required String subtitle,
    required AppStatus status,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // App Icon Placeholder / Image
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4F0),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: _getIconReplacement(title, iconPath),
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Status Badge
          if (status == AppStatus.connected)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else if (status == AppStatus.automatic)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5), // Indigo blue
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Automatic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getIconReplacement(String title, String asset) {
    // If the SVG is not available yet, provide a fallback built-in icon
    switch (title.toLowerCase()) {
      case 'whatsapp':
        return const Icon(Icons.chat_bubble_outline, color: Color(0xFF10B981));
      case 'tiktok':
        return const Icon(Icons.music_note, color: Colors.black);
      case 'facebook':
        return const Icon(Icons.facebook, color: Color(0xFF1877F2));
      case 'instagram':
        return const Icon(Icons.camera_alt_outlined, color: Color(0xFFE1306C));
      case 'sms':
        return const Icon(Icons.message_outlined, color: Color(0xFF4B5563));
      default:
        return const Icon(Icons.apps);
    }
  }
}

enum AppStatus { connected, automatic }
