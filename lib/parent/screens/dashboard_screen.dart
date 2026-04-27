// dashboard_screen.dart — Parent Monitoring Dashboard
// Reads from DashboardDataService. Two states: Protected (green) and Action required (red).
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/parent/services/dashboard_data_service.dart';
// import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/parent/screens/app_control_screen.dart';
import 'package:kova/parent/screens/alert_history_screen.dart';
import 'package:kova/parent/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0;

  late AnimationController _entranceCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _appsFade;
  late Animation<Offset> _appsSlide;
  late Animation<double> _activityFade;
  late Animation<Offset> _activitySlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _entranceCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load dashboard data when screen is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardDataService>().loadDashboardData();
    });
  }

  void _initAnimations() {
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = _fade(0.0, 0.25);
    _headerSlide = _slide(0.0, 0.25);
    _cardFade = _fade(0.1, 0.45);
    _cardSlide = _slide(0.1, 0.45);
    _appsFade = _fade(0.3, 0.65);
    _appsSlide = _slide(0.3, 0.65);
    _activityFade = _fade(0.5, 0.85);
    _activitySlide = _slide(0.5, 0.85);
  }

  Animation<double> _fade(double begin, double end) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut),
        ),
      );

  Animation<Offset> _slide(double begin, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, _) {
            return IndexedStack(
              index: _selectedNavIndex,
              children: [
                _buildDashboardTab(),
                // Alerts tab
                const AlertHistoryScreen(isEmbedded: true),
                // Control tab
                const AppControlScreen(isEmbedded: true),
                // Settings tab
                const SettingsScreen(isEmbedded: true),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Dashboard Tab
  // ═══════════════════════════════════════════
  Widget _buildDashboardTab() {
    return Consumer<DashboardDataService>(
      builder: (context, service, _) {
        final children = service.children ?? [];
        final activeChild = service.activeChild;
        final hasAlerts = service.hasAlerts;
        final safetyScore = service.safetyScore;
        final alertCount = service.alertCount;
        final parentName = (service.parentName?.isNotEmpty ?? false)
            ? service.parentName!
            : 'Parent';

        // Determine time-based greeting
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KovaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header: greeting + logo + child selector ──
              SlideTransition(
                position: _headerSlide,
                child: Opacity(
                  opacity: _headerFade.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, $parentName',
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: KovaColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                hasAlerts
                                    ? 'Action required'
                                    : 'Everything looks good today',
                                key: ValueKey(hasAlerts),
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: hasAlerts
                                      ? KovaColors.danger
                                      : KovaColors.textSecondary,
                                ),
                              ),
                            ),
                            // Child selector dropdown
                            if (children.length > 1) ...[
                              const SizedBox(height: 8),
                              _buildChildSelector(
                                  children, activeChild, service),
                            ],
                          ],
                        ),
                      ),
                      // Kova logo icon
                      SvgPicture.asset(KovaAssets.logoSvg, height: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Child cards for all children ──
              if (children.isEmpty)
                _buildNoChildCard()
              else if (children.length == 1)
                SlideTransition(
                  position: _cardSlide,
                  child: Opacity(
                    opacity: _cardFade.value,
                    child: _buildChildCard(
                      child: activeChild!,
                      hasAlerts: hasAlerts,
                      safetyScore: safetyScore,
                      alertCount: alertCount,
                    ),
                  ),
                )
              else
                // Show summary cards for all children
                ...children.map((child) {
                  // Calculate per-child stats
                  final childAlerts = service.alerts
                          ?.where((a) => a.childId == child.id)
                          .toList() ??
                      [];
                  final childAlertCount =
                      childAlerts.where((a) => !a.read).length;
                  final childHasAlerts = childAlertCount > 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Opacity(
                        opacity: _cardFade.value,
                        child: _buildChildCard(
                          child: child,
                          hasAlerts: childHasAlerts,
                          safetyScore: child.score,
                          alertCount: childAlertCount,
                        ),
                      ),
                    ),
                  );
                }),

              // ── Monitored apps ──
              SlideTransition(
                position: _appsSlide,
                child: Opacity(
                  opacity: _appsFade.value,
                  child: _buildMonitoredApps(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Recent activity ──
              SlideTransition(
                position: _activitySlide,
                child: Opacity(
                  opacity: _activityFade.value,
                  child: _buildRecentActivity(
                    hasAlerts: hasAlerts,
                    alertCount: alertCount,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // ──  Child Selector Dropdown
  // ═══════════════════════════════════════════
  Widget _buildChildSelector(List<ChildModel> children, ChildModel? activeChild,
      DashboardDataService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: KovaColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ChildModel>(
          value: activeChild,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down,
              color: KovaColors.primary, size: 20),
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: KovaColors.primary,
          ),
          items: children.map((child) {
            return DropdownMenuItem<ChildModel>(
              value: child,
              child: Text(
                child.name,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: (ChildModel? newChild) {
            if (newChild != null) {
              service.setActiveChild(newChild.id);
            }
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  No Child Card
  // ═══════════════════════════════════════════
  Widget _buildNoChildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KovaColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.child_care,
            size: 48,
            color: KovaColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No child added yet',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: KovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a child to start monitoring',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: KovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.push(AppRoutes.childProfile);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Child'),
            style: ElevatedButton.styleFrom(
              backgroundColor: KovaColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Child Card
  // ═══════════════════════════════════════════
  Widget _buildChildCard({
    required ChildModel child,
    required bool hasAlerts,
    required int safetyScore,
    required int alertCount,
  }) {
    final badgeColor = hasAlerts ? KovaColors.danger : KovaColors.success;
    final badgeText = hasAlerts ? 'Action required' : 'Protected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KovaColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KovaColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: KovaColors.primary.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: Text(
              child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: KovaColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name + age
          Text(
            child.name,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: KovaColors.textPrimary,
            ),
          ),
          Text(
            '${child.age} years',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: KovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Safety score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '$safetyScore',
                  key: ValueKey(safetyScore),
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: hasAlerts ? KovaColors.danger : KovaColors.success,
                  ),
                ),
              ),
              Text(
                '/100',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KovaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Alert count
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              hasAlerts ? '$alertCount alerts' : 'No alerts',
              key: ValueKey(alertCount),
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasAlerts ? KovaColors.danger : KovaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Monitored Apps
  // ═══════════════════════════════════════════
  Widget _buildMonitoredApps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monitored apps',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: KovaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _appIconBox(
              const Color(0xFF000000),
              const FaIcon(FontAwesomeIcons.xTwitter, size: 18),
            ),
            _appIconBox(
              const Color(0xFF25D366),
              const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
            ),
            _appIconBox(
              const Color(0xFF010101),
              const FaIcon(FontAwesomeIcons.tiktok, size: 18),
            ),
            _appIconBox(
              const Color(0xFF1877F2),
              const FaIcon(FontAwesomeIcons.facebook, size: 20),
            ),
            _appIconBox(
              const Color(0xFFE4405F),
              const FaIcon(FontAwesomeIcons.instagram, size: 20),
            ),
            _appIconBox(
              const Color(0xFF34C759),
              const FaIcon(FontAwesomeIcons.commentDots, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _appIconBox(Color color, Widget icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(color: color, size: 20),
          child: icon,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Recent Activity
  // ═══════════════════════════════════════════
  Widget _buildRecentActivity({
    required bool hasAlerts,
    required int alertCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent activity',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: KovaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: hasAlerts
              ? _buildAlertActivityCard(
                  alertCount: alertCount,
                  key: const ValueKey('alert'),
                )
              : _buildSafeActivityCard(key: const ValueKey('safe')),
        ),
      ],
    );
  }

  Widget _buildSafeActivityCard({Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: KovaColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KovaColors.success.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: KovaColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'No threat detected today',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KovaColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              'Last scan: 2 minutes ago',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: KovaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertActivityCard({required int alertCount, Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: KovaColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KovaColors.danger.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: KovaColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                '$alertCount threats detected',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KovaColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              'Tap on Alerts tab to review',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: KovaColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedNavIndex = 1);
              },
              child: Text(
                'View details →',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KovaColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──  Bottom Navigation
  // ═══════════════════════════════════════════
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: KovaColors.cardWhite,
        border: Border(
          top: BorderSide(
            color: KovaColors.divider.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (i) => setState(() => _selectedNavIndex = i),
        backgroundColor: KovaColors.cardWhite,
        selectedItemColor: KovaColors.primary,
        unselectedItemColor: KovaColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
