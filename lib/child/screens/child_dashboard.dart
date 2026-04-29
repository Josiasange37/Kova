import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/kova_theme.dart';
import 'block_screen.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/services/network_sync_service.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  bool _isLoading = true;
  String? _error;

  ChildModel? _child;
  List<AlertModel> _recentAlerts = [];
  Timer? _profileRetryTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startProfileRetryTimer();
  }

  @override
  void dispose() {
    _profileRetryTimer?.cancel();
    super.dispose();
  }

  /// Retry fetching profile every 10 seconds if not loaded (DIRECTIVE 4)
  void _startProfileRetryTimer() {
    _profileRetryTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_child == null && mounted) {
        print('⏳ Retrying child profile sync...');
        final synced = await NetworkSyncService.instance.syncChildProfile();
        if (synced) {
          print('✅ Child profile synced on retry');
          await _loadData();
        }
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final childId = await AppModeManager.getChildId();
      if (childId == null) {
        setState(() {
          _error = 'No child profile linked.';
          _isLoading = false;
        });
        return;
      }

      final childRepo = ChildRepository();
      final alertRepo = AlertRepository();

      // Try to get my own profile (DIRECTIVE 4)
      final child = await childRepo.getById(childId);
      final alerts = await alertRepo.getRecent(childId, 24);

      setState(() {
        _child = child;
        _recentAlerts = alerts;
        _isLoading = false;
      });

      // If profile is still null, show waiting state but keep retry timer running
      if (child == null) {
        print('⏳ Child profile not available yet - waiting for parent setup...');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E2A5D)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Color(0xFF1E2A5D)),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF1E2A5D)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _isLoading = true; _error = null; });
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2A5D)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Waiting for parent setup state (DIRECTIVE 4)
    if (_child == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A5D).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 64,
                    color: Color(0xFF1E2A5D),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Waiting for parent setup...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E2A5D),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your parent needs to finish setting up your profile. Retrying automatically...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E2A5D).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF1E2A5D),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final child = _child;
    final score = child?.score ?? 0;
    final childName = child?.name ?? 'there';
    final scoreLabel = score >= 80 ? 'Great' : score >= 60 ? 'Fair' : 'Needs Attention';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: RefreshIndicator(
        color: const Color(0xFF1E2A5D),
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Top gradient background
                  Container(
                    height: 280,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3358CB), Color(0xFF1E2A5D)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "KOVA Safety",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Hi $childName 👋",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Score Card — real score from DB
                          _buildScoreCard(score, scoreLabel),

                          const SizedBox(height: 32),

                          // Blocked Attempts Section — real alerts from DB
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader("Recent alerts"),
                              Text(
                                "${_recentAlerts.length} in last 24h",
                                style: GoogleFonts.inter(
                                  color: _recentAlerts.isEmpty
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE53935),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildAlertsList(),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BlockScreen()),
          );
        },
        backgroundColor: KovaTheme.primaryBlue,
        child: const Icon(Icons.shield_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildScoreCard(int score, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 16,
                  backgroundColor: Colors.grey.shade100,
                  color: _scoreColor(score),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A5D).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF1E2A5D),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "$score",
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E2A5D),
                        ),
                      ),
                      Text(
                        "%",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E2A5D),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KovaTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            score >= 80
                ? "Great job! Keep up the safe habits."
                : score >= 60
                    ? "Not bad! A little more care goes a long way."
                    : "Let's work together to improve your score.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E2A5D),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E2A5D),
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_recentAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "No alerts in the last 24 hours. Great work!",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E2A5D),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentAlerts.take(5).map((alert) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAlertItem(alert),
        );
      }).toList(),
    );
  }

  Widget _buildAlertItem(AlertModel alert) {
    final icon = _iconForApp(alert.app);
    final iconColor = _colorForSeverity(alert.severity);
    final iconBg = iconColor.withValues(alpha: 0.12);
    final timeAgo = _timeAgo(alert.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.app,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E2A5D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelForType(alert.type),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: KovaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgo,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: KovaTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.severityLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForApp(String app) {
    return switch (app.toLowerCase()) {
      'whatsapp' => Icons.chat_bubble_outline,
      'tiktok' => Icons.music_note_outlined,
      'facebook' => Icons.facebook,
      'instagram' => Icons.camera_alt_outlined,
      'sms' => Icons.sms_outlined,
      _ => Icons.language_outlined,
    };
  }

  Color _colorForSeverity(String severity) {
    return switch (severity) {
      'critical' => const Color(0xFFE53935),
      'high'     => const Color(0xFFFF5722),
      'medium'   => const Color(0xFFFF9800),
      'low'      => const Color(0xFF4CAF50),
      _          => const Color(0xFF1E2A5D),
    };
  }

  String _labelForType(String type) {
    return switch (type) {
      'grooming'         => 'Grooming detected',
      'harmful_content'  => 'Harmful content',
      'blocked_app'      => 'Blocked app',
      'screen_time'      => 'Screen time limit',
      _                  => type.replaceAll('_', ' '),
    };
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
