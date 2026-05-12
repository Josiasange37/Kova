import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/child/services/detection_orchestrator.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/services/network_sync_service.dart';
import 'package:kova/shared/models/network_alert.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _childRepository = ChildRepository();
  final _alertRepository = AlertRepository();
  final _networkSync = NetworkSyncService();

  ChildModel? _child;
  List<AlertModel> _recentAlerts = [];
  bool _isLoading = true;
  StreamSubscription<AlertModel>? _alertSub;
  StreamSubscription<NetworkAlertSummary>? _networkAlertSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen for local alerts from detection orchestrator
    _alertSub = DetectionOrchestrator.instance.onNewAlert.listen((alert) {
      if (mounted) {
        setState(() {
          _recentAlerts.insert(0, alert);
        });
      }
    });
    
    // Listen for parent-initiated block/unblock commands
    _networkAlertSub = _networkSync.onAlertReceived.listen((alert) {
      if (alert.alertType == 'parent_block') {
        debugPrint('🚫 [CHILD] Received parent block command for ${alert.app}');
        DetectionOrchestrator.instance.safeBlockApp(alert.app);
      } else if (alert.alertType == 'parent_unblock') {
        debugPrint('🔓 [CHILD] Received parent unblock command for ${alert.app}');
        DetectionOrchestrator.instance.unblockApp(alert.app);
      }
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _networkAlertSub?.cancel();
    super.dispose();
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
        backgroundColor: Color(0xFFF6F6F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final childName = _child?.name ?? 'Alex';
    final score = _child?.score ?? 92;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Hello $childName 👋',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C2C54),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's how you're doing",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF888899),
                ),
              ),
              const SizedBox(height: 40),

              // Score Ring
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: SegmentedRingPainter(
                          score: score,
                          activeColor: const Color(0xFF7E3FF2),
                          inactiveColor: const Color(0xFFE8E8EE),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$score',
                                style: GoogleFonts.inter(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7E3FF2),
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                '/100',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF888899),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _getScoreText(score),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7E3FF2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // "This week" Chart
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C2C54),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildChartBar('Mon', 100, const Color(0xFF1CB476)),
                        _buildChartBar('Tue', 100, const Color(0xFF1CB476)),
                        _buildChartBar('Wed', 100, const Color(0xFF1CB476)),
                        _buildChartBar('Thu', 100, const Color(0xFFF59E0B)),
                        _buildChartBar('Fri', 100, const Color(0xFF1CB476)),
                        _buildChartBar('Sat', 10, const Color(0xFF5B7FFF)),
                        _buildChartBar('Sun', 10, const Color(0xFFD1D5DB)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // "Your badges"
              Text(
                'Your badges',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C2C54),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBadge(
                      '5-Day Streak',
                      Icons.star_border,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBadge(
                      'Top Scorer',
                      Icons.emoji_events_outlined,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBadge(
                      'Kind Words',
                      Icons.favorite_border,
                      const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // "Keep going to unlock"
              Text(
                'Keep going to unlock',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C2C54),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLockedBadge(
                      'Week\nChampion',
                      Icons.workspace_premium_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLockedBadge(
                      'Perfect\nWeek',
                      Icons.bolt_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLockedBadge(
                      '100 Club',
                      Icons.adjust,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Bottom Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFF59E0B)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Keep it up and earn your\nweekly badge! 🌟',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getScoreText(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Great';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Needs Work';
    return 'Warning';
  }

  Widget _buildChartBar(String day, double heightPct, Color color) {
    final double maxHeight = 100.0;
    final double actualHeight = (heightPct / 100.0) * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: actualHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF888899),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String title, IconData icon, Color bgColor) {
    return AspectRatio(
      aspectRatio: 0.9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBadge(String title, IconData icon) {
    return AspectRatio(
      aspectRatio: 0.9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 8,
              child: const Icon(
                Icons.lock_outline,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFF94A3B8), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SegmentedRingPainter extends CustomPainter {
  final int score;
  final Color activeColor;
  final Color inactiveColor;

  SegmentedRingPainter({
    required this.score,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw full background ring
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // We draw 4 segments. Total active is determined by score.
    // For 92, almost all segments are active. We'll draw 4 arcs with gaps.
    final int totalSegments = 4;
    final double gapAngle = 0.3; // radians
    final double sweepAngle = (2 * 3.141592653589793 - (gapAngle * totalSegments)) / totalSegments;
    
    int segmentsToFill = (score / 25).ceil();
    if (segmentsToFill > totalSegments) segmentsToFill = totalSegments;

    // Start angle slightly rotated so gaps align nicely (e.g. top gap, bottom gap, sides)
    double startAngle = -3.141592653589793 / 2 + (gapAngle / 2);

    for (int i = 0; i < totalSegments; i++) {
      if (i < segmentsToFill) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          fgPaint,
        );
      }
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
