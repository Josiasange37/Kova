// child/services/text_classifier.dart — Placeholder text content classifier
// Returns realistic confidence scores WITHOUT TFLite (real models come later)

class TextClassifier {
  /// Classify text content for harmful/grooming patterns
  /// Returns: {"risk": "low|medium|high", "confidence": 0.0-1.0, "keywords": [...]}
  ///
  /// Placeholder behavior:
  /// - Detects common harmful keywords
  /// - Returns confidence based on keyword count + context
  /// - Safe by default (returns "low" for clean text)
  static Future<Map<String, dynamic>> classify(String text) async {
    if (text.isEmpty) {
      return {
        'risk': 'low',
        'confidence': 0.0,
        'keywords': [],
        'reason': 'empty_text',
      };
    }

    // Placeholder keyword detection (case-insensitive)
    final lowerText = text.toLowerCase();

    // Harmful keywords map
    final riskKeywords = {
      'grooming': ['meet me', 'alone', 'secret', 'dont tell', 'private'],
      'abuse': ['hate', 'stupid', 'idiot', 'loser', 'worthless'],
      'adult_content': ['porn', 'sex', 'nude', 'xxx'],
    };

    final detectedKeywords = <String>[];
    var totalScore = 0.0;

    for (final category in riskKeywords.entries) {
      for (final keyword in category.value) {
        if (lowerText.contains(keyword)) {
          detectedKeywords.add(keyword);
          // Grooming scores higher
          totalScore += category.key == 'grooming' ? 0.4 : 0.2;
        }
      }
    }

    // Clamp confidence to 0.0-1.0
    final confidence = (totalScore).clamp(0.0, 1.0);

    // Determine risk level
    String risk;
    if (confidence < 0.2) {
      risk = 'low';
    } else if (confidence < 0.6) {
      risk = 'medium';
    } else {
      risk = 'high';
    }

    return {
      'risk': risk,
      'confidence': confidence,
      'keywords': detectedKeywords,
      'reason': 'keyword_detection',
      'model': 'placeholder_v1',
    };
  }

  /// Get risk assessment for multiple text messages
  static Future<Map<String, dynamic>> classifyBatch(List<String> texts) async {
    var maxConfidence = 0.0;
    var maxRisk = 'low';
    final allKeywords = <String>{};

    for (final text in texts) {
      final result = await classify(text);
      final confidence = (result['confidence'] as num).toDouble();

      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        maxRisk = result['risk'] as String;
      }

      if (result['keywords'] is List) {
        allKeywords.addAll(List<String>.from(result['keywords'] as List));
      }
    }

    return {
      'risk': maxRisk,
      'confidence': maxConfidence,
      'keywords': allKeywords.toList(),
      'message_count': texts.length,
      'model': 'placeholder_v1',
    };
  }
}
