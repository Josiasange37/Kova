// child/services/detection_orchestrator.dart — Master coordinator for all detection services
// Real implementation using TextAnalyzer, ContextDetector, SeverityEngine

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/local_backend/repositories/browser_history_repository.dart';
import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/models/web_history.dart';
import 'dart:convert';
import 'dart:async';
import 'package:kova/shared/services/notification_service.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/local_backend/repositories/pending_sync_repository.dart';
import 'package:kova/shared/models/pending_sync.dart';
import 'package:kova/shared/services/network_sync_service.dart';

import 'context_detector.dart';
import 'severity_engine.dart';
import 'monitoring_bridge.dart';
import 'tflite_analyzer_service.dart';

/// Master service that coordinates all detection and alerting
/// Only active when mode == AppMode.child
class DetectionOrchestrator {
  static final DetectionOrchestrator instance = DetectionOrchestrator._internal();
  DetectionOrchestrator._internal();

  final ChildRepository _childRepo = ChildRepository();
  final AlertRepository _alertRepo = AlertRepository();
  final BrowserHistoryRepository _browserRepo = BrowserHistoryRepository();
  final NetworkSyncService _networkSync = NetworkSyncService();
  final PendingSyncRepository _pendingSyncRepo = PendingSyncRepository();
  final ContextDetector _contextDetector = ContextDetector();
  final TfLiteAnalyzerService _tfLiteAnalyzer = TfLiteAnalyzerService();
  
  final _alertStreamController = StreamController<AlertModel>.broadcast();
  Stream<AlertModel> get onNewAlert => _alertStreamController.stream;
  
  bool _active = false;
  String? _childId;
  String? _lastUrl;
  DateTime? _lastUrlTimestamp;

  /// In-memory cache of blocked app keys — avoids DB reads on every window_changed
  final Set<String> _blockedApps = {};

  /// Start detection services
  Future<void> start() async {
    if (_active) return;
    
    // Get child ID
    _childId = await AppModeManager.getChildId();
    if (_childId == null) {
      if (kDebugMode) debugPrint('❌ DetectionOrchestrator: No child ID found');
      return;
    }

    _active = true;

    // Initialize ML model
    await _tfLiteAnalyzer.init();

    // Populate the blocked-app cache from the database
    try {
      final persisted = await _childRepo.getBlockedApps(_childId!);
      _blockedApps.addAll(persisted);
      if (kDebugMode && persisted.isNotEmpty) {
        debugPrint('🔒 Loaded ${persisted.length} blocked apps from DB: $persisted');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to load blocked apps cache: $e');
    }

    // Set up bridge callbacks for all 3 channels + tamper
    MonitoringBridge.onContent = _processContent;
    MonitoringBridge.onConversation = _processConversation;
    MonitoringBridge.onMetadata = _processMetadata;
    MonitoringBridge.onTamper = _processTamper;
    MonitoringBridge.onBrowserContent = _processBrowserContent;
    
    // Initialize bridge (registers handlers on 3 channels)
    MonitoringBridge.init();

    if (kDebugMode) debugPrint('🛡️ KOVA Detection Orchestrator: ACTIVE (${_blockedApps.length} apps blocked)');
  }

  /// Stop detection services
  void stop() {
    _active = false;
    _blockedApps.clear();
    _tfLiteAnalyzer.close();
    MonitoringBridge.reset();
    _alertStreamController.close();
    if (kDebugMode) debugPrint('🛑 KOVA Detection Orchestrator: STOPPED');
  }

  /// Process single content from monitoring services
  /// direction = 'incoming' (notification) or 'outgoing' (keyboard)
  Future<void> _processContent(
    String app,
    String text,
    String source,
    String direction,
    String conversationId,
    String? senderName,
  ) async {
    if (!_active || _childId == null) return;

    // Check if monitoring is enabled for this app
    final child = await _childRepo.getById(_childId!);
    if (child == null) return;

    final appKey = _normalizeAppName(app);
    final isEnabled = child.appControls[appKey] ?? true;
    if (!isEnabled) {
      if (kDebugMode) debugPrint('⏸️ Monitoring disabled for $appKey');
      return;
    }

    // Add to conversation context with direction info
    _contextDetector.addMessage(
      conversationId,
      text,
      sender: direction == 'outgoing' ? 'child' : senderName,
    );

    // Analyze text with ML
    final textScores = await _tfLiteAnalyzer.analyzeText(text);
    final contextResult = _contextDetector.analyze(conversationId);

    // Calculate severity
    final severity = SeverityEngine.calculate(
      textScores: textScores,
      contextScores: contextResult,
    );

    if (kDebugMode) {
      debugPrint('🔍 [$app] dir=$direction severity=$severity text=${textScores['unsafe']?.toStringAsFixed(2)} ctx=${contextResult['grooming_risk']?.toStringAsFixed(2)}');
    }

    // Skip safe content
    if (severity == 'safe') return;

    // Handle high/critical severity
    if (severity == 'critical' || severity == 'high') {
      await _blockApp(appKey);
    }

    // Update child score
    final delta = SeverityEngine.scoreDelta(severity);
    await _childRepo.updateScore(_childId!, delta);

    // Create alert
    final alertType = SeverityEngine.getType(
      textScores: textScores,
      contextScores: contextResult,
    );

    final alertId = await _alertRepo.create(
      childId: _childId!,
      app: appKey,
      type: alertType,
      severity: severity,
      scoreText: textScores['unsafe'] ?? 0.0,
      scoreImage: 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
    );

    _alertStreamController.add(AlertModel(
      id: alertId,
      childId: _childId!,
      app: appKey,
      type: alertType,
      severity: severity,
      scoreText: textScores['unsafe'] ?? 0.0,
      scoreImage: 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
      read: false,
      resolved: false,
      createdAt: DateTime.now(),
    ));

    // Show notification
    await _showAlertNotification(appKey, severity, alertId, text);

    // Push alert to parent via network (LAN full data or Vercel summary)
    print('📤 [ALERT PIPELINE] Step 1: Calling _pushAlertToNetwork for alert $alertId');
    await _pushAlertToNetwork(
      severity: severity,
      app: appKey,
      alertType: alertType,
      aiConfidence: textScores['unsafe'] ?? 0.0,
      contentPreview: text.length > 200 ? '${text.substring(0, 200)}...' : text,
      scoreText: textScores['unsafe'] ?? 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
      scoreDelta: delta,
    );

    print('✅ [ALERT PIPELINE] Step 5: Alert pipeline complete for $alertId');
    if (kDebugMode) debugPrint('🚨 Alert created: $alertId');
  }

  /// Process conversation batch
  Future<void> _processConversation(
    String app,
    List<Map<String, dynamic>> messages,
    String? senderName,
  ) async {
    if (!_active || _childId == null || messages.isEmpty) return;

    // Check if monitoring is enabled
    final child = await _childRepo.getById(_childId!);
    if (child == null) return;

    final appKey = _normalizeAppName(app);
    final isEnabled = child.appControls[appKey] ?? true;
    if (!isEnabled) return;

    // Extract texts for analysis
    final texts = messages
        .map((m) => m['text']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    if (texts.isEmpty) return;

    // Batch analyze with ML
    final batchResult = await _tfLiteAnalyzer.analyzeBatch(texts);
    final conversationId = '${appKey}_$_childId';
    
    // Add all messages to context
    for (final msg in messages) {
      _contextDetector.addMessage(
        conversationId,
        msg['text']?.toString() ?? '',
        sender: msg['sender']?.toString(),
      );
    }
    
    final contextResult = _contextDetector.analyze(conversationId);

    // Calculate severity
    final severity = SeverityEngine.calculate(
      textScores: batchResult,
      contextScores: contextResult,
    );

    if (severity == 'safe') return;

    // Handle blocking
    if (severity == 'critical' || severity == 'high') {
      await _blockApp(appKey);
    }

    // Update score
    final delta = SeverityEngine.scoreDelta(severity);
    await _childRepo.updateScore(_childId!, delta);

    // Create alert
    final alertType = SeverityEngine.getType(
      textScores: batchResult,
      contextScores: contextResult,
    );

    final alertId = await _alertRepo.create(
      childId: _childId!,
      app: appKey,
      type: alertType,
      severity: severity,
      scoreText: batchResult['unsafe'] ?? 0.0,
      scoreImage: 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
    );

    _alertStreamController.add(AlertModel(
      id: alertId,
      childId: _childId!,
      app: appKey,
      type: alertType,
      severity: severity,
      scoreText: batchResult['unsafe'] ?? 0.0,
      scoreImage: 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
      read: false,
      resolved: false,
      createdAt: DateTime.now(),
    ));

    await _showAlertNotification(appKey, severity, alertId, 'Conversation batch');

    // Push alert to parent via network
    await _pushAlertToNetwork(
      severity: severity,
      app: appKey,
      alertType: alertType,
      aiConfidence: batchResult['unsafe'] ?? 0.0,
      contentPreview: texts.take(3).join(' | '),
      scoreText: batchResult['unsafe'] ?? 0.0,
      scoreGrooming: (contextResult['grooming_risk'] as num?)?.toDouble() ?? 0.0,
      scoreDelta: delta,
    );

    if (kDebugMode) debugPrint('🚨 Conversation alert created: $alertId');
  }

  /// Process metadata from accessibility service
  /// Tracks which apps the child navigates to AND enforces active blocks
  void _processMetadata(
    String event,
    String app,
    Map<String, dynamic> data,
  ) {
    if (!_active) return;

    if (event == 'window_changed') {
      final appKey = _normalizeAppName(app);
      final windowType = data['windowType'] as String? ?? 'other';

      if (kDebugMode) {
        debugPrint('🪟 Child navigated to $appKey ($windowType)');
      }

      // ── LOCKING LOOP: If this app is in the blocked cache, re-block immediately ──
      if (_blockedApps.contains(appKey)) {
        if (kDebugMode) {
          debugPrint('🔒 BLOCKED APP DETECTED: $appKey — re-triggering block overlay');
        }
        // Fire-and-forget: don't await to keep the metadata handler fast
        _blockApp(appKey);
        return;
      }

      // Also check against the raw package name for apps not yet normalized
      final rawPkg = app.toLowerCase();
      for (final blocked in _blockedApps) {
        final pkg = _appKeyToPackage(blocked);
        if (pkg != null && rawPkg == pkg) {
          if (kDebugMode) {
            debugPrint('🔒 BLOCKED PKG DETECTED: $rawPkg — re-triggering block overlay');
          }
          _blockApp(blocked);
          return;
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // Web History Logging
  // ─────────────────────────────────────────────

  Future<void> _processBrowserContent(String app, String url, String title) async {
    if (!_active || _childId == null) return;
    
    // Debounce: don't log the exact same URL within 10 seconds
    final now = DateTime.now();
    if (_lastUrl == url && _lastUrlTimestamp != null) {
      if (now.difference(_lastUrlTimestamp!).inSeconds < 10) {
        return;
      }
    }
    
    _lastUrl = url;
    _lastUrlTimestamp = now;

    if (kDebugMode) {
      debugPrint('📚 Saving to Web History: $url ($title)');
    }

    final history = WebHistory(url: url, title: title, createdAt: now);

    // Save locally
    await _browserRepo.insert(history);

    // Queue for sync instead of pushing directly
    final pendingItem = PendingSync(
      id: 'hist_${now.millisecondsSinceEpoch}',
      type: 'history',
      payload: jsonEncode(history.toJson()),
    );
    await _pendingSyncRepo.insert(pendingItem);
  }

  // ─────────────────────────────────────────────
  // Tamper detection — self-defense alerts
  // ─────────────────────────────────────────────

  /// Handle tamper events from the native watchdog / accessibility service.
  /// These are ALWAYS critical severity — immediately alert the parent.
  Future<void> _processTamper(
    String type,
    String message,
    Map<String, dynamic> data,
  ) async {
    if (!_active || _childId == null) return;

    if (kDebugMode) {
      debugPrint('🛡️ TAMPER DETECTED: $type → $message');
    }

    // Map tamper type to human-readable description
    final descriptions = {
      'uninstall_attempt': 'Attempted to uninstall KOVA',
      'service_disable_attempt': 'Attempted to disable KOVA services',
      'accessibility_disabled': 'Accessibility service was disabled',
      'notification_listener_disabled': 'Notification listener was disabled',
      'keyboard_disabled': 'KOVA keyboard was disabled or switched',
      'device_admin_disabled': 'Device admin was deactivated',
    };

    final description = descriptions[type] ?? message;

    // 1. Store critical alert locally
    final alertId = await _alertRepo.create(
      childId: _childId!,
      app: 'kova_self_defense',
      type: 'tamper_$type',
      severity: 'critical',
      scoreText: 1.0,
      scoreImage: 0.0,
      scoreGrooming: 0.0,
    );

    _alertStreamController.add(AlertModel(
      id: alertId,
      childId: _childId!,
      app: 'kova_self_defense',
      type: 'tamper_$type',
      severity: 'critical',
      scoreText: 1.0,
      scoreImage: 0.0,
      scoreGrooming: 0.0,
      read: false,
      resolved: false,
      createdAt: DateTime.now(),
    ));

    // 2. Push to parent immediately
    await _pushAlertToNetwork(
      severity: 'critical',
      app: 'kova_self_defense',
      alertType: 'tamper_$type',
      aiConfidence: 1.0,
      contentPreview: description,
    );

    // 3. Send local notification
    NotificationService.showCriticalAlert(
      '🛡️ Tamper Alert',
      description,
    );
  }

  /// Push alert to parent device via network (LAN or Internet)
  Future<void> _pushAlertToNetwork({
    required String severity,
    required String app,
    required String alertType,
    required double aiConfidence,
    String? contentPreview,
    double scoreText = 0.0,
    double scoreGrooming = 0.0,
    int scoreDelta = 0,
  }) async {
    print('📤 [ALERT PIPELINE] Step 2: _pushAlertToNetwork started - app=$app, severity=$severity');
    try {
      final childName = LocalStorage.getString('child_name', 'Child');

      final alert = NetworkAlertFull(
        severity: severity,
        app: app,
        alertType: alertType,
        childName: childName,
        timestamp: DateTime.now(),
        aiConfidence: aiConfidence,
        contentPreview: contentPreview,
        scoreText: scoreText,
        scoreGrooming: scoreGrooming,
        scoreDelta: scoreDelta,
      );

      // We explicitly construct Summary here just in case, but really
      // NetworkSyncService used to do this. We'll just serialize it as NetworkAlertSummary
      // to the queue so it takes less space and is ready for Vercel.
      // Wait, LAN might want full data. 
      // If we put full data in the queue, NetworkSyncService can downcast it when sending to Vercel.
      final pendingItem = PendingSync(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: 'alert',
        payload: jsonEncode(alert.toJson()),
      );
      await _pendingSyncRepo.insert(pendingItem);

      // Trigger sync manually (optional, or let periodic loop handle)
      print('📤 [ALERT PIPELINE] Step 3: Triggering network sync loop...');
      _networkSync.triggerSyncLoop();

      print('✅ [ALERT PIPELINE] Step 4: Alert queued and sync triggered');
      if (kDebugMode) debugPrint('📤 Alert queued for network push');
    } catch (e) {
      print('❌ [ALERT PIPELINE] ERROR in _pushAlertToNetwork: $e');
      if (kDebugMode) debugPrint('⚠️ Network push failed (local alert saved): $e');
    }
  }

  // ─────────────────────────────────────────────
  // Package name mapping (shared by _blockApp & _appKeyToPackage)
  // ─────────────────────────────────────────────
  static const Map<String, String> _pkgMap = {
    // Messaging
    'whatsapp': 'com.whatsapp',
    'whatsapp_business': 'com.whatsapp.w4b',
    'facebook': 'com.facebook.katana',
    'messenger': 'com.facebook.orca',
    'messenger_lite': 'com.facebook.mlite',
    'tiktok': 'com.zhiliaoapp.musically',
    'instagram': 'com.instagram.android',
    'telegram': 'org.telegram.messenger',
    'signal': 'org.thoughtcrime.securesms',
    'twitter': 'com.twitter.android',
    'discord': 'com.discord',
    'snapchat': 'com.snapchat.android',
    'skype': 'com.skype.raider',
    'viber': 'com.viber.voip',
    'sms': 'com.google.android.apps.messaging',
    'samsung_messages': 'com.samsung.android.messaging',
    // Browsers
    'chrome': 'com.android.chrome',
    'firefox': 'org.mozilla.firefox',
    'brave': 'com.brave.browser',
    'opera': 'com.opera.browser',
    'edge': 'com.microsoft.emmx',
    'duckduckgo': 'com.duckduckgo.mobile.android',
    'samsung_browser': 'com.sec.android.app.sbrowser',
    'kiwi': 'com.kiwibrowser.browser',
    // Search & Video
    'youtube': 'com.google.android.youtube',
    'google': 'com.google.android.googlequicksearchbox',
  };

  /// Resolve an app key to its Android package name
  String? _appKeyToPackage(String appKey) => _pkgMap[appKey];

  /// Block an app using native blocker, persist to DB + in-memory cache
  Future<void> _blockApp(String app) async {
    const channel = MethodChannel('com.kova.child/blocker');

    final pkg = _pkgMap[app];
    if (pkg == null) return;

    // ── 1. Add to in-memory cache immediately (instant enforcement) ──
    _blockedApps.add(app);

    // ── 2. Persist to database (survives restart) ──
    if (_childId != null) {
      try {
        await _childRepo.setAppBlocked(_childId!, app, true);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to persist block for $app: $e');
      }
    }

    // ── 3. Trigger native overlay via DUAL approach ──
    // Approach A: MethodChannel (works when Flutter engine is alive)
    bool channelSuccess = false;
    try {
      await channel.invokeMethod('blockApp', {'pkg': pkg});
      channelSuccess = true;
      if (kDebugMode) debugPrint('🚫 App blocked via MethodChannel: $app ($pkg)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ MethodChannel block failed (engine dead?): $e');
    }

    // Approach B: ForegroundService Intent (works even when Flutter is backgrounded)
    // This is the reliable path — the service is always running.
    if (!channelSuccess) {
      try {
        const platform = MethodChannel('com.kova.child/setup');
        await platform.invokeMethod('blockAppViaService', {'pkg': pkg});
        if (kDebugMode) debugPrint('🚫 App blocked via ForegroundService: $app ($pkg)');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ ForegroundService block also failed: $e');
      }
    }
  }

  /// Unblock an app (called from parent dashboard via network sync)
  Future<void> unblockApp(String app) async {
    _blockedApps.remove(app);
    if (_childId != null) {
      try {
        await _childRepo.setAppBlocked(_childId!, app, false);
        if (kDebugMode) debugPrint('✅ App unblocked: $app');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to persist unblock for $app: $e');
      }
    }
  }

  /// Check if an app is currently blocked
  bool isAppBlocked(String app) => _blockedApps.contains(_normalizeAppName(app));

  /// Show alert notification to parent
  Future<void> _showAlertNotification(
    String app,
    String severity,
    String alertId,
    String content,
  ) async {
    final title = _getAlertTitle(app, severity);
    final body = _getAlertBody(app, severity, content);

    if (severity == 'critical') {
      await NotificationService.showCriticalAlert(title, body);
    } else {
      await NotificationService.showAlert(title, body, alertId: alertId);
    }
  }

  String _getAlertTitle(String app, String severity) {
    final appName = app.substring(0, 1).toUpperCase() + app.substring(1);
    return switch (severity) {
      'critical' => '🚨 CRITICAL: $appName Alert',
      'high' => '⚠️ High Risk: $appName',
      'medium' => '⚡ Medium Risk: $appName',
      _ => 'KOVA Alert: $appName',
    };
  }

  String _getAlertBody(String app, String severity, String content) {
    final preview = content.length > 50 ? '${content.substring(0, 50)}...' : content;
    return 'Potentially harmful content detected. Preview: "$preview"';
  }

  /// Normalize app name / package to internal key
  String _normalizeAppName(String app) {
    final lower = app.toLowerCase();
    // Messaging
    if (lower.contains('whatsapp') || lower == 'com.whatsapp.w4b') return 'whatsapp';
    if (lower.contains('com.facebook.orca') || lower.contains('com.facebook.mlite')) return 'messenger';
    if (lower.contains('com.facebook.katana') || lower == 'facebook') return 'facebook';
    if (lower.contains('instagram')) return 'instagram';
    if (lower.contains('tiktok') || lower.contains('musically') || lower.contains('ugc.trill')) return 'tiktok';
    if (lower.contains('telegram')) return 'telegram';
    if (lower.contains('snapchat')) return 'snapchat';
    if (lower.contains('signal') || lower.contains('securesms')) return 'signal';
    if (lower.contains('twitter')) return 'twitter';
    if (lower.contains('discord')) return 'discord';
    if (lower.contains('skype')) return 'skype';
    if (lower.contains('viber')) return 'viber';
    // Browsers
    if (lower.contains('chrome') || lower == 'com.android.chrome') return 'chrome';
    if (lower.contains('firefox') || lower.contains('mozilla') || lower.contains('fenix')) return 'firefox';
    if (lower.contains('brave')) return 'brave';
    if (lower.contains('opera')) return 'opera';
    if (lower.contains('edge') || lower.contains('emmx')) return 'edge';
    if (lower.contains('duckduckgo')) return 'duckduckgo';
    if (lower.contains('sbrowser') || lower.contains('samsung') && lower.contains('browser')) return 'samsung_browser';
    if (lower.contains('kiwi')) return 'kiwi';
    if (lower.contains('ucmobile') || lower.contains('ucbrowser')) return 'ucbrowser';
    // Search & Video
    if (lower.contains('youtube')) return 'youtube';
    if (lower.contains('googlequicksearchbox') || lower.contains('searchlite')) return 'google';
    // SMS
    if (lower.contains('sms') || lower.contains('messaging') || lower.contains('com.android.mms')) return 'sms';
    return lower;
  }

  // Legacy compatibility methods
  static Future<Map<String, dynamic>?> analyzeMessage({
    required String childId,
    required String app,
    required String messageText,
    required String? senderName,
    required List<String> attachedImagePaths,
  }) async {
    final tfLite = TfLiteAnalyzerService();
    if (!tfLite.isInitialized) await tfLite.init();
    final textScores = await tfLite.analyzeText(messageText);
    
    final detector = ContextDetector();
    detector.addMessage('${app}_$childId', messageText, sender: senderName);
    final contextResult = detector.analyze('${app}_$childId');
    
    final severity = SeverityEngine.calculate(
      textScores: textScores,
      contextScores: contextResult,
    );

    if (severity == 'safe') return null;

    return _buildAlertData(
      childId: childId,
      app: app,
      textScores: textScores,
      contextScores: contextResult,
      userReported: false,
    );
  }

  static Future<Map<String, dynamic>?> analyzeConversation({
    required String childId,
    required String app,
    required String senderName,
    required List<Map<String, dynamic>> messages,
    required String? metadata,
  }) async {
    final texts = messages.map((m) => m['text']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
    if (texts.isEmpty) return null;
    
    final tfLite = TfLiteAnalyzerService();
    if (!tfLite.isInitialized) await tfLite.init();
    final batchResult = await tfLite.analyzeBatch(texts);
    
    final detector = ContextDetector();
    
    for (final msg in messages) {
      detector.addMessage('${app}_$childId', msg['text']?.toString() ?? '');
    }
    
    final contextResult = detector.analyze('${app}_$childId');
    final severity = SeverityEngine.calculate(
      textScores: batchResult,
      contextScores: contextResult,
    );

    if (severity == 'safe') return null;

    return _buildAlertData(
      childId: childId,
      app: app,
      textScores: batchResult,
      contextScores: contextResult,
      userReported: false,
    );
  }

  static Map<String, dynamic> _buildAlertData({
    required String childId,
    required String app,
    required Map<String, dynamic> textScores,
    required Map<String, dynamic> contextScores,
    required bool userReported,
  }) {
    final severity = SeverityEngine.calculate(
      textScores: {
        'unsafe': (textScores['unsafe'] as num?)?.toDouble() ?? 0.0,
        'sexual': (textScores['sexual'] as num?)?.toDouble() ?? 0.0,
        'grooming': (textScores['grooming'] as num?)?.toDouble() ?? 0.0,
        'violence': (textScores['violence'] as num?)?.toDouble() ?? 0.0,
      },
      contextScores: contextScores,
    );

    final safetyScore = SeverityEngine.calculateSafetyScore(
      textConfidence: (textScores['unsafe'] as num?)?.toDouble() ?? 0.0,
      groomingConfidence: (contextScores['grooming_risk'] as num?)?.toDouble() ?? 0.0,
      imageConfidence: 0.0,
    );

    return {
      'childId': childId,
      'app': app,
      'severity': severity,
      'safetyScore': safetyScore,
      'scores': {
        'text': textScores['unsafe'] ?? 0.0,
        'grooming': contextScores['grooming_risk'] ?? 0.0,
        'image': 0.0,
      },
      'userReported': userReported,
      'requiresImmediateAction': severity == 'critical' || severity == 'high',
    };
  }

  /// User manually reports a conversation as harmful
  static Future<Map<String, dynamic>> analyzeUserReport({
    required String childId,
    required String app,
    required String senderName,
    required List<Map<String, dynamic>> messages,
    required String? userReportText,
  }) async {
    var alert = await analyzeConversation(
      childId: childId,
      app: app,
      senderName: senderName,
      messages: messages,
      metadata: userReportText,
    );

    alert ??= {
      'childId': childId,
      'app': app,
      'severity': 'high',
      'safetyScore': 30,
      'message': userReportText ?? 'User reported this conversation as harmful',
      'scores': {'text': 0.5, 'grooming': 0.5, 'image': 0.0},
      'userReported': true,
      'requiresImmediateAction': true,
    };

    alert['userReported'] = true;
    alert['requiresImmediateAction'] = true;
    if (alert['severity'] == 'low' || alert['severity'] == 'safe') {
      alert['severity'] = 'medium';
    }

    return alert;
  }

  /// Generate realistic test alert for demo purposes
  static Future<Map<String, dynamic>> generateTestAlert({
    required String childId,
    required String severity,
  }) async {
    final testMessages = [
      {'text': 'hey you look special today'},
      {'text': 'but dont tell your parents about our chats ok'},
      {'text': 'you seem so mature for your age'},
    ];

    final alert = await analyzeConversation(
      childId: childId,
      app: 'WhatsApp',
      senderName: 'TestSender',
      messages: testMessages,
      metadata: 'test_alert',
    );

    if (alert != null) {
      alert['severity'] = severity;
      alert['isTestAlert'] = true;
    }

    return alert ?? {
      'childId': childId,
      'app': 'WhatsApp',
      'severity': severity,
      'safetyScore': severity == 'high' ? 30 : 50,
      'message': 'Test alert for demo',
      'isTestAlert': true,
    };
  }
}
