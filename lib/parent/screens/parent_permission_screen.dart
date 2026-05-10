import 'package:flutter/material.dart';
import 'package:kova/parent/services/parent_permission_service.dart';

/// Shown once on first launch of the parent app.
/// Each permission has its own "Grant" button and live status indicator.
/// The screen auto-refreshes status when the user returns from system settings.
class ParentPermissionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ParentPermissionScreen({super.key, required this.onComplete});

  @override
  State<ParentPermissionScreen> createState() => _ParentPermissionScreenState();
}

class _ParentPermissionScreenState extends State<ParentPermissionScreen>
    with WidgetsBindingObserver {

  // Permission status map — drives the UI
  Map<String, bool> _status = {
    'notifications': false,
    'nearbyWifi': false,
    'battery': false,
    'exactAlarm': false,
  };

  bool _loading = false;
  bool _checkingIndividual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check all statuses when app resumes (user returned from settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final s = await ParentPermissionService.getStatus();
    if (!mounted) return;
    setState(() => _status = s);

    // Auto-advance if all required permissions are already granted
    if ((_status['notifications'] ?? false) && (_status['nearbyWifi'] ?? false)) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) widget.onComplete();
    }
  }

  Future<void> _grantAll() async {
    setState(() => _loading = true);
    await ParentPermissionService.checkAndRequestAll(context);
    await _refresh();
    setState(() => _loading = false);
  }

  Future<void> _grantIndividual(String key) async {
    setState(() => _checkingIndividual = true);
    switch (key) {
      case 'notifications':
        await ParentPermissionService.requestNotifications();
      case 'nearbyWifi':
        await ParentPermissionService.requestNearbyWifi();
      case 'battery':
        await ParentPermissionService.requestBatteryOptimization();
      case 'exactAlarm':
        await ParentPermissionService.requestExactAlarm();
    }
    await _refresh();
    setState(() => _checkingIndividual = false);
  }

  bool get _allRequiredGranted =>
      (_status['notifications'] ?? false) && (_status['nearbyWifi'] ?? false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🛡️', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Set Up KOVA Parent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant these permissions so KOVA can alert you\nin real time when your child needs help.',
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Required badge count
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _allRequiredGranted
                    ? _buildAllGrantedBadge()
                    : _buildPendingBadge(),
              ),

              const SizedBox(height: 28),

              // ── Permission Cards ────────────────────────────────────────
              _PermissionItem(
                icon: '🔔',
                title: 'Notifications',
                description: 'Receive instant alerts when a threat is detected.',
                required: true,
                granted: _status['notifications'] ?? false,
                onGrant: _checkingIndividual ? null : () => _grantIndividual('notifications'),
              ),
              const SizedBox(height: 12),
              _PermissionItem(
                icon: '📡',
                title: 'Nearby Wi-Fi Devices',
                description:
                    'Discover the child device on your local network (LAN). '
                    'Without this, KOVA falls back to a slower internet relay.',
                required: true,
                granted: _status['nearbyWifi'] ?? false,
                onGrant: _checkingIndividual ? null : () => _grantIndividual('nearbyWifi'),
              ),
              const SizedBox(height: 12),
              _PermissionItem(
                icon: '🔋',
                title: 'Battery — No Restrictions',
                description:
                    'Keep receiving alerts even when your screen is off. '
                    'Critical on Xiaomi/MIUI and Samsung.',
                required: false,
                granted: _status['battery'] ?? false,
                onGrant: _checkingIndividual ? null : () => _grantIndividual('battery'),
              ),
              const SizedBox(height: 12),
              _PermissionItem(
                icon: '⏰',
                title: 'Exact Alarms',
                description: 'Used for reliable background watchdog scheduling.',
                required: false,
                granted: _status['exactAlarm'] ?? false,
                onGrant: _checkingIndividual ? null : () => _grantIndividual('exactAlarm'),
              ),

              const SizedBox(height: 32),

              // ── Grant All Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _grantAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    disabledBackgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Grant All Permissions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Continue button — only shown when required permissions granted
              if (_allRequiredGranted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: widget.onComplete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue →',
                      style: TextStyle(color: Color(0xFF4F46E5), fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Skip for now (not recommended)',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
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

  Widget _buildAllGrantedBadge() {
    return Container(
      key: const ValueKey('all_granted'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 6),
          Text(
            'All required permissions granted',
            style: TextStyle(color: Colors.green, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBadge() {
    final pending = [
      if (!(_status['notifications'] ?? false)) 'Notifications',
      if (!(_status['nearbyWifi'] ?? false)) 'Nearby Wi-Fi',
    ].join(', ');
    return Container(
      key: const ValueKey('pending'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 6),
          Text(
            'Required: $pending',
            style: const TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Individual permission row widget
// ────────────────────────────────────────────────────────────────────────────

class _PermissionItem extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final bool required;
  final bool granted;
  final VoidCallback? onGrant;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.required,
    required this.granted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = granted
        ? Colors.green.withValues(alpha: 0.4)
        : required
            ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
            : Colors.white12;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: granted
                  ? Colors.green.withValues(alpha: 0.1)
                  : const Color(0xFF1E1E3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),

          // Text content
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                              color: Color(0xFF818CF8), fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status / Grant button
          if (granted)
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 26)
          else
            GestureDetector(
              onTap: onGrant,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: onGrant != null
                      ? const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        )
                      : null,
                  color: onGrant == null ? Colors.white12 : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Grant',
                  style: TextStyle(
                    color: onGrant != null ? Colors.white : Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
