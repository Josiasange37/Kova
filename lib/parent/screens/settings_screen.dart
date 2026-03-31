import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/parent/services/settings_service.dart';
import 'package:kova/parent/services/dashboard_data_service.dart';
import 'package:kova/parent/services/alert_history_service.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/database/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsService>().loadSettings();
    });
  }

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
    VoidCallback? onPressed,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? KovaColors.primary, size: 24),
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
                // ignore: use_null_aware_elements
                if (trailing != null) trailing,
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
      ),
    );
  }

  Widget _buildEditButton(VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
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

  void _showEditChildDialog(String currentName, int currentAge) {
    final nameController = TextEditingController(text: currentName);
    final ageController = TextEditingController(text: currentAge.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Child Profile', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Child Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newAge = int.tryParse(ageController.text) ?? currentAge;
              if (newName.isNotEmpty) {
                await _updateChildProfile(newName, newAge);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(String currentPhone) {
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Phone Number', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newPhone = phoneController.text.trim();
              await LocalStorage.setString('parent_phone', newPhone);
              setState(() {});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateChildProfile(String name, int age) async {
    final dashboard = context.read<DashboardDataService>();
    final child = dashboard.activeChild;
    if (child != null) {
      await context.read<DashboardDataService>().updateChildProfile(child.id, name, age);
      setState(() {});
    }
  }

  Future<void> _showDeleteChildDialog(ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${child.name}?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently remove ${child.name} and all associated alerts and monitoring data. This action cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: KovaColors.danger),
            child: Text('Delete', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dashboard = context.read<DashboardDataService>();
        await dashboard.deleteChild(child.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${child.name} has been deleted', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              backgroundColor: KovaColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              backgroundColor: KovaColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportWeeklyPDF() async {
    final alertService = context.read<AlertHistoryService>();
    
    // Get all alerts from the past week
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final allAlerts = alertService.allAlerts;
    final weeklyAlerts = allAlerts.where((a) => a.createdAt.isAfter(weekAgo)).toList();
    
    // Calculate stats
    final totalAlerts = weeklyAlerts.length;
    final resolvedAlerts = weeklyAlerts.where((a) => a.resolved).length;
    final criticalAlerts = weeklyAlerts.where((a) => a.severity == 'critical').length;
    
    // Show PDF generation dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Weekly Report', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Period: ${weekAgo.day}/${weekAgo.month} - ${now.day}/${now.month}/${now.year}'),
            const SizedBox(height: 16),
            _buildReportStat('Total Alerts', totalAlerts.toString()),
            _buildReportStat('Resolved', resolvedAlerts.toString()),
            _buildReportStat('Critical', criticalAlerts.toString()),
            const SizedBox(height: 16),
            const Text('PDF export functionality requires pdf package integration.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.nunito()),
          Text(
            value,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: KovaColors.primary),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Legal Information', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Policy', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'KOVA collects and processes data solely for child safety monitoring. '
                'All data is stored locally on your device. We do not share data with third parties.',
                style: GoogleFonts.nunito(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Terms of Service', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'By using KOVA, you agree to use this app responsibly for protecting children. '
                'This app is intended for parental monitoring of minor children only.',
                style: GoogleFonts.nunito(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Data Protection', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'All monitoring data is stored locally on your device. '
                'No data is transmitted to external servers without your explicit consent.',
                style: GoogleFonts.nunito(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, {VoidCallback? onTap}) {
    return TextButton(
      onPressed: onTap ?? () {},
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
          onPressed: () => context.pop(),
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
    );
  }

  Widget _buildBody() {
    final settings = context.watch<SettingsService>();
    final dashboard = context.watch<DashboardDataService>();

    // Real data from services
    final activeChild = dashboard.activeChild;
    final childName = activeChild?.name ?? 'No child';
    final childAge = activeChild?.age ?? 0;
    final parentPhone = LocalStorage.getString('parent_phone');

    // Map language code to display name
    final languageDisplay =
        settings.language == 'fr' ? 'Français' : 'English';

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
              subtitle: '$childName, $childAge years old',
              trailing: activeChild != null
                  ? _buildEditButton(() => _showEditChildDialog(childName, childAge))
                  : null,
            ),
            _buildSettingItem(
              Icons.local_phone_outlined,
              'Phone number',
              subtitle: parentPhone.isNotEmpty
                  ? parentPhone
                  : 'Not set',
              trailing: _buildEditButton(() => _showEditPhoneDialog(parentPhone)),
              showDivider: activeChild == null,
            ),
            if (activeChild != null)
              _buildSettingItem(
                Icons.delete_outline_rounded,
                'Delete child',
                subtitle: 'Remove $childName from monitoring',
                trailing: _buildActionButton('Delete', onTap: () => _showDeleteChildDialog(activeChild)),
                showDivider: false,
                iconColor: KovaColors.danger,
              ),
          ]),
          _buildSection('Security', [
            _buildSettingItem(
              Icons.lock_outline_rounded,
              'Change PIN',
              trailing: _buildActionButton('Change', onTap: () {
                context.push(AppRoutes.pinModification);
              }),
              showDivider: false,
            ),
          ]),
          _buildSection('Notifications', [
            _buildSettingItem(
              Icons.notifications_none_rounded,
              'Notifications',
              subtitle: settings.notificationsEnabled
                  ? 'Enabled'
                  : 'Disabled',
              trailing: Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: settings.notificationsEnabled,
                  onChanged: (v) => settings.setNotificationsEnabled(v),
                  activeTrackColor: KovaColors.primary,
                ),
              ),
            ),
            _buildSettingItem(
              Icons.volume_up_rounded,
              'Sound',
              trailing: Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: settings.soundEnabled,
                  onChanged: (v) => settings.setSoundEnabled(v),
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
                    _buildLanguageToggle(
                      'Français',
                      'fr',
                      languageDisplay,
                      settings,
                    ),
                    _buildLanguageToggle(
                      'English',
                      'en',
                      languageDisplay,
                      settings,
                    ),
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
              trailing: _buildActionButton('Export', onTap: _exportWeeklyPDF),
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
              trailing: _buildActionButton('View', onTap: _showLegalDialog),
              showDivider: false,
            ),
          ]),
          _buildSection('App Mode', [
            _buildSettingItem(
              Icons.swap_horiz_rounded,
              'Switch to Child Mode',
              subtitle: childName != 'No child'
                  ? "$childName's view"
                  : 'Not configured',
              trailing: _buildActionButton('Switch', onTap: () async {
                // Switch to child mode — use the child's UUID (pair code is
                // cleared after linking, so we use the persistent child ID).
                final child = dashboard.activeChild;
                if (child != null) {
                  await AppModeManager.setChildMode(child.id);
                }
                if (!mounted) return;
                context.go(AppRoutes.childDashboard);
              }),
              showDivider: true,
            ),
            _buildSettingItem(
              Icons.restart_alt_rounded,
              'Reset all settings',
              subtitle: 'Restore defaults',
              trailing: _buildActionButton('Reset', onTap: () async {
                await settings.resetToDefaults();
              }),
              showDivider: false,
            ),
          ]),
          const SizedBox(height: KovaSpacing.xl),
          OutlinedButton.icon(
            onPressed: () {
              context.push(AppRoutes.childProfile);
            },
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
          _buildSection('Account', [
            _buildSettingItem(
              Icons.logout_outlined,
              'Logout',
              subtitle: 'Clear all data and return to login',
              trailing: _buildActionButton('Logout', onTap: _showLogoutDialog),
              showDivider: false,
              iconColor: KovaColors.danger,
            ),
          ]),
          const SizedBox(height: KovaSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: KovaColors.danger)),
        content: Text(
          'This will clear ALL data and return you to the login screen:\n\n'
          '• All child profiles\n'
          '• All alerts and monitoring history\n'
          '• All settings and preferences\n'
          '• Parent account information\n\n'
          'This action cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KovaColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
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
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged out successfully', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              backgroundColor: KovaColors.success,
            ),
          );
          
          // Navigate to splash screen
          context.go(AppRoutes.splash);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              backgroundColor: KovaColors.danger,
            ),
          );
        }
      }
    }
  }

  Widget _buildLanguageToggle(
    String displayName,
    String langCode,
    String currentLanguageDisplay,
    SettingsService settings,
  ) {
    bool isSelected = currentLanguageDisplay == displayName;
    return GestureDetector(
      onTap: () => settings.setLanguage(langCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? KovaColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayName,
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
