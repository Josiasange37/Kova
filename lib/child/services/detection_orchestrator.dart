// child/services/detection_orchestrator.dart — Master coordinator for all detection services
// Real implementation using TextAnalyzer, ContextDetector, SeverityEngine

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/network_sync_service.dart';
import 'package:kova/shared/services/notification_service.dart';
import 'package:kova/shared/services/local_storage.dart';

import 'text_analyzer.dart';
import 'context_detector.dart';
import 'severity_engine.dart';
import 'monitoring_bridge.dart';

/// Master service that coordinates all detection and alerting
/// Only active when mode == AppMode.child
class DetectionOrchestrator {
  static final DetectionOrchestrator instance = DetectionOrchestrator._internal();
  DetectionOrchestrator._internal();

  final ChildRepository _childRepo = ChildRepository();
  final AlertRepository _alertRepo = AlertRepository();
  final NetworkSyncService _networkSync = NetworkSyncService();
  final ContextDetector _contextDetector = ContextDetector();
  
  bool _active = false;
  String? _childId;

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

    // Set up bridge callbacks for all 3 channels
    MonitoringBridge.onContent = _processContent;
    MonitoringBridge.onConversation = _processConversation;
    MonitoringBridge.onMetadata = _processMetadata;
    
    // Initialize bridge (registers handlers on 3 channels)
    MonitoringBridge.init();

    if (kDebugMode) debugPrint('🛡️ KOVA Detection Orchestrator: ACTIVE');
  }

  /// Stop detection services
  void stop() {
    _active = false;
    MonitoringBridge.reset();
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

    // Analyze text
    final textScores = TextAnalyzer.analyze(text);
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

    // Show notification
    await _showAlertNotification(appKey, severity, alertId, text);

    // Push alert to parent via network (LAN full data or Vercel summary)
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

    // Batch analyze
    final batchResult = TextAnalyzer.analyzeBatch(texts);
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
  /// Tracks which apps the child navigates to
  void _processMetadata(
    String event,
    String app,
    Map<String, dynamic> data,
  ) {
    if (!_active) return;

    // Track app navigation for context correlation
    if (event == 'window_changed' && data['isMonitored'] == true) {
      final windowType = data['windowType'] as String? ?? 'other';
      if (kDebugMode) {
        debugPrint('🪟 Child navigated to $app ($windowType)');
      }
    }
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

      await _networkSync.pushAlert(alert);

      if (kDebugMode) debugPrint('📤 Alert pushed to parent network');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Network push failed (local alert saved): $e');
    }
  }

  /// Block an app using native blocker
  Future<void> _blockApp(String app) async {
    const channel = MethodChannel('com.kova.child/blocker');
    
    final pkgMap = {
      'whatsapp': 'com.whatsapp',
      'whatsapp_business': 'com.whatsapp.w4b',
      'facebook': 'com.facebook.katana',
      'messenger': 'com.facebook.orca',
      'tiktok': 'com.zhiliaoapp.musically',
      'instagram': 'com.instagram.android',
      'telegram': 'org.telegram.messenger',
      'sms': 'com.google.android.apps.messaging',
    };

    final pkg = pkgMap[app];
    if (pkg == null) return;

    try {
      await channel.invokeMethod('blockApp', {'pkg': pkg});
      if (kDebugMode) debugPrint('🚫 App blocked: $app');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to block app: $e');
    }
  }

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

  /// Normalize app name to internal key
  String _normalizeAppName(String app) {
    final lower = app.toLowerCase();
    if (lower.contains('whatsapp')) return 'whatsapp';
    if (lower.contains('facebook')) return 'facebook';
    if (lower.contains('instagram')) return 'instagram';
    if (lower.contains('tiktok')) return 'tiktok';
    if (lower.contains('telegram')) return 'telegram';
    if (lower.contains('snapchat')) return 'snapchat';
    if (lower.contains('sms') || lower.contains('messaging')) return 'sms';
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
    final textScores = TextAnalyzer.analyze(messageText);
    
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
    
    final batchResult = TextAnalyzer.analyzeBatch(texts);
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
