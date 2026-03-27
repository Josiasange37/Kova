import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MonitoringDashboardScreen extends StatelessWidget {
  const MonitoringDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Monitoring Dashboard',
          style: GoogleFonts.inter(fontSize: 24),
        ),
      ),
    );
  }
}
