import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/kova_theme.dart';
import 'whatsapp_connection_screen.dart';

class FinalActiveScreen extends StatelessWidget {
  const FinalActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                "KOVA is active",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  color: KovaTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your child's phone is being monitored by KOVA AI for a safer digital experience.",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: KovaTheme.textSecondary),
              ),
              const SizedBox(height: 48),

              const Text(
                "Current Monitoring",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: KovaTheme.textMain,
                ),
              ),
              const SizedBox(height: 16),

              _monitoredApp(
                context,
                "WhatsApp",
                "Active",
                Icons.message_rounded,
              ),
              _monitoredApp(
                context,
                "TikTok",
                "Active",
                Icons.video_collection_rounded,
              ),
              _monitoredApp(
                context,
                "Snapchat",
                "Active",
                Icons.snapchat_rounded,
              ),
              _monitoredApp(
                context,
                "Instagram",
                "Active",
                Icons.camera_alt_rounded,
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhatsappConnectionScreen(),
                    ),
                  );
                },
                child: const Text("Go to Dashboard"),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monitoredApp(
    BuildContext context,
    String name,
    String status,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: KovaTheme.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: KovaTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: KovaTheme.textMain,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: KovaTheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: KovaTheme.secondaryIndigo,
            size: 24,
          ),
        ],
      ),
    );
  }
}
