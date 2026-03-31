import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/parent/services/dashboard_data_service.dart';
import 'package:provider/provider.dart';

class ChildWelcomeScreen extends StatelessWidget {
  const ChildWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardDataService>();
    final activeChild = dashboard.activeChild;
    final childName = activeChild?.name ?? 'your child';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Child Setup',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: KovaColors.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: KovaColors.primary),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care,
              size: 80,
              color: KovaColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Setup $childName\'s Device',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: KovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Follow the steps to connect and protect $childName\'s device',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: KovaColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go(AppRoutes.whatsappConnect);
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('Generate Pairing Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KovaColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
