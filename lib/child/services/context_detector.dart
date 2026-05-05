// child/services/context_detector.dart — Detects grooming/abuse patterns in conversation context
// Analyzes conversation flow, not just individual messages

import 'package:flutter/foundation.dart';

/// Detects grooming patterns by analyzing conversation history
class ContextDetector {
  // Conversation history: conversationId -> list of messages
  final Map<String, List<Map<String, dynamic>>> _history = {};
  
  // Maximum messages to keep per conversation
  static const int _maxHistorySize = 50;

  /// Add a message to conversation history
  void addMessage(String conversationId, String text, {String? sender}) {
    final msgs = _history[conversationId] ?? [];
    msgs.add({
      'text': text.toLowerCase(),
      'sender': sender ?? 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Keep only recent messages
    if (msgs.length > _maxHistorySize) {
      msgs.removeAt(0);
    }
    
    _history[conversationId] = msgs;
    _cleanupStaleConversations();
  }

  void _cleanupStaleConversations() {
    if (_history.length > 200) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _history.removeWhere((key, msgs) {
        if (msgs.isEmpty) return true;
        final lastMsgTime = msgs.last['timestamp'] as int;
        return (now - lastMsgTime) > (24 * 60 * 60 * 1000); // 24 hours
      });
      
      if (_history.length > 300) {
        final sortedKeys = _history.keys.toList()
          ..sort((a, b) {
            final timeA = _history[a]!.last['timestamp'] as int;
            final timeB = _history[b]!.last['timestamp'] as int;
            return timeA.compareTo(timeB);
          });
        for (var i = 0; i < sortedKeys.length - 200; i++) {
          _history.remove(sortedKeys[i]);
        }
      }
    }
  }

  /// Analyze a conversation for grooming patterns
  /// Returns risk score and detected patterns
  Map<String, dynamic> analyze(String conversationId) {
    final msgs = _history[conversationId] ?? [];
    if (msgs.isEmpty) {
      return {
        'grooming_risk': 0.0,
        'escalation': false,
        'pattern': 'none',
        'indicators': <String>[],
        'conversation_age_hours': 0,
        'detected': false,
        'confidence': 0.0,
      };
    }

    final fullText = msgs.map((m) => m['text'] as String).join(' ');
    final indicators = <String>[];
    double risk = 0.0;

    // Pattern 1: Photo request + Secrecy = High grooming risk
    final hasPhotoRequest = _hasPhotoRequest(fullText);
    final hasSecrecy = _hasSecrecy(fullText);
    final hasIsolation = _hasIsolation(fullText);
    final hasMeeting = _hasMeetingRequest(fullText);
    final hasTrustBuilding = _hasTrustBuilding(fullText);
    final hasPersonalInfo = _hasPersonalInfoRequest(fullText);

    if (hasPhotoRequest) {
      risk += 0.25;
      indicators.add('photo_request');
    }
    if (hasSecrecy) {
      risk += 0.35;
      indicators.add('secrecy_request');
    }
    if (hasIsolation) {
      risk += 0.20;
      indicators.add('isolation_tactic');
    }
    if (hasMeeting) {
      risk += 0.30;
      indicators.add('meeting_request');
    }
    if (hasTrustBuilding) {
      risk += 0.15;
      indicators.add('trust_building');
    }
    if (hasPersonalInfo) {
      risk += 0.20;
      indicators.add('personal_info_request');
    }

    // Pattern 2: Combination detection (most dangerous)
    String pattern = 'none';
    
    if (hasPhotoRequest && hasSecrecy) {
      risk += 0.35; // Critical combination
      pattern = 'grooming_photo_secrecy';
      indicators.add('CRITICAL_COMBO: photo + secrecy');
    } else if (hasSecrecy && hasMeeting) {
      risk += 0.30;
      pattern = 'grooming_secrecy_meeting';
      indicators.add('HIGH_RISK: secrecy + meeting');
    } else if (hasPhotoRequest && hasMeeting) {
      risk += 0.25;
      pattern = 'photo_meeting';
      indicators.add('HIGH_RISK: photo + meeting');
    } else if (hasSecrecy && hasIsolation) {
      risk += 0.25;
      pattern = 'isolation_grooming';
      indicators.add('isolation_secrecy_pattern');
    } else if (hasPhotoRequest) {
      pattern = 'photo_request';
    } else if (hasSecrecy) {
      pattern = 'secrecy_pattern';
    }

    // Pattern 3: Escalation detection over time
    bool escalation = false;
    if (msgs.length >= 6) {
      final midPoint = msgs.length ~/ 2;
      final earlyMessages = msgs.sublist(0, midPoint);
      final recentMessages = msgs.sublist(midPoint);
      
      final earlyRisk = _calculateMessageRisk(earlyMessages);
      final recentRisk = _calculateMessageRisk(recentMessages);
      
      // Escalation = recent messages significantly more risky
      if (recentRisk > earlyRisk + 0.25) {
        escalation = true;
        risk += 0.15;
        indicators.add('escalation_detected');
      }
    }

    // Pattern 4: Message frequency analysis (rapid conversation)
    if (msgs.length >= 10) {
      final firstMsg = msgs.first['timestamp'] as int;
      final lastMsg = msgs.last['timestamp'] as int;
      final durationMinutes = (lastMsg - firstMsg) / (1000 * 60);
      
      // Many messages in short time = potential grooming intensity
      if (durationMinutes > 0 && msgs.length / durationMinutes > 5) {
        risk += 0.10;
        indicators.add('high_frequency_chat');
      }
    }

    // Calculate conversation age
    final firstMsg = msgs.first['timestamp'] as int;
    final ageHours = (DateTime.now().millisecondsSinceEpoch - firstMsg) / (1000 * 60 * 60);

    final finalRisk = risk.clamp(0.0, 1.0);
    final detected = finalRisk > 0.3;

    if (kDebugMode && finalRisk > 0.3) {
      debugPrint('🚨 ContextDetector: grooming_risk=${finalRisk.toStringAsFixed(2)}, pattern=$pattern, indicators=$indicators');
    }

    return {
      'grooming_risk': finalRisk,
      'escalation': escalation,
      'pattern': pattern,
      'indicators': indicators,
      'conversation_age_hours': ageHours,
      'message_count': msgs.length,
      'detected': detected,
      'confidence': finalRisk,
      'phases': indicators,
    };
  }

  // Helper methods for pattern detection
  bool _hasPhotoRequest(String text) {
    final keywords = [
      'photo', 'pic', 'picture', 'image', 'selfie', 'nude', 'naked',
      'envoie', 'montre', 'send', 'show me', 'send me',
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _hasSecrecy(String text) {
    final keywords = [
      'secret', 'dis rien', 'ne dis pas', 'personne ne',
      "don't tell", 'dont tell', 'no one', 'between us',
      'juste nous', 'entre nous', 'notre secret', 'our secret',
      'privé', 'private', 'confidentiel', 'confidential',
      'ne le dis à personne', "don't say anything",
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _hasIsolation(String text) {
    final keywords = [
      'juste nous', 'just us', 'seuls', 'alone',
      'tes parents', 'your parents', 'ta mère', 'your mom',
      'ton père', 'your dad', 'ils ne comprennent pas',
      "they don't understand", 'contre eux', 'against them',
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _hasMeetingRequest(String text) {
    final keywords = [
      'viens', 'venez', 'come', 'retrouver', 'meet',
      'chercher', 'pick you up', 'te prendre', 'get you',
      'où habites', 'where do you live', 'ton adresse',
      'your address', 'chez toi', 'your house', 'seul',
      'alone', 'ensemble', 'together', 'rendez-vous',
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _hasTrustBuilding(String text) {
    final keywords = [
      'confiance', 'trust', 'comprends', 'understand',
      'différent', 'different', 'ami', 'friend', 'soutien',
      'support', 'écoute', 'listen', 'seul à seul',
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _hasPersonalInfoRequest(String text) {
    final keywords = [
      'adresse', 'address', 'où habites', 'where live',
      'numéro', 'number', 'téléphone', 'phone',
      'école', 'school', 'âge', 'age', 'quand',
      'when', 'snap', 'instagram', 'insta', 'facebook',
    ];
    return keywords.any((kw) => text.contains(kw));
  }

  double _calculateMessageRisk(List<Map<String, dynamic>> messages) {
    final text = messages.map((m) => m['text'] as String).join(' ');
    double score = 0.0;
    
    if (_hasPhotoRequest(text)) score += 0.3;
    if (_hasSecrecy(text)) score += 0.4;
    if (_hasMeetingRequest(text)) score += 0.3;
    if (_hasIsolation(text)) score += 0.25;
    
    return score.clamp(0.0, 1.0);
  }

  /// Clear history for a conversation
  void clearHistory(String conversationId) {
    _history.remove(conversationId);
  }

  /// Get all conversation IDs
  List<String> getConversationIds() {
    return _history.keys.toList();
  }

  /// Get message count for a conversation
  int getMessageCount(String conversationId) {
    return _history[conversationId]?.length ?? 0;
  }

  // Legacy compatibility methods
  static Future<Map<String, dynamic>> detectGrooming(List<Map<String, dynamic>> messages) async {
    final detector = ContextDetector();
    final conversationId = messages.hashCode.toString();
    for (final msg in messages) {
      detector.addMessage(conversationId, msg['text']?.toString() ?? '', sender: msg['sender']?.toString());
    }
    return detector.analyze(conversationId);
  }

  static Future<Map<String, dynamic>> detectAbuse(List<Map<String, dynamic>> messages) async {
    final text = messages.map((m) => (m['text'] ?? '').toString().toLowerCase()).join(' ');
    final abuseKeywords = [
      'hate', 'stupid', 'idiot', 'loser', 'worthless',
      'kill yourself', 'die', 'kys', 'je vais te tuer',
      'je te hais', 'sale merde', 'connard', 'salope',
      'pétasse', 'pute', 'fais le ou je', 'sinon je vais',
    ];
    
    var keywordCount = 0;
    for (final keyword in abuseKeywords) {
      if (text.contains(keyword)) keywordCount++;
    }
    
    final confidence = (keywordCount * 0.25).clamp(0.0, 1.0);
    final detected = confidence > 0.4;
    
    return {
      'detected': detected,
      'confidence': confidence,
      'pattern': detected ? 'bullying_abuse' : 'none',
      'keyword_count': keywordCount,
      'severity': detected ? (confidence > 0.8 ? 'high' : 'medium') : 'low',
      'model': 'keyword_v1',
    };
  }

  static Future<Map<String, dynamic>> analyzeVelocity(List<Map<String, dynamic>> messages) async {
    if (messages.length < 2) {
      return {'escalating': false, 'velocity_score': 0.0};
    }
    
    final periods = (messages.length / 10).ceil();
    var escalationCount = 0;
    
    for (var i = 1; i < periods; i++) {
      escalationCount++;
    }
    
    final velocityScore = (escalationCount / periods.toDouble()).clamp(0.0, 1.0);
    
    return {
      'escalating': velocityScore > 0.5,
      'velocity_score': velocityScore,
      'periods_analyzed': periods,
      'model': 'velocity_v1',
    };
  }
}
