// child/services/detection_orchestrator.dart — Master coordinator for all detection services
// Orchestrates: TextClassifier, ImageClassifier, ContextDetector, SeverityEngine

import 'package:uuid/uuid.dart';
import 'text_classifier.dart';
import 'image_classifier.dart';
import 'context_detector.dart';
import 'severity_engine.dart';

class DetectionOrchestrator {
  static const _uuid = Uuid();

  /// Analyze a single message from WhatsApp/messaging app
  /// Returns complete alert data if harmful content detected
  static Future<Map<String, dynamic>?> analyzeMessage({
    required String childId,
    required String app,
    required String messageText,
    required String? senderName,
    required List<String> attachedImagePaths,
  }) async {
    // Step 1: Classify text
    final textResult = await TextClassifier.classify(messageText);
    final textConfidence = (textResult['confidence'] as num).toDouble();

    // Step 2: Classify images (if any)
    double imageConfidence = 0.0;
    for (final imagePath in attachedImagePaths) {
      if (ImageClassifier.shouldAnalyze(imagePath)) {
        final imageResult = await ImageClassifier.classify(imagePath);
        final imgConfidence = (imageResult['confidence'] as num).toDouble();
        imageConfidence = (imageConfidence + imgConfidence) / 2;
      }
    }

    // Step 3: Detect grooming/abuse in single message
    final abuseResult = await ContextDetector.detectAbuse([
      {'text': messageText, 'sender': senderName},
    ]);
    final abuseConfidence = (abuseResult['confidence'] as num).toDouble();

    // For single message, use text + abuse score as grooming indicator
    final groomingConfidence = (textConfidence + abuseConfidence) / 2;

    // Step 4: Calculate severity
    final severity = SeverityEngine.determineSeverity(
      textConfidence: textConfidence,
      groomingConfidence: groomingConfidence,
      imageConfidence: imageConfidence,
      userReportedHarmful: false,
    );

    // Only create alert if severity is medium or higher
    if (severity == 'safe' || severity == 'low') {
      return null;
    }

    // Step 5: Build alert data
    final detectedKeywords = List<String>.from(
      textResult['keywords'] as List? ?? [],
    );

    final alert = await SeverityEngine.buildAlertData(
      childId: childId,
      app: app,
      textConfidence: textConfidence,
      groomingConfidence: groomingConfidence,
      imageConfidence: imageConfidence,
      detectedKeywords: detectedKeywords,
      detectedGroomingPhases: (abuseResult['keyword_count'] as int? ?? 0) > 0
          ? ['abuse_detected']
          : [],
      userReported: false,
    );

    return alert;
  }

  /// Analyze entire conversation thread
  /// More powerful than single message - detects grooming progression
  static Future<Map<String, dynamic>?> analyzeConversation({
    required String childId,
    required String app,
    required String senderName,
    required List<Map<String, dynamic>> messages, // [{text, imageCount}, ...]
    required String? metadata,
  }) async {
    if (messages.isEmpty) return null;

    // Step 1: Analyze text from all messages
    final messageTexts = messages
        .map((m) => (m['text'] ?? '') as String)
        .where((t) => t.isNotEmpty)
        .toList();

    final textBatchResult = await TextClassifier.classifyBatch(messageTexts);
    final textConfidence = (textBatchResult['confidence'] as num).toDouble();

    // Step 2: Detect grooming patterns across conversation
    final groomingResult = await ContextDetector.detectGrooming(messages);
    final groomingConfidence = (groomingResult['confidence'] as num).toDouble();

    // Step 3: Analyze abuse patterns
    final abuseResult = await ContextDetector.detectAbuse(messages);
    final abuseConfidence = (abuseResult['confidence'] as num).toDouble();

    // Step 4: Check conversation velocity
    final velocityResult = await ContextDetector.analyzeVelocity(messages);
    final isEscalating = velocityResult['escalating'] as bool? ?? false;

    // Boost grooming confidence if conversation is escalating
    var finalGroomingConfidence = groomingConfidence;
    if (isEscalating && groomingResult['detected'] == true) {
      finalGroomingConfidence = (finalGroomingConfidence + 0.2).clamp(0.0, 1.0);
    }

    // Step 5: Image analysis (if messages contain images)
    double imageConfidence = 0.0;
    var totalImageCount = 0;
    for (final msg in messages) {
      totalImageCount += (msg['imageCount'] as int? ?? 0);
    }
    // For now, assume images are handled separately
    // Real implementation would fetch and analyze actual images

    // Step 6: Determine final severity
    final severity = SeverityEngine.determineSeverity(
      textConfidence: textConfidence,
      groomingConfidence: finalGroomingConfidence,
      imageConfidence: imageConfidence,
      userReportedHarmful: false,
    );

    // Only create alert if severity is medium or higher
    if (severity == 'safe' || severity == 'low') {
      return null;
    }

    // Step 7: Extract detected phases and keywords
    final detectedPhases = List<String>.from(
      groomingResult['phases'] as List? ?? [],
    );
    if (abuseResult['detected'] == true) {
      detectedPhases.add('abuse_detected');
    }

    final detectedKeywords = List<String>.from(
      textBatchResult['keywords'] as List? ?? [],
    );

    // Step 8: Build comprehensive alert
    final alert = await SeverityEngine.buildAlertData(
      childId: childId,
      app: app,
      textConfidence: textConfidence,
      groomingConfidence: finalGroomingConfidence,
      imageConfidence: imageConfidence,
      detectedKeywords: detectedKeywords,
      detectedGroomingPhases: detectedPhases,
      userReported: false,
    );

    // Add conversation context
    alert['conversationMetadata'] = {
      'senderName': senderName,
      'messageCount': messages.length,
      'isEscalating': isEscalating,
      'span': messages.length > 0 ? 'multi_message' : 'single_message',
    };

    return alert;
  }

  /// User manually reports a conversation as harmful
  /// Escalates confidence scores
  static Future<Map<String, dynamic>> analyzeUserReport({
    required String childId,
    required String app,
    required String senderName,
    required List<Map<String, dynamic>> messages,
    required String? userReportText,
  }) async {
    // Run normal analysis first
    var alert = await analyzeConversation(
      childId: childId,
      app: app,
      senderName: senderName,
      messages: messages,
      metadata: userReportText,
    );

    // If analysis found nothing, create alert anyway (user knows best)
    alert ??= {
      'childId': childId,
      'app': app,
      'severity': 'high', // Escalate user reports
      'safetyScore': 30,
      'message': userReportText ?? 'User reported this conversation as harmful',
      'scores': {'text': 0.5, 'grooming': 0.5, 'image': 0.0},
      'userReported': true,
      'requiresImmediateAction': true,
    };

    // Mark as user reported and ensure high priority
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
    const testMessages = [
      {'text': 'hey you look special today'},
      {'text': 'but dont tell your parents about our chats ok'},
      {'text': 'you seem so mature for your age'},
    ];

    // Return test alert with requested severity
    final alert = await analyzeConversation(
      childId: childId,
      app: 'WhatsApp',
      senderName: 'TestSender',
      messages: testMessages,
      metadata: 'test_alert',
    );

    // Force severity if needed
    if (alert != null) {
      alert['severity'] = severity;
      alert['isTestAlert'] = true;
    }

    return alert ??
        {
          'childId': childId,
          'app': 'WhatsApp',
          'severity': severity,
          'safetyScore': severity == 'high' ? 30 : 50,
          'message': 'Test alert for demo',
          'isTestAlert': true,
        };
  }
}
