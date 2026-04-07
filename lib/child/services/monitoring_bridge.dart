// child/services/monitoring_bridge.dart — MODULE 4
// Receives data from THREE native Kotlin services via MethodChannel.
// Tags each message with direction for the detection engine.

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Callback for single content items (text messages)
typedef ContentCallback = void Function(
  String app,
  String text,
  String source,
  String direction,
  String conversationId,
  String? senderName,
);

/// Callback for metadata events from AccessibilityService
typedef MetadataCallback = void Function(
  String event,
  String app,
  Map<String, dynamic> data,
);

/// Bridge that receives messages from three native Android services:
///
/// Channel 1: 'com.kova.child/notifications'
///   → Incoming messages captured from notification bar
///   → direction = 'incoming'
///
/// Channel 2: 'com.kova.child/keyboard'
///   → Outgoing text captured from custom IME
///   → direction = 'outgoing'
///
/// Channel 3: 'com.kova.child/accessibility'
///   → Metadata only (app switches, window changes, screen state)
///   → No message content (FLAG_SECURE safe)
///
class MonitoringBridge {
  // ── Three distinct channels ──
  static const MethodChannel _notificationsChannel = MethodChannel(
    'com.kova.child/notifications',
  );
  static const MethodChannel _keyboardChannel = MethodChannel(
    'com.kova.child/keyboard',
  );
  static const MethodChannel _accessibilityChannel = MethodChannel(
    'com.kova.child/accessibility',
  );

  // ── Callbacks ──
  static ContentCallback? onContent;
  static Function(
    String app,
    List<Map<String, dynamic>> messages,
    String? senderName,
  )? onConversation;
  static MetadataCallback? onMetadata;

  static bool _initialized = false;

  /// Initialize the bridge and set up handlers on all three channels
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _notificationsChannel.setMethodCallHandler(_handleNotification);
    _keyboardChannel.setMethodCallHandler(_handleKeyboard);
    _accessibilityChannel.setMethodCallHandler(_handleAccessibility);

    if (kDebugMode) {
      debugPrint('📡 MonitoringBridge initialized — 3 channels active');
    }
  }

  // ─────────────────────────────────────────────
  // Channel 1 — Notifications (INCOMING messages)
  // ─────────────────────────────────────────────

  static Future<dynamic> _handleNotification(MethodCall call) async {
    if (call.method == 'onData') {
      _processNotificationData(call.arguments);
    }
    return null;
  }

  static void _processNotificationData(dynamic arguments) {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);

      final app = args['app'] as String? ?? 'unknown';
      final text = args['text'] as String? ?? '';
      final senderName = args['senderName'] as String?;
      final conversationId = args['conversationId'] as String? ??
          '${app}_${senderName ?? 'unknown'}';

      if (text.isEmpty) return;

      if (kDebugMode) {
        final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
        debugPrint('📩 [INCOMING] $app → $preview');
      }

      // Tag as incoming — these are received messages
      onContent?.call(
        app,
        text,
        'notification',   // source
        'incoming',       // direction
        conversationId,
        senderName,
      );

      // If there are message lines, process each individually
      final messageLines = args['messageLines'];
      if (messageLines is List && messageLines.length > 1) {
        for (final line in messageLines) {
          final lineText = line?.toString() ?? '';
          if (lineText.isNotEmpty && lineText != text) {
            onContent?.call(
              app,
              lineText,
              'notification',
              'incoming',
              conversationId,
              senderName,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error in notification handler: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Channel 2 — Keyboard (OUTGOING messages)
  // ─────────────────────────────────────────────

  static Future<dynamic> _handleKeyboard(MethodCall call) async {
    if (call.method == 'onData') {
      _processKeyboardData(call.arguments);
    }
    return null;
  }

  static void _processKeyboardData(dynamic arguments) {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);

      final app = args['app'] as String? ?? 'unknown';
      final text = args['text'] as String? ?? '';
      final trigger = args['trigger'] as String? ?? 'unknown';
      final conversationId = args['conversationId'] as String? ??
          '${app}_keyboard';

      if (text.isEmpty) return;

      if (kDebugMode) {
        final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
        debugPrint('📤 [OUTGOING] $app ($trigger) → $preview');
      }

      // Tag as outgoing — this is what the child typed
      onContent?.call(
        app,
        text,
        'keyboard',       // source
        'outgoing',       // direction
        conversationId,
        null,             // no sender name for own text
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error in keyboard handler: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Channel 3 — Accessibility (METADATA only)
  // ─────────────────────────────────────────────

  static Future<dynamic> _handleAccessibility(MethodCall call) async {
    if (call.method == 'onData') {
      _processAccessibilityData(call.arguments);
    }
    return null;
  }

  static void _processAccessibilityData(dynamic arguments) {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);

      final event = args['event'] as String? ?? 'unknown';
      final app = args['app'] as String? ?? 'unknown';

      if (kDebugMode) {
        debugPrint('🔍 [META] $event → $app');
      }

      onMetadata?.call(event, app, args);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error in accessibility handler: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Utility methods
  // ─────────────────────────────────────────────

  /// Request accessibility service status check
  static Future<bool> isAccessibilityEnabled() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      final result = await channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking accessibility: $e');
      return false;
    }
  }

  /// Open accessibility settings
  static Future<void> openAccessibilitySettings() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      await channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error opening settings: $e');
    }
  }

  /// Check notification listener status
  static Future<bool> isNotificationListenerEnabled() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      final result = await channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if keyboard (IME) is active
  static Future<bool> isKeyboardEnabled() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      final result = await channel.invokeMethod<bool>('isKeyboardEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open input method settings to enable the KOVA keyboard
  static Future<void> openInputMethodSettings() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      await channel.invokeMethod('openInputMethodSettings');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error opening IME settings: $e');
    }
  }

  /// Reset the bridge
  static void reset() {
    _initialized = false;
    onContent = null;
    onConversation = null;
    onMetadata = null;
  }
}
