// child/services/context_detector.dart — Detects grooming/abuse patterns in context
// Analyzes conversation flow, not just individual messages

class ContextDetector {
  /// Detect grooming patterns across conversation context
  /// Returns: {"pattern": "string", "confidence": 0.0-1.0, "steps": [...]}
  ///
  /// Placeholder behavior:
  /// - Detects common grooming sequence patterns
  /// - Tracks conversation escalation
  /// - Returns realistic confidence scores
  static Future<Map<String, dynamic>> detectGrooming(
    List<Map<String, dynamic>> messages,
  ) async {
    if (messages.isEmpty) {
      return {'detected': false, 'confidence': 0.0, 'pattern': 'none'};
    }

    // Placeholder grooming indicators:
    // 1. "Trust building" - compliments, special attention
    // 2. "Isolation" - requests to keep secret, go private
    // 3. "Desensitization" - gradual inappropriate content
    // 4. "Exploitation" - explicit requests

    final conversationText = messages
        .map((m) => (m['text'] ?? '').toString().toLowerCase())
        .join(' ');

    final trustBuildingWords = ['special', 'unique', 'beautiful', 'smart'];
    final isolationWords = [
      'secret',
      'dont tell',
      'private',
      'alone',
      'between us',
    ];
    final desensitizationWords = ['funny', 'interesting', 'trust', 'mature'];

    var score = 0.0;
    final detectedPhases = <String>[];

    // Check for trust building
    for (final word in trustBuildingWords) {
      if (conversationText.contains(word)) {
        score += 0.15;
        detectedPhases.add('trust_building');
        break;
      }
    }

    // Check for isolation attempts
    for (final word in isolationWords) {
      if (conversationText.contains(word)) {
        score += 0.35;
        detectedPhases.add('isolation');
        break;
      }
    }

    // Check for desensitization
    for (final word in desensitizationWords) {
      if (conversationText.contains(word)) {
        score += 0.25;
        detectedPhases.add('desensitization');
        break;
      }
    }

    final detected = score > 0.3;
    final confidence = score.clamp(0.0, 1.0);

    return {
      'detected': detected,
      'confidence': confidence,
      'pattern': detected ? 'potential_grooming' : 'none',
      'phases': detectedPhases,
      'risk_score': confidence,
      'message_count': messages.length,
      'model': 'placeholder_v1',
    };
  }

  /// Detect abuse/bullying patterns
  static Future<Map<String, dynamic>> detectAbuse(
    List<Map<String, dynamic>> messages,
  ) async {
    if (messages.isEmpty) {
      return {'detected': false, 'confidence': 0.0, 'pattern': 'none'};
    }

    final conversationText = messages
        .map((m) => (m['text'] ?? '').toString().toLowerCase())
        .join(' ');

    final abuseKeywords = [
      'hate',
      'stupid',
      'idiot',
      'loser',
      'worthless',
      'kill yourself',
      'die',
    ];

    var keywordCount = 0;
    for (final keyword in abuseKeywords) {
      if (conversationText.contains(keyword)) {
        keywordCount++;
      }
    }

    final confidence = (keywordCount * 0.25).clamp(0.0, 1.0);
    final detected = confidence > 0.4;

    return {
      'detected': detected,
      'confidence': confidence,
      'pattern': detected ? 'bullying_abuse' : 'none',
      'keyword_count': keywordCount,
      'severity': detected ? (confidence > 0.8 ? 'high' : 'medium') : 'low',
      'model': 'placeholder_v1',
    };
  }

  /// Analyze conversation velocity (rate of escalation)
  static Future<Map<String, dynamic>> analyzeVelocity(
    List<Map<String, dynamic>> messages,
  ) async {
    if (messages.length < 2) {
      return {'escalating': false, 'velocity_score': 0.0};
    }

    // Check if messages are getting more intense over time
    // Placeholder: Every 10th message represents a period
    final periods = (messages.length / 10).ceil();
    var escalationCount = 0;

    for (var i = 1; i < periods; i++) {
      // Simplified: if we detect keywords in later messages, it's escalating
      escalationCount++;
    }

    final velocityScore = (escalationCount / periods.toDouble()).clamp(
      0.0,
      1.0,
    );

    return {
      'escalating': velocityScore > 0.5,
      'velocity_score': velocityScore,
      'periods_analyzed': periods,
      'model': 'placeholder_v1',
    };
  }
}
