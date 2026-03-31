// child/services/monitoring_bridge.dart — Receives data from Kotlin services via MethodChannel
// Bridges native Android monitoring to Flutter detection engine

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Callback type for content received from monitoring services
typedef ContentCallback = void Function(
  String app,
  String text,
  String source,
  String conversationId,
  String? senderName,
);

/// Bridge that receives messages from native Android monitoring services
/// - KovaNotificationListener.kt (background notifications)
/// - KovaAccessibilityService.kt (foreground screen content)
class MonitoringBridge {
  // MethodChannel names must match Kotlin side
  static const MethodChannel _notificationChannel = MethodChannel(
    'com.kova.app/accessibility',
  );

  static Function(String app, String text, String source, String conversationId, String? senderName)? onContent;
  static Function(String app, List<Map<String, dynamic>> messages, String? senderName)? onConversation;

  static bool _initialized = false;

  /// Initialize the bridge and set up method call handlers
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _notificationChannel.setMethodCallHandler(_handleMethodCall);
    
    if (kDebugMode) {
      debugPrint('📡 MonitoringBridge initialized');
    }
  }

  /// Handle incoming method calls from Kotlin
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (kDebugMode) {
      debugPrint('📨 MonitoringBridge received: ${call.method}');
    }

    switch (call.method) {
      case 'onMessage':
        _handleMessage(call.arguments);
        break;
      case 'onConversation':
        _handleConversation(call.arguments);
        break;
      default:
        if (kDebugMode) {
          debugPrint('⚠️ Unknown method: ${call.method}');
        }
    }
    return null;
  }

  /// Handle single message from notification or accessibility
  static void _handleMessage(dynamic arguments) {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);
      
      final app = args['app'] as String? ?? 'unknown';
      final text = args['messageText'] as String? ?? '';
      final senderName = args['senderName'] as String?;
      final source = _determineSource(args);
      final conversationId = _extractConversationId(args, app);

      if (text.isEmpty) return;

      if (kDebugMode) {
        debugPrint('📩 Message from $app: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      }

      onContent?.call(app, text, source, conversationId, senderName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling message: $e');
      }
    }
  }

  /// Handle conversation batch from accessibility service
  static void _handleConversation(dynamic arguments) {
    try {
      final args = Map<String, dynamic>.from(arguments as Map);
      
      final app = args['app'] as String? ?? 'unknown';
      final senderName = args['senderName'] as String?;
      final messagesRaw = args['messages'] as List<dynamic>? ?? [];
      
      final messages = messagesRaw.map((m) {
        if (m is Map) {
          return Map<String, dynamic>.from(m);
        }
        return <String, dynamic>{};
      }).toList();

      if (messages.isEmpty) return;

      if (kDebugMode) {
        debugPrint('📨 Conversation from $app: ${messages.length} messages');
      }

      onConversation?.call(app, messages, senderName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling conversation: $e');
      }
    }
  }

  /// Determine message source based on arguments
  static String _determineSource(Map<String, dynamic> args) {
    // Check if it's from notification listener
    if (args.containsKey('source')) {
      return args['source'] as String;
    }
    return 'accessibility'; // Default
  }

  /// Extract or generate conversation ID
  static String _extractConversationId(Map<String, dynamic> args, String app) {
    // Use sender name + app as conversation identifier
    final sender = args['senderName'] as String? ?? 'unknown';
    return '${app}_$sender';
  }

  /// Request accessibility service status check
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _notificationChannel.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking accessibility: $e');
      }
      return false;
    }
  }

  /// Open accessibility settings
  static Future<void> openAccessibilitySettings() async {
    try {
      await _notificationChannel.invokeMethod('openSettings');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error opening settings: $e');
      }
    }
  }

  /// Check notification listener status
  static Future<bool> isNotificationListenerEnabled() async {
    try {
      const channel = MethodChannel('com.kova.child/setup');
      final result = await channel.invokeMethod<bool>('isNotificationListenerEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Reset the bridge
  static void reset() {
    _initialized = false;
    onContent = null;
    onConversation = null;
  }
}
