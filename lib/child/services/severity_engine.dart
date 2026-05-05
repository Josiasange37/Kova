// child/services/severity_engine.dart — Combines all detector scores into final severity

class SeverityEngine {
  /// Calculate severity from text and context scores
  /// Returns: 'safe', 'low', 'medium', 'high', 'critical'
  static String calculate({
    required Map<String, dynamic> textScores,
    required Map<String, dynamic> contextScores,
  }) {
    final unsafe = (textScores['unsafe'] as num?)?.toDouble() ?? 0.0;
    final sexual = (textScores['sexual'] as num?)?.toDouble() ?? 0.0;
    final grooming = (textScores['grooming'] as num?)?.toDouble() ?? 0.0;
    final violence = (textScores['violence'] as num?)?.toDouble() ?? 0.0;
    final unsafeSubstances = (textScores['unsafe_substances'] as num?)?.toDouble() ?? 0.0;
    final personalInfo = (textScores['personal_info'] as num?)?.toDouble() ?? 0.0;
    final ctxRisk = (contextScores['grooming_risk'] as num?)?.toDouble() ?? 0.0;
    final escalation = contextScores['escalation'] as bool? ?? false;

    // CRITICAL (stricter)
    if (sexual > 0.4 ||
        grooming > 0.5 ||
        violence > 0.5 ||
        unsafe > 0.6 ||
        ctxRisk > 0.6 ||
        (escalation && ctxRisk > 0.4)) {
      return 'critical';
    }

    // HIGH (stricter)
    if (sexual > 0.2 ||
        grooming > 0.3 ||
        violence > 0.3 ||
        unsafeSubstances > 0.4 ||
        personalInfo > 0.5 ||
        ctxRisk > 0.3 ||
        unsafe > 0.4) {
      return 'high';
    }

    // MEDIUM
    if (grooming > 0.15 ||
        violence > 0.15 ||
        unsafeSubstances > 0.2 ||
        personalInfo > 0.3 ||
        ctxRisk > 0.2 ||
        unsafe > 0.25) {
      return 'medium';
    }

    // LOW
    if (unsafe > 0.1 || ctxRisk > 0.1) {
      return 'low';
    }

    return 'safe';
  }

  /// Get alert type from scores
  static String getType({
    required Map<String, dynamic> textScores,
    required Map<String, dynamic> contextScores,
  }) {
    final sexual = (textScores['sexual'] as num?)?.toDouble() ?? 0.0;
    final grooming = (textScores['grooming'] as num?)?.toDouble() ?? 0.0;
    final violence = (textScores['violence'] as num?)?.toDouble() ?? 0.0;
    final ctxRisk = (contextScores['grooming_risk'] as num?)?.toDouble() ?? 0.0;

    if (ctxRisk > 0.4) return 'grooming';
    if (sexual > 0.3) return 'nsfw_text';
    if (violence > 0.3) return 'violence_text';
    if (grooming > 0.2) return 'grooming_attempt';
    return 'unsafe_content';
  }

  /// Get score delta based on severity
  static int scoreDelta(String severity) {
    return switch (severity) {
      'critical' => -20,
      'high' => -10,
      'medium' => -5,
      'low' => -2,
      _ => 0,
    };
  }

  /// Calculate final safety score (0-100) from all classifiers
  /// 100 = completely safe, 0 = critical threat
  ///
  /// Algorithm:
  /// 1. Get text confidence (0-1)
  /// 2. Get image confidence (0-1)
  /// 3. Get grooming confidence (0-1)
  /// 4. Weight by importance: text=40%, grooming=50%, image=10%
  /// 5. Convert to 0-100 scale
  static int calculateSafetyScore({
    required double textConfidence,
    required double groomingConfidence,
    required double imageConfidence,
  }) {
    // Weighted combination (higher confidence = lower safety)
    final weighted =
        (textConfidence * 0.40) +
        (groomingConfidence * 0.50) +
        (imageConfidence * 0.10);

    // Convert threat score to safety score (inverse)
    final safetyScore = 100 - (weighted * 100).round();

    return safetyScore.clamp(0, 100);
  }

  /// Determine severity level from combined analysis
  static String determineSeverity({
    required double textConfidence,
    required double groomingConfidence,
    required double imageConfidence,
    required bool userReportedHarmful,
  }) {
    final weighted =
        (textConfidence * 0.40) +
        (groomingConfidence * 0.50) +
        (imageConfidence * 0.10);

    // If user reported it, escalate
    var confidence = weighted;
    if (userReportedHarmful) {
      confidence = (confidence + 0.3).clamp(0.0, 1.0);
    }

    // Map confidence to severity
    if (confidence >= 0.8) {
      return 'critical';
    } else if (confidence >= 0.6) {
      return 'high';
    } else if (confidence >= 0.4) {
      return 'medium';
    } else if (confidence >= 0.2) {
      return 'low';
    } else {
      return 'safe';
    }
  }

  /// Generate alert message based on detected threats
  static String generateAlertMessage({
    required String severity,
    required List<String> detectedGroomingPhases,
    required List<String> detectedKeywords,
    required bool imageHarmful,
  }) {
    switch (severity) {
      case 'critical':
        if (detectedKeywords.contains('suicide') || detectedKeywords.contains('self-harm')) {
          return 'Severe self-harm threat detected. URGENT ACTION RECOMMENDED.';
        } else if (detectedGroomingPhases.isNotEmpty) {
          return 'Potential predatory grooming detected. Pattern: ${detectedGroomingPhases.join(", ")}. URGENT ACTION RECOMMENDED.';
        } else if (detectedKeywords.isNotEmpty) {
          return 'Severe harmful content detected. Keywords: ${detectedKeywords.take(3).join(", ")}. URGENT ACTION RECOMMENDED.';
        }
        return 'Critical threat detected. Immediate parent notification recommended.';

      case 'high':
        if (detectedGroomingPhases.isNotEmpty) {
          return 'Concerning conversation pattern detected: ${detectedGroomingPhases.first}. Monitor closely.';
        } else if (detectedKeywords.isNotEmpty) {
          return 'Harmful content detected: ${detectedKeywords.first}. Parent review recommended.';
        }
        return 'High-risk content detected.';

      case 'medium':
        if (imageHarmful) {
          return 'Potentially inappropriate image shared. Review recommended.';
        }
        return 'Moderate-risk content detected. Monitor.';

      case 'low':
        return 'Low-risk content. Standard monitoring.';

      default:
        return 'Content appears safe.';
    }
  }

  /// Build alert with all detection details
  static Future<Map<String, dynamic>> buildAlertData({
    required String childId,
    required String app,
    required double textConfidence,
    required double groomingConfidence,
    required double imageConfidence,
    required List<String> detectedKeywords,
    required List<String> detectedGroomingPhases,
    required bool userReported,
  }) async {
    final severity = determineSeverity(
      textConfidence: textConfidence,
      groomingConfidence: groomingConfidence,
      imageConfidence: imageConfidence,
      userReportedHarmful: userReported,
    );

    final safetyScore = calculateSafetyScore(
      textConfidence: textConfidence,
      groomingConfidence: groomingConfidence,
      imageConfidence: imageConfidence,
    );

    final message = generateAlertMessage(
      severity: severity,
      detectedGroomingPhases: detectedGroomingPhases,
      detectedKeywords: detectedKeywords,
      imageHarmful: imageConfidence > 0.5,
    );

    return {
      'childId': childId,
      'app': app,
      'severity': severity,
      'safetyScore': safetyScore,
      'message': message,
      'scores': {
        'text': textConfidence,
        'grooming': groomingConfidence,
        'image': imageConfidence,
      },
      'detectedKeywords': detectedKeywords,
      'detectedGroomingPhases': detectedGroomingPhases,
      'userReported': userReported,
      'timestamp': DateTime.now().toIso8601String(),
      'requiresImmediateAction': severity == 'critical' || severity == 'high',
    };
  }

  /// Trend analysis: Is safety score improving or declining?
  static String analyzeTrend(List<int> historicalScores) {
    if (historicalScores.isEmpty) return 'no_data';
    if (historicalScores.length < 3) return 'insufficient_data';

    // Compare last 3 scores to previous 3
    final recent = historicalScores.sublist(historicalScores.length - 3);
    final previous = historicalScores.sublist(
      historicalScores.length - 6,
      historicalScores.length - 3,
    );

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final previousAvg = previous.reduce((a, b) => a + b) / previous.length;

    if (recentAvg > previousAvg + 10) {
      return 'improving';
    } else if (recentAvg < previousAvg - 10) {
      return 'declining';
    } else {
      return 'stable';
    }
  }
}
