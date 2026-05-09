import 'package:flutter/material.dart';
import 'package:kova/parent/services/parent_permission_service.dart';
import 'package:kova/shared/services/local_storage.dart';

/// Shown once on first launch of parent app.
/// Walks parent through granting all required permissions.
class ParentPermissionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ParentPermissionScreen({super.key, required this.onComplete});

  @override
  State<ParentPermissionScreen> createState() => _ParentPermissionScreenState();
}

class _ParentPermissionScreenState extends State<ParentPermissionScreen> {
  bool _notifGranted = false;
  bool _batteryGranted = false;
  bool _loading = false;

  final _permissions = [
    {
      'icon': '🔔',
      'title': 'Notifications',
      'desc': 'Recevoir les alertes instantanément',
      'required': true,
    },
    {
      'icon': '🔋',
      'title': 'Batterie sans restriction',
      'desc': 'Continuer à recevoir des alertes écran éteint',
      'required': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final notif = await ParentPermissionService.hasNotificationPermission();
    setState(() {
      _notifGranted = notif;
    });
  }

  Future<void> _requestAll() async {
    setState(() => _loading = true);
    await ParentPermissionService.checkAndRequestAll(context);
    final notif = await ParentPermissionService.hasNotificationPermission();
    setState(() {
      _notifGranted = notif;
      _batteryGranted = true;
      _loading = false;
    });
    if (_notifGranted) {
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text('🛡️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Configurer KOVA Parent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Accordez ces permissions pour recevoir\nles alertes de votre enfant en temps réel.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Permission cards
              _PermissionCard(
                icon: '🔔',
                title: 'Notifications',
                desc: 'Recevoir les alertes instantanément',
                granted: _notifGranted,
                required: true,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: '🔋',
                title: 'Batterie sans restriction',
                desc: 'Alertes même écran éteint (important sur MIUI)',
                granted: _batteryGranted,
                required: false,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Accorder les permissions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_notifGranted) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Continuer →',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  final bool granted;
  final bool required;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.granted,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? Colors.green.withOpacity(0.5)
              : required
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (required) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Requis',
                          style: TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            granted ? Icons.check_circle : Icons.circle_outlined,
            color: granted ? Colors.green : Colors.white30,
            size: 22,
          ),
        ],
      ),
    );
  }
}
