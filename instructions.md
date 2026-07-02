# CLAUDE.md - KOVA Parental Control App

This file provides comprehensive context for Claude Code when working with the KOVA project.

## Quick Reference

- **Tech Stack**: Flutter (Dart), Android (Kotlin), Node.js backend
- **App Type**: Dual-mode parental control (Child mode + Parent mode)
- **Platforms**: Android (primary), planned iOS
- **Database**: SQLite (local), PostgreSQL (server)
- **AI**: TensorFlow Lite on-device + keyword analysis

## Project Structure

```
lib/
├── child/           # Child device: monitoring, detection, blocking
│   ├── services/    # DetectionOrchestrator, MonitoringBridge, etc.
│   └── screens/     # Child UI, setup, status
├── parent/          # Parent device: dashboard, alerts, controls
│   ├── services/    # DashboardDataService, AlertHistoryService, etc.
│   └── screens/     # Parent UI, dashboard, settings
├── shared/          # Common: NetworkSync, LAN discovery, models
├── local_backend/   # SQLite: DatabaseService, repositories
└── core/            # AppMode, constants, router

android/             # Native Kotlin code
├── app/src/main/kotlin/com/kova/child/
│   ├── MainActivity.kt
│   ├── KovaAccessibilityService.kt  (detects app changes, shows overlay)
│   ├── KovaNotificationListener.kt  (captures notifications)
│   ├── KovaForegroundService.kt     (keeps app alive)
│   └── BlockOverlayActivity.kt      (blocking UI)

server/              # Node.js backend for Internet relay
```

## Key Services

### Child Side (Critical for Understanding)

1. **DetectionOrchestrator** (`lib/child/services/detection_orchestrator.dart`)
   - MASTER coordinator for all detection
   - Entry points: `start()`, `stop()`, `safeBlockApp()`
   - Processes: content (notifications/keyboard), conversations, metadata (window changes)
   - NEVER crash this - wraps everything in try-catch

2. **MonitoringBridge** (`lib/child/services/monitoring_bridge.dart`)
   - Bridge between native Android and Flutter
   - 3 MethodChannels: notifications, keyboard, accessibility
   - Data flows: Native → MethodChannel → Dart callbacks

3. **Safe Blocking** (`safeBlockApp()` method)
   - Use this instead of direct blocking
   - Has 3-attempt retry with exponential backoff
   - 500ms delay to avoid race conditions
   - Critical for MIUI/Xiaomi compatibility

### Parent Side

1. **DashboardDataService** (`lib/parent/services/dashboard_data_service.dart`)
   - Manages parent dashboard state
   - Subscribes to alert streams
   - Child profile management

2. **NetworkSyncService** (`lib/shared/services/network_sync_service.dart`)
   - LAN discovery (UDP port 18756)
   - Internet relay (Vercel backend)
   - Alert pushing to parent

## Critical Patterns

### Error Handling Philosophy
```dart
// Always wrap native calls
try {
  await platform.invokeMethod('blockApp', {'pkg': pkg});
} catch (e) {
  debugPrint('⚠️ [BLOCK] Failed: $e');
  // Retry or fail gracefully - NEVER crash
}
```

### Null Safety Guards
```dart
// Check before using bang operator
if (_childId == null) {
  debugPrint('❌ Cannot create alert: _childId is null');
  return;
}
// Now safe to use: _childId!
```

### Stream Management
```dart
// Always check if closed
if (!_alertStreamController.isClosed) {
  _alertStreamController.add(alert);
}
```

## Common Issues to Avoid

1. **Don't call `_safeBlockApp`** - renamed to `safeBlockApp` (public method)
2. **Don't forget await** on NotificationService calls
3. **Don't close streams twice** - check `isClosed` first
4. **Don't use ! on nullable** without null check
5. **Don't block on UI thread** - use `Future.delayed()` before blocking

## Testing on Real Device

Emulator CANNOT test:
- Accessibility service (needs real apps)
- Notification listener (needs real notifications)
- Keyboard input (needs real keyboard)
- App blocking (needs real windows)

Always test on physical Android device (preferably Xiaomi/Redmi to catch MIUI issues).

## Build Commands

```bash
# Analyze before building
flutter analyze

# Build release APK
flutter clean
flutter pub get
flutter build apk --release

# Install and test
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Debugging

```bash
# View logs
adb logcat | grep -E "flutter|kova|KOVA"

# Check specific component
adb logcat | grep "DetectionOrchestrator"
```

## Backend (Vercel/Azure/DO)

Server needs:
- Node.js 18+
- PostgreSQL database
- WebSocket support (for real-time)
- Endpoints:
  - POST /api/pair/register
  - POST /api/pair/claim
  - POST /api/alert/push

## Security Notes

- All sensitive data encrypted at rest
- LAN communication uses AES encryption
- No cloud storage of actual message content
- Only metadata and alerts sent to parent
- Child content analyzed on-device (TFLite)

## When Making Changes

1. **Test on real device** - not emulator
2. **Check MIUI compatibility** - add error handling
3. **Add retry logic** - for all native calls
4. **Log with emojis** - ✅ ❌ ⚠️ for quick visual scanning
5. **Update SKILL.md** - if architecture changes
6. **Commit with clear messages** - reference issue if fixing bug

## Contact & Resources

- Full docs: `DOCUMENTATION_COMPLETE_FRANCAIS.md`
- Bug fixes: `ADDITIONAL_BUGS_FIXED.md`
- Market research: `BUG_FIXES_AND_MARKET_RESEARCH.md`
- Build guides: `BUILD_WORKFLOW.md`, `COMPLETE_BUILD_GUIDE.md`

---

*Context file for Claude Code - KOVA Development*
