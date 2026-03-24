import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _quietHours = true;
  String _selectedLanguage = 'English';

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: KovaColors.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KovaColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: KovaColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KovaColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KovaColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: KovaColors.divider.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  Widget _buildEditButton() {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: KovaColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Edit',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _buildActionButton(String label) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: KovaColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: KovaColors.background,
      appBar: AppBar(
        backgroundColor: KovaColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: KovaColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: KovaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        backgroundColor: KovaColors.cardWhite,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: KovaColors.primary,
        unselectedItemColor: KovaColors.textSecondary.withValues(alpha: 0.5),
        selectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        currentIndex: 3,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_rounded),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: KovaSpacing.md),
        children: [
          if (widget.isEmbedded) ...[
            const SizedBox(height: KovaSpacing.lg),
            Text(
              'Settings',
              style: GoogleFonts.nunito(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: KovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: KovaSpacing.sm),
          ],
          _buildSection('Profile', [
            _buildSettingItem(
              Icons.person_outline_rounded,
              'Child name',
              subtitle: 'Alex, 12 years old',
              trailing: _buildEditButton(),
            ),
            _buildSettingItem(
              Icons.local_phone_outlined,
              'Phone number',
              subtitle: '+237 690 123 456',
              trailing: _buildEditButton(),
              showDivider: false,
            ),
          ]),
          _buildSection('Security', [
            _buildSettingItem(
              Icons.lock_outline_rounded,
              'Change PIN',
              trailing: _buildActionButton('Change'),
              showDivider: false,
            ),
          ]),
          _buildSection('Notifications', [
            _buildSettingItem(
              Icons.notifications_none_rounded,
              'Quiet hours',
              subtitle: '10pm — 6am',
              trailing: Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: _quietHours,
                  onChanged: (v) => setState(() => _quietHours = v),
                  activeTrackColor: KovaColors.primary,
                ),
              ),
              showDivider: false,
            ),
          ]),
          _buildSection('Language', [
            _buildSettingItem(
              Icons.language_rounded,
              'Language',
              trailing: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageToggle('Français'),
                    _buildLanguageToggle('English'),
                  ],
                ),
              ),
              showDivider: false,
            ),
          ]),
          _buildSection('Report', [
            _buildSettingItem(
              Icons.description_outlined,
              'Export weekly PDF',
              trailing: _buildActionButton('Export'),
              showDivider: false,
            ),
          ]),
          _buildSection('About', [
            _buildSettingItem(
              Icons.info_outline_rounded,
              'App version',
              subtitle: '1.0.0',
            ),
            _buildSettingItem(
              Icons.description_outlined,
              'Legal',
              trailing: _buildActionButton('View'),
              showDivider: false,
            ),
          ]),
          const SizedBox(height: KovaSpacing.xl),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add a child'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KovaColors.primary,
              side: const BorderSide(color: KovaColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: KovaSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle(String name) {
    bool isSelected = _selectedLanguage == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? KovaColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: GoogleFonts.nunito(
            color: isSelected ? Colors.white : KovaColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
