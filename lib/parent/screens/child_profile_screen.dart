// parent/screens/child_profile_screen.dart — Child profile setup screen
// Used during parent onboarding to enter child's name and age

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kova/core/router.dart';

import 'package:kova/shared/services/local_storage.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final _nameController = TextEditingController();
  int _selectedAge = 10;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your child\'s information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Child\'s Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                initialValue: _selectedAge,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                items: List.generate(13, (i) => i + 5)
                    .map((age) => DropdownMenuItem(
                          value: age,
                          child: Text('$age years old'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAge = val);
                },
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  if (_nameController.text.trim().isNotEmpty) {
                    await LocalStorage.setString('child_name', _nameController.text.trim());
                    if (context.mounted) {
                      context.go(AppRoutes.parentMonitoredApps);
                    }
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
