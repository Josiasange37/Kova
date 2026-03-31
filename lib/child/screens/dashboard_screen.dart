import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/core/router.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/local_backend/database/database_service.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _childRepository = ChildRepository();
  final _alertRepository = AlertRepository();

  ChildModel? _child;
  List<AlertModel> _recentAlerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final childId = await AppModeManager.getChildId();
    if (childId != null) {
      final child = await _childRepository.getById(childId);
      final alerts = await _alertRepository.getRecent(childId, 24);
      if (mounted) {
        setState(() {
          _child = child;
          _recentAlerts = alerts;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final childName = _child?.name ?? 'Child';
    final initial = childName.isNotEmpty ? childName[0].toUpperCase() : 'C';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E2A5D),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $childName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A5D),
                          ),
                        ),
                        const Text(
                          'Protected by your parents',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.battery_charging_full,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '85%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(
                      Icons.logout_outlined,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Status Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A5D),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E2A5D).withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All systems active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your device is connected and monitoring is active in the background.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.access_time,
                      label: 'Screen Time',
                      color: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.rule,
                      label: 'Rules',
                      color: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.chat_bubble_outline,
                      label: 'Ask Parent',
                      color: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Recent Activity
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E2A5D),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _recentAlerts.isEmpty 
                        ? const Center(
                            child: Text(
                              'No recent activity',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _recentAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = _recentAlerts[index];
                              return _buildActivityItem(
                                icon: _getIconForAlert(alert.type),
                                title: alert.app,
                                time: _formatTime(alert.createdAt),
                                status: alert.type,
                                statusColor: alert.isCritical ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForAlert(String type) {
    if (type.contains('blocked')) return Icons.block;
    if (type.contains('time')) return Icons.timer_outlined;
    if (type.contains('app')) return Icons.apps;
    return Icons.chat_bubble_outline;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 60) {
      if (difference.inMinutes <= 1) return 'Just now';
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM d, yyyy').format(time);
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFEF4444),
          ),
        ),
        content: const Text(
          'This will clear all your data and return to the login screen.\n\n'
          'Your parent will need to set up the connection again.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear database
        final db = DatabaseService();
        await db.reset();
        
        // Clear all local storage
        await LocalStorage.clear();
        
        if (mounted) {
          // Navigate to splash screen
          context.go(AppRoutes.splash);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required String status,
    required Color statusColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
