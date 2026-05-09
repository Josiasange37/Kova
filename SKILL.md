# KOVA - AI Assistant Skill File

---
name: kova
description: Complete understanding of KOVA Parental Control App architecture, codebase, and development patterns
version: 1.0.0
author: KOVA Development Team
tags: [flutter, dart, parental-control, android, ios, safety, ai-moderation]
---

## 🎯 Project Overview

**KOVA** is an AI-powered parental control app for Android (and planned iOS) that monitors children's digital activities in real-time, detects potentially harmful content using on-device TensorFlow Lite AI + keyword analysis, and alerts parents immediately via LAN (local network) or Internet (Vercel relay).

### Core Features
- **Real-time content monitoring** (notifications, keyboard, accessibility events)
- **AI-powered detection** (TFLite NLP model for text classification)
- **Keyword-based detection** (hardcoded + expandable word lists)
- **Instant app blocking** (overlay appears on dangerous content)
- **Parent-child pairing** (LAN discovery + Vercel relay fallback)
- **Real-time alerts** (push to parent device instantly)
- **Tamper protection** (detects uninstall attempts, settings changes)
- **Offline capability** (works without internet, syncs when available)

### Architecture Pattern
**Dual-Mode App**: Single codebase serves both "Child" and "Parent" roles based on `AppMode` setting.

```
lib/
├── child/          # Child-side features (monitoring, detection)
├── parent/         # Parent-side features (dashboard, alerts)
├── shared/         # Common utilities, models, services
├── local_backend/  # SQLite database, repositories
├── core/           # App configuration, routing, constants
└── main.dart       # Entry point with mode-based initialization
```

---

## 📁 Directory Structure Deep Dive

### `/lib/child/` - Child Device Side

**Purpose**: All code running on the child's phone for monitoring and protection.

**Services** (`/lib/child/services/`):
| File | Purpose | Key Methods |
|------|---------|-------------|
| `detection_orchestrator.dart` | **MASTER COORDINATOR** - Central hub for all detection logic | `start()`, `stop()`, `safeBlockApp()`, `_processContent()`, `_processConversation()`, `_processMetadata()` |
| `monitoring_bridge.dart` | Bridge between native Android services and Flutter | `initialize()`, `_handleNotification()`, `_handleAccessibility()`, `_handleKeyboard()` |
| `accessibility_service.dart` | Permission helpers for accessibility, notifications, keyboard | `isAccessibilityPermissionGranted()`, `requestAccessibilityPermission()`, `isNotificationListenerEnabled()` |
| `accessibility_bridge.dart` | Legacy bridge, now delegates to DetectionOrchestrator | `blockApp()` (uses `safeBlockApp()` internally), `pauseMonitoring()`, `resumeMonitoring()` |
| `text_analyzer.dart` | Keyword-based text analysis | `analyze()`, `_loadKeywordDatasets()`, `addCustomKeywords()` |
| `tflite_analyzer_service.dart` | TensorFlow Lite NLP model wrapper | `init()`, `analyzeText()`, `analyzeBatch()`, `close()` |
| `context_detector.dart` | Conversation context analysis (grooming detection) | `analyzeConversation()`, `_detectGroomingPatterns()`, `_calculateRiskScore()` |
| `severity_engine.dart` | Calculates alert severity from scores | `calculate()`, `scoreDelta()`, `shouldBlock()` |
| `image_classifier.dart` | Placeholder for image content analysis | `classifyImage()` |
| `text_classifier.dart` | Text classification wrapper | `classify()` |

**Screens** (`/lib/child/screens/`):
- `child_dashboard.dart` - Main child interface
- `parent_connection_screen.dart` - QR code pairing with parent
- `accessibility_setup_screen.dart` - Guides permission setup
- `monitored_apps_screen.dart` - Shows which apps are monitored
- `final_active_screen.dart` - "Kova is protecting you" status screen
- `dashboard_screen.dart`, `splash_screen.dart`, `welcome_screen.dart` - Onboarding

### `/lib/parent/` - Parent Device Side

**Purpose**: Dashboard for parents to view alerts, manage child settings, and receive notifications.

**Services** (`/lib/parent/services/`):
| File | Purpose | Key Methods |
|------|---------|-------------|
| `dashboard_data_service.dart` | Manages dashboard state, alert subscriptions | `loadDashboardData()`, `setActiveChild()`, `deleteChild()`, `dispose()` |
| `alert_history_service.dart` | Loads and filters alert history | `loadAlertHistory()`, `filterAlerts()`, `markAsRead()`, `resolveAlert()` |
| `app_control_service.dart` | Manages app blocking rules | `loadAppControls()`, `blockApp()`, `unblockApp()`, `setTimeLimit()` |
| `child_profile_service.dart` | CRUD for child profiles | `createChild()`, `updateChild()`, `deleteChild()`, `getChild()` |
| `settings_service.dart` | Parent app settings | `loadSettings()`, `updateSettings()`, `exportData()`, `importData()` |

**Screens** (`/lib/parent/screens/`):
- `dashboard_screen.dart` - Main parent dashboard with alerts
- `alert_history_screen.dart` - List of all past alerts
- `alert_detail_screen.dart` - Detailed view of single alert
- `child_profile_screen.dart` - Child profile management
- `app_control_screen.dart` - Per-app settings (time limits, blocking)
- `web_history_screen.dart` - Child's browsing history
- `whatsapp_connect_screen.dart` - WhatsApp Business API integration
- `settings_screen.dart` - Parent app settings
- `accessibility_setup_screen.dart` - Guide for child phone setup
- `pin_entry_screen.dart`, `pin_modification_screen.dart` - PIN protection
- `splash_screen.dart`, `welcome_screen.dart`, `success_screen.dart` - Onboarding

### `/lib/shared/` - Common Resources

**Purpose**: Models, services, and utilities used by both child and parent sides.

**Services** (`/lib/shared/services/`):
| File | Purpose | Key Methods |
|------|---------|-------------|
| `network_sync_service.dart` | **CRITICAL** - LAN and Internet sync, pairing management | `start()`, `stop()`, `registerPairingCode()`, `pushAlert()`, `claimPairingCode()` |
| `lan_discovery_service.dart` | UDP broadcast discovery for LAN pairing | `start()`, `stop()`, `findPeerByCode()`, `waitForPeerWithCode()` |
| `lan_data_service.dart` | TCP server/client for full data transfer over LAN | `startServer()`, `connectToPeer()`, `sendAlert()`, `sendProfile()` |
| `notification_service.dart` | Local notification display | `init()`, `showAlertNotification()`, `showCriticalAlert()` |
| `crypto_service.dart` | Encryption for LAN communication | `encryptPayload()`, `decryptPayload()`, `generateKey()` |
| `local_storage.dart` | SharedPreferences wrapper | `getString()`, `setString()`, `getInt()`, `setInt()` |
| `security_service.dart` | PIN hashing, tamper detection | `hashPin()`, `verifyPin()`, `encryptData()`, `decryptData()` |

**Models** (`/lib/shared/models/`):
- `alert.dart` - Alert data structure
- `child_profile.dart` - Child profile model
- `network_alert.dart` - Alert format for network transmission
- `pending_sync.dart` - Queue for offline sync
- `web_history.dart` - Browser history entry

**Screens** (`/lib/shared/screens/`):
- `pin_entry_screen.dart` - Reusable PIN entry UI
- `splash_screen.dart` - App initialization screen

### `/lib/local_backend/` - Database Layer

**Purpose**: SQLite database for local storage.

**Database** (`/lib/local_backend/database/`):
- `database_service.dart` - Singleton database manager
  - `database` getter - Returns SQLite instance
  - `_createTables()` - Creates all tables
  - `close()` - Closes connection

**Repositories** (`/lib/local_backend/repositories/`):
| File | Purpose | Tables Managed |
|------|---------|----------------|
| `alert_repository.dart` | Alert CRUD operations | `alerts` table |
| `child_repository.dart` | Child profile CRUD | `children` table |
| `browser_history_repository.dart` | Web history CRUD | `browser_history` table |
| `pending_sync_repository.dart` | Offline sync queue | `pending_sync` table |

### `/lib/core/` - App Foundation

**Files**:
| File | Purpose |
|------|---------|
| `app_mode.dart` | Enum: `AppMode.child` or `AppMode.parent` |
| `constants.dart` | App-wide constants (colors, durations, limits) |
| `router.dart` | GoRouter configuration for navigation |

### `/android/` - Android Native Code

**Key Files** (`/android/app/src/main/kotlin/com/kova/child/`):
| File | Purpose |
|------|---------|
| `MainActivity.kt` | Main Flutter activity, sets up MethodChannels |
| `KovaAccessibilityService.kt` | Accessibility service - detects window changes, shows overlay |
| `KovaNotificationListener.kt` | Captures notifications from all apps |
| `KovaForegroundService.kt` | Keeps app running in background |
| `KovaInputMethodService.kt` | Custom keyboard to capture outgoing messages |
| `KovaDeviceAdmin.kt` | Device admin receiver for tamper protection |
| `KovaBootReceiver.kt` | Restarts services after phone reboot |
| `BlockOverlayActivity.kt` | Activity that shows blocking overlay |
| `LanDiscoveryService.kt` | Native UDP discovery service |
| `OnboardingHelper.kt` | Guides users through permission setup |

**MethodChannels**:
- `com.kova.child/setup` - General setup, permissions
- `com.kova.child/blocker` - App blocking requests
- `com.kova.child/notifications` - Notification capture data
- `com.kova.child/keyboard` - Keyboard input data
- `com.kova.child/accessibility` - Accessibility events

### `/server/` - Backend (Node.js)

**Purpose**: Vercel-hosted relay for Internet-based parent-child communication.

**Key Files**:
| File | Purpose |
|------|---------|
| `index.js` or `server.js` | Main Express server |
| `routes/pairing.js` | Pairing code registration/claim |
| `routes/alerts.js` | Alert relay endpoints |
| `models/` - Database models (if using MongoDB/PostgreSQL) |

**API Endpoints**:
- `POST /api/pair/register` - Parent registers pairing code
- `POST /api/pair/claim` - Child claims pairing code
- `POST /api/alert/push` - Push alert to parent
- `GET /api/alert/:childId` - Parent polls for alerts

---

## 🔧 Key Development Patterns

### 1. Singleton Pattern
Most services are singletons:
```dart
class DetectionOrchestrator {
  static final DetectionOrchestrator instance = DetectionOrchestrator._internal();
  factory DetectionOrchestrator() => instance;
  DetectionOrchestrator._internal();
}
```

### 2. MethodChannel Communication
Native-Flutter communication:
```dart
static const _setup = MethodChannel('com.kova.child/setup');

Future<bool> isAccessibilityPermissionGranted() async {
  final result = await _setup.invokeMethod<bool>('isAccessibilityEnabled');
  return result ?? false;
}
```

### 3. Stream-Based Reactive Updates
Alerts flow through streams:
```dart
final _alertStreamController = StreamController<AlertModel>.broadcast();
Stream<AlertModel> get onNewAlert => _alertStreamController.stream;
```

### 4. Retry Logic for Critical Operations
All blocking operations have retry:
```dart
Future<void> safeBlockApp(String app) async {
  int attempts = 0;
  while (attempts < 3) {
    try {
      await platform.invokeMethod('blockAppViaService', {'pkg': pkg});
      return;
    } catch (e) {
      attempts++;
      await Future.delayed(Duration(milliseconds: 300 * attempts));
    }
  }
}
```

### 5. Error Handling Philosophy
- Catch at boundaries (MethodChannel, database, network)
- Log with descriptive emojis (✅, ❌, ⚠️)
- Fail gracefully - app continues even if one component fails
- Never crash the child app - safety is priority

### 6. Database Pattern
Repository pattern with SQLite:
```dart
class AlertRepository {
  final DatabaseService _db = DatabaseService();
  
  Future<int> create({...}) async {
    final db = await _db.database;
    return await db.insert('alerts', {...});
  }
}
```

---

## 🐛 Common Issues & Solutions

### Issue: Overlay crashes on Xiaomi/MIUI
**Solution**: Use `safeBlockApp()` with delay and retry logic. MIUI has aggressive battery optimization - need to handle errors gracefully.

### Issue: Null pointer on `_childId!`
**Solution**: Always check `_childId != null` before using bang operator. Added guards in all alert creation methods.

### Issue: StreamController already closed
**Solution**: Check `!_alertStreamController.isClosed` before calling `close()`.

### Issue: TFLite model not found
**Solution**: Check AssetManifest.json before loading, gracefully fallback to keyword-only mode.

### Issue: LAN discovery not working
**Solution**: Need MulticastLock on Android, use UDP port 18756, check firewall rules.

### Issue: Database locked (SQLite)
**Solution**: Use singleton pattern, don't open multiple connections, use transactions for writes.

---

## 🚀 Build Commands

```bash
# Development
flutter run

# Build APK (Android)
flutter build apk --release

# Build with verbose logging
flutter build apk --release --verbose

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

---

## 📱 Testing Checklist

### Child App
- [ ] Setup wizard completes without errors
- [ ] All permissions granted (accessibility, notifications, keyboard, device admin)
- [ ] Typing "dangerous words" triggers detection
- [ ] Overlay appears and blocks app
- [ ] App restart doesn't break monitoring
- [ ] Tamper detection works (try to uninstall)

### Parent App
- [ ] Can pair with child (QR code or manual)
- [ ] Receives alerts in real-time
- [ ] Can view alert details
- [ ] Can block/unblock apps remotely
- [ ] Can set time limits

### Network
- [ ] LAN mode works (same WiFi)
- [ ] Internet mode works (Vercel relay)
- [ ] Alerts sync when offline then online

---

## 🎓 Code Style Guidelines

### Naming
- Classes: `PascalCase` (e.g., `DetectionOrchestrator`)
- Methods: `camelCase` (e.g., `safeBlockApp`)
- Private methods: `_camelCase` with underscore (e.g., `_processContent`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_SEQ_LEN`)
- Files: `snake_case.dart` (e.g., `detection_orchestrator.dart`)

### Comments
- Use `//` for single line
- Use `///` for documentation comments (above classes/methods)
- Add emoji indicators: ✅ (success), ❌ (error), ⚠️ (warning), 🎯 (important)
- Log messages should be descriptive: `'⚠️ [BLOCK] Failed to block app $appKey: $e'`

### Imports
- Always use full package paths: `import 'package:kova/...'`
- Group: Dart SDK → Flutter → Third-party → Project
- Remove unused imports immediately

---

## 🔗 Related Resources

- **Pubspec**: `/pubspec.yaml` - Dependencies
- **Documentation**: `DOCUMENTATION_COMPLETE_FRANCAIS.md` - Full French docs
- **Bug Fixes**: `ADDITIONAL_BUGS_FIXED.md` - Known issues and fixes
- **Market Research**: `BUG_FIXES_AND_MARKET_RESEARCH.md` - Business analysis
- **Build Guide**: `BUILD_WORKFLOW.md`, `COMPLETE_BUILD_GUIDE.md`

---

## 💡 AI Assistant Instructions

When working with KOVA:

1. **Always check AppMode** - Child and Parent have different logic
2. **Never break detection flow** - Child safety is priority
3. **Add error handling** - Use try-catch on all native calls
4. **Test on real device** - Emulator doesn't have accessibility/keyboard
5. **Respect privacy** - Don't log actual message content in production
6. **Keep it lightweight** - Children's phones may be low-end
7. **Battery efficiency** - Don't poll constantly, use event-driven architecture

---

*Generated for Claude AI Assistant - KOVA Development Context*
