import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kova/core/router.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';

class MonitoredAppsScreen extends StatefulWidget {
  const MonitoredAppsScreen({super.key});

  @override
  State<MonitoredAppsScreen> createState() => _MonitoredAppsScreenState();
}

class _MonitoredAppsScreenState extends State<MonitoredAppsScreen> {
  final _childRepo = ChildRepository();
  ChildModel? _child;
  bool _loading = true;

  final Map<String, _AppMeta> _appMeta = {
    'whatsapp': const _AppMeta('WhatsApp', 'com.whatsapp'),
    'tiktok': const _AppMeta('TikTok', 'com.zhiliaoapp.musically'),
    'facebook': const _AppMeta('Facebook', 'com.facebook.katana'),
    'instagram': const _AppMeta('Instagram', 'com.instagram.android'),
    'sms': const _AppMeta('SMS', 'com.google.android.apps.messaging'),
    'snapchat': const _AppMeta('Snapchat', 'com.snapchat.android'),
    'web_browsers': const _AppMeta('Web Browsers', 'com.android.chrome'),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final childId = await AppModeManager.getChildId();
    if (childId != null) {
      _child = await _childRepo.getById(childId);
    }
    setState(() => _loading = false);
  }

  List<MapEntry<String, _AppMeta>> get _enabledApps {
    if (_child == null) return [];
    return _appMeta.entries.where((entry) {
      final isEnabled = _child!.appControls[entry.key] ?? true;
      return isEnabled;
    }).toList();
  }

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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _enabledApps.isEmpty
                        ? const Center(child: Text('No apps configured for monitoring'))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _enabledApps.length,
                            itemBuilder: (context, index) {
                              final app = _enabledApps[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildAppCard(
                                  title: app.value.name,
                                  packageName: app.value.package,
                                  isConnected: app.key == 'whatsapp',
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.childDashboard),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2A5D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
    required String title,
    required String packageName,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4F0),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: _getAppIcon(title),
          ),
          const SizedBox(width: 16),
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
              ],
            ),
          ),
          if (isConnected)
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Automatic',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getAppIcon(String title) {
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
      case 'snapchat':
        return const Icon(Icons.chat, color: Color(0xFFFFFC00));
      case 'web browsers':
        return const Icon(Icons.language_outlined, color: Color(0xFF03A9F4));
      default:
        return const Icon(Icons.apps);
    }
  }
}

class _AppMeta {
  final String name;
  final String package;
  const _AppMeta(this.name, this.package);
}
