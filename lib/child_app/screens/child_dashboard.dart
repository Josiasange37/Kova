import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/kova_theme.dart';
import 'block_screen.dart';

class ChildDashboard extends StatelessWidget {
  const ChildDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
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
                                  color: Colors.white.withOpacity(0.2),
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
                          "Hi Liam 👋",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Score Card
                        _buildScoreCard(),

                        const SizedBox(height: 32),

                        // Screen Time Section
                        _buildSectionHeader("Screen time"),
                        const SizedBox(height: 16),
                        _buildScreenTimeCard(),

                        const SizedBox(height: 32),

                        // Blocked Attempts Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader("Blocked attempts"),
                            Text(
                              "12 blocks today",
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE53935),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBlockedAttemptsList(),

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BlockScreen()));
        },
        backgroundColor: KovaTheme.primaryBlue,
        child: const Icon(Icons.shield_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  value: 0.62,
                  strokeWidth: 16,
                  backgroundColor: Colors.grey.shade100,
                  color: const Color(0xFF1E2A5D),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A5D).withOpacity(0.1),
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
                        "62",
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
                    "Fair",
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
            "Keep it up! Your safety score is improving.",
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

  Widget _buildScreenTimeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "2h 45m",
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E2A5D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "3h daily limit",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: KovaTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "45m remaining",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF57C00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(0.4, "Mon"),
                _buildBar(0.7, "Tue"),
                _buildBar(0.85, "Wed", isToday: true),
                _buildBar(0.5, "Thu"),
                _buildBar(0.9, "Fri"),
                _buildBar(
                  1.0,
                  "Sat",
                  color: const Color(0xFFE53935),
                ), // Exceeded
                _buildBar(0.6, "Sun"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
    double height,
    String label, {
    bool isToday = false,
    Color? color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 90 * height,
          decoration: BoxDecoration(
            color:
                color ??
                (isToday ? const Color(0xFF1E2A5D) : const Color(0xFFEEF2FF)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            color: isToday ? const Color(0xFF1E2A5D) : KovaTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedAttemptsList() {
    return Column(
      children: [
        _buildAttemptItem(
          icon: Icons.games_outlined,
          iconColor: const Color(0xFF4CAF50),
          iconBg: const Color(0xFFE8F5E9),
          title: "Minecraft",
          subtitle: "Exceeded limit",
          time: "2m ago",
        ),
        const SizedBox(height: 12),
        _buildAttemptItem(
          icon: Icons.music_note_outlined,
          iconColor: const Color(
            0xFFE1306C,
          ), // TikTok brand color approximation
          iconBg: const Color(0xFFFCE4EC),
          title: "TikTok",
          subtitle: "Blocked app",
          time: "15m ago",
        ),
        const SizedBox(height: 12),
        _buildAttemptItem(
          icon: Icons.language_outlined,
          iconColor: const Color(0xFF1E2A5D),
          iconBg: const Color(0xFFEEF2FF),
          title: "Unknown Website",
          subtitle: "Harmful content",
          time: "1h ago",
        ),
      ],
    );
  }

  Widget _buildAttemptItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E2A5D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: KovaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: KovaTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
