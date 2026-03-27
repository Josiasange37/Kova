// services/seed_service.dart — Seeds demo data on first launch
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kova/services/local_auth_service.dart';
import 'package:kova/services/local_data_service.dart';

class SeedService {
  static const String _seededKey = 'kova_data_seeded';

  /// Seed demo data if first launch
  static Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) == true) return;

    final auth = LocalAuthService();
    final data = LocalDataService();

    // 1. Register demo parent "John"
    final registered = await auth.register('John', '+1234567890', '1234');
    if (!registered) return;

    final parentId = await auth.getParentId();
    if (parentId == null) return;

    // Log out so user goes through onboarding
    await auth.logout();

    // 2. Create child "Alex"
    final child = await data.addChild(parentId, 'Alex', 12);
    if (child == null) return;

    // 3. Add monitored apps
    final apps = [
      {'name': 'WhatsApp', 'pkg': 'com.whatsapp', 'cat': 'messaging'},
      {'name': 'Instagram', 'pkg': 'com.instagram.android', 'cat': 'social'},
      {'name': 'TikTok', 'pkg': 'com.zhiliaoapp.musically', 'cat': 'social'},
      {'name': 'X (Twitter)', 'pkg': 'com.twitter.android', 'cat': 'social'},
      {'name': 'Facebook', 'pkg': 'com.facebook.katana', 'cat': 'social'},
      {'name': 'Messages', 'pkg': 'com.google.android.apps.messaging', 'cat': 'messaging'},
    ];

    for (final app in apps) {
      await data.addMonitoredApp(
        childId: child.id,
        appName: app['name']!,
        packageName: app['pkg'],
        category: app['cat']!,
      );
    }

    // 4. Create sample alerts
    await data.addAlert(
      childId: child.id,
      appName: 'WhatsApp',
      alertType: 'suspicious_contact',
      severity: 'high',
      senderInfo: 'Unknown +9876543210',
      contentPreview: 'Suspicious message from unknown contact requesting personal info',
      aiConfidence: 0.92,
    );

    await data.addAlert(
      childId: child.id,
      appName: 'Instagram',
      alertType: 'inappropriate_content',
      severity: 'medium',
      contentPreview: 'Potentially inappropriate content detected in DM',
      aiConfidence: 0.78,
    );

    await data.addAlert(
      childId: child.id,
      appName: 'TikTok',
      alertType: 'cyberbullying',
      severity: 'critical',
      senderInfo: 'User @anon_user_42',
      contentPreview: 'Aggressive language and threats detected in comments',
      aiConfidence: 0.95,
    );

    // 5. Create default settings
    await data.ensureSettings(parentId);

    // Mark as seeded
    await prefs.setBool(_seededKey, true);
  }
}
