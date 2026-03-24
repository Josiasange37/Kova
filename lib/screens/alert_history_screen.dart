import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const _appFilters = ['All', 'WhatsApp', 'TikTok', 'Facebook'];
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

  // ── Demo data ──
  List<_AlertItem> get _alerts => [
    const _AlertItem(
      app: 'TikTok',
      icon: Icons.music_note_rounded,
      borderColor: Color(0xFFFA6262), // Red border
      score: '87%',
      title: 'Suspicious content',
      action: 'Blocked 20 min',
      time: '2 hours ago',
    ),
    const _AlertItem(
      app: 'WhatsApp',
      icon: Icons.chat_bubble_outline_rounded,
      borderColor: Color(0xFFF5A623), // Orange/yellow border
      score: '72%',
      title: 'Inappropriate text',
      action: 'Notification sent',
      time: '5 hours ago',
    ),
    const _AlertItem(
      app: 'Facebook',
      icon: Icons.facebook_rounded,
      borderColor: Color(0xFFF5A623), // Orange border
      score: '65%',
      title: 'Suspicious link',
      action: 'Blocked',
      time: 'Yesterday',
    ),
    const _AlertItem(
      app: 'TikTok',
      icon: Icons.music_note_rounded,
      borderColor: Color(0xFF4AC38B), // Green border
      score: '12%',
      title: 'Normal scan',
      action: 'No action',
      time: '2 days ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
              Opacity(opacity: _filterFade.value, child: _buildAppFilters()),
              const SizedBox(height: 16),

              // ── Time filter chips ──
              Opacity(opacity: _filterFade.value, child: _buildTimeFilters()),
              const SizedBox(height: 24),

              // ── Stats row ──
              Opacity(opacity: _statsFade.value, child: _buildStatsRow()),
              const SizedBox(height: 24),

              // ── Alert list ──
              Opacity(
                opacity: _listFade.value,
                child: Column(
                  children: _alerts.map((a) => _buildAlertCard(a)).toList(),
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
  Widget _buildAppFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_appFilters.length, (i) {
          final isActive = _selectedAppFilter == i;
          return Padding(
            padding: EdgeInsets.only(
              right: i < _appFilters.length - 1 ? 12 : 0,
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
                  _appFilters[i],
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
  Widget _buildStatsRow() {
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
            _buildStatItem('12', 'Total alerts'),
            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
            _buildStatItem('5', 'Blocks'),
            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
            _buildStatItem('68%', 'Avg AI score'),
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
  Widget _buildAlertCard(_AlertItem alert) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(KovaRoutes.alertDetail);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: KovaColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: alert.borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: alert.borderColor.withValues(alpha: 0.06),
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
                  alert.icon,
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
                        alert.app,
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
                          alert.score,
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
                    alert.title,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  if (alert.action.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alert.action,
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
              alert.time,
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
}

class _AlertItem {
  final String app;
  final IconData icon;
  final Color borderColor;
  final String score;
  final String title;
  final String action;
  final String time;

  const _AlertItem({
    required this.app,
    required this.icon,
    required this.borderColor,
    required this.score,
    required this.title,
    required this.action,
    required this.time,
  });
}
