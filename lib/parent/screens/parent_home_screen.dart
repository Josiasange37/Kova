// parent/screens/parent_home_screen.dart — Parent dashboard (PLACEHOLDER)
import 'package:flutter/material.dart';

class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KOVA Parent'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Parent Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('(Coming soon...)'),
          ],
        ),
      ),
    );
  }
}
