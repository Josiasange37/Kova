import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kova/providers/app_state.dart';
import 'package:kova/models/alert.dart';
import 'package:kova/core/constants.dart';

class AlertHistoryScreen extends StatefulWidget {
  final bool isEmbedded;

  const AlertHistoryScreen({super.key, this.isEmbedded = false});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen>
    with SingleTickerProviderStateMixin {
  // ── Filters ──
  int _selectedAppFilter = 0; // 0=All, 1=WhatsApp, 2=TikTok, 3=Facebook
  int _selectedTimeFilter = 0; // 0=This week, 1=This month, 2=All

  static const _timeFilters = ['This week', 'This month', 'All'];


  late AnimationController _entranceCtrl;
  late Animation<double> _headerFade;
  late Animation<double> _filterFade;
  late Animation<double> _statsFade;
  late Animation<double> _listFade;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _filterFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _statsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _listFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Helper methods ──

  List<Alert> _getFilteredAlerts(List<Alert> allAlerts, List<String> apps) {
    var filtered = allAlerts;

    // Filter by App
    if (_selectedAppFilter > 0 && _selectedAppFilter < apps.length) {
      final selectedAppName = apps[_selectedAppFilter];
      filtered = filtered.where((a) => a.appName == selectedAppName).toList();
    }

    // Filter by Time
    final now = DateTime.now();
    if (_selectedTimeFilter == 0) {
      // Today
      filtered = filtered.where((a) => 
        a.createdAt.year == now.year && 
        a.createdAt.month == now.month && 
        a.createdAt.day == now.day).toList();
    } else if (_selectedTimeFilter == 1) {
      // Yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      filtered = filtered.where((a) => 
        a.createdAt.year == yesterday.year && 
        a.createdAt.month == yesterday.month && 
        a.createdAt.day == yesterday.day).toList();
    } else if (_selectedTimeFilter == 2) {
      // Last 7 days
      final weekAgo = now.subtract(const Duration(days: 7));
      filtered = filtered.where((a) => a.createdAt.isAfter(weekAgo)).toList();
    }

    return filtered;
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFB8C00);
      default:
        return const Color(0xFF4AC38B);
    }
  }

  IconData _getAppIcon(String appName) {
    switch (appName.toLowerCase()) {
      case 'whatsapp':
        return Icons.message_rounded;
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'snapchat':
        return Icons.snapchat_rounded;
      case 'youtube':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // Derive app filters from alert history
    final uniqueApps = appState.alerts.map((a) => a.appName).toSet().toList();
    uniqueApps.sort();
    final apps = ['All', ...uniqueApps];

    final filteredAlerts = _getFilteredAlerts(appState.alerts, apps);

    // Calculate stats
    final totalAlerts = filteredAlerts.length;
    final blocksCount = filteredAlerts.where((a) => a.isResolved && (a.resolvedAction?.contains('Block') ?? false)).length;
    final avgScore = totalAlerts == 0 ? 0 
        : (filteredAlerts.map((a) => a.aiConfidence).reduce((a, b) => a + b) / totalAlerts * 100).round();

    final content = AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(top: widget.isEmbedded ? 0 : 24, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title (only if not embedded) ──
              if (!widget.isEmbedded)
                Opacity(
                  opacity: _headerFade.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Alert history',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: KovaColors.primary,
                      ),
                    ),
                  ),
                ),
              if (!widget.isEmbedded) const SizedBox(height: 20),

              // ── App filter chips ──
              Opacity(
                opacity: _filterFade.value, 
                child: _buildAppFilters(apps),
              ),
              const SizedBox(height: 16),

              // ── Time filter chips ──
              Opacity(opacity: _filterFade.value, child: _buildTimeFilters()),
              const SizedBox(height: 24),

              // ── Stats row ──
              Opacity(
                opacity: _statsFade.value, 
                child: _buildStatsRow(totalAlerts.toString(), blocksCount.toString(), '$avgScore%'),
              ),
              const SizedBox(height: 24),

              // ── Alert list ──
              Opacity(
                opacity: _listFade.value,
                child: filteredAlerts.isEmpty 
                  ? _buildEmptyState()
                  : Column(
                      children: filteredAlerts.map((a) => _buildAlertCard(a)).toList(),
                    ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(child: content),
    );
  }

  // ═══════════════════════════════════════════
  // ──  App Filter Chips
  // ═══════════════════════════════════════════
  Widget _buildAppFilters(List<String> apps) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(apps.length, (i) {
          final isActive = _selectedAppFilter == i;
          return Padding(
            padding: EdgeInsets.only(
              right: i < apps.length - 1 ? 12 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedAppFilter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive ? KovaColors.primary : KovaColors.cardWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isActive
                        ? KovaColors.primary
                        : const Color(0xFFE8EAF1),
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: KovaColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  apps[i],
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? KovaColors.textOnDark
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Time Filter Chips
  // ═══════════════════════════════════════════
  Widget _buildTimeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_timeFilters.length, (i) {
          final isActive = _selectedTimeFilter == i;
          return Padding(
            padding: EdgeInsets.only(
              right: i < _timeFilters.length - 1 ? 12 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTimeFilter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: KovaColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF5A72A0)
                        : const Color(0xFFE8EAF1),
                  ),
                ),
                child: Text(
                  _timeFilters[i],
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF5A72A0)
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Stats Row
  // ═══════════════════════════════════════════
  Widget _buildStatsRow(String total, String blocks, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: KovaColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
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
            _buildStatItem(total, 'Total alerts'),
            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
            _buildStatItem(blocks, 'Blocks'),
            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
            _buildStatItem(score, 'Avg AI score'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: KovaColors.primary, // Dark blue text
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93), // light grey text
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Alert Card
  // ═══════════════════════════════════════════
  Widget _buildAlertCard(Alert alert) {
    final borderColor = _getSeverityColor(alert.severity);
    final scoreText = '${(alert.aiConfidence * 100).round()}%';
    final timeAgo = _getTimeAgo(alert.createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(KovaRoutes.alertDetail, arguments: alert);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: KovaColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getAppIcon(alert.appName),
                  color: const Color(0xFF1F2937),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        alert.appName,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E2A4F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scoreText,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.alertType,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  if (alert.isResolved) ...[
                    const SizedBox(height: 4),
                    Text(
                      alert.resolvedAction ?? 'Resolved',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B5B96), // Dark blue action text
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Time text (top right)
            Text(
              timeAgo,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF), // Light grey
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No alerts found',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


