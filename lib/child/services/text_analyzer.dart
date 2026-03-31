// child/services/text_analyzer.dart — Real keyword-based text content analyzer
// Detects harmful content in French and English
// Works completely offline, no TFLite needed

import 'package:flutter/foundation.dart';

/// Real text analyzer that detects harmful content using keyword patterns
class TextAnalyzer {
  // Danger keywords organized by category and weight
  // Higher weight = more dangerous
  static const Map<String, Map<String, double>> _riskKeywords = {
    'sexual': {
      // French
      'envoie moi une photo': 0.8,
      'envoie une photo de toi': 0.9,
      'montre moi': 0.5,
      'photo nue': 1.0,
      'photo de toi': 0.6,
      'déshabille': 0.9,
      'pornographie': 1.0,
      'sexe': 0.8,
      'nue': 0.8,
      'seins': 0.7,
      'fesses': 0.7,
      'sous-vêtements': 0.6,
      // English
      'send nudes': 1.0,
      'send me a pic': 0.7,
      'sexy photo': 0.8,
      'show me': 0.5,
      'naked': 0.9,
      'nude': 0.9,
      'porn': 0.9,
      'xxx': 0.8,
      'boobs': 0.7,
      'ass pic': 0.7,
      'underwear': 0.6,
    },
    'grooming': {
      // French - isolation & secrecy
      "dis rien à ta maman": 0.9,
      "dis rien à tes parents": 0.9,
      "c'est notre secret": 0.9,
      "entre nous": 0.6,
      "ne le dis à personne": 0.9,
      "personne ne doit savoir": 0.9,
      "personne ne sait": 0.7,
      "juste nous": 0.7,
      "notre petit secret": 0.9,
      "garde ça pour toi": 0.8,
      "reste entre nous": 0.8,
      "ne dis rien": 0.7,
      // French - meeting requests
      "on va se retrouver": 0.8,
      "viens me voir": 0.9,
      "je viens te chercher": 0.9,
      "on se voit où": 0.7,
      "tu habites où": 0.6,
      "donne moi ton adresse": 0.8,
      // French - trust building
      "tu peux me faire confiance": 0.5,
      "je suis différent": 0.5,
      "je te comprends": 0.4,
      "tes parents ne comprennent pas": 0.7,
      // English
      "don't tell your parents": 0.9,
      "don't tell your mom": 0.9,
      "our secret": 0.9,
      "just between us": 0.8,
      "no one needs to know": 0.9,
      "meet me": 0.8,
      "come see me": 0.9,
      "i'll pick you up": 0.9,
      "where do you live": 0.6,
      "send me your address": 0.8,
      "you can trust me": 0.5,
      "your parents don't understand": 0.7,
      "i'm different": 0.5,
    },
    'violence': {
      // French
      'je vais te tuer': 1.0,
      'je vais te frapper': 0.9,
      'tu vas mourir': 1.0,
      'je te hais': 0.7,
      'sale merde': 0.6,
      'connard': 0.6,
      'salope': 0.8,
      'pétasse': 0.8,
      'pute': 0.9,
      'fais le ou je': 0.8,
      'sinon je vais': 0.8,
      // English
      'kill yourself': 1.0,
      'kys': 1.0,
      'kill you': 0.9,
      'i hate you': 0.7,
      'i will hurt you': 0.9,
      'beat you up': 0.8,
      'shut up or i': 0.7,
      'do it or i will': 0.8,
      'you deserve to die': 1.0,
      'ugly bitch': 0.8,
      'stupid whore': 0.8,
    },
    'unsafe': {
      // French
      'drogue': 0.6,
      'cocaine': 0.8,
      'weed': 0.5,
      'marijuana': 0.5,
      'alcool': 0.4,
      'viens boire': 0.6,
      'fumer ensemble': 0.6,
      'shoot': 0.7,
      'shooter': 0.7,
      // English
      'drugs': 0.6,
      'heroin': 0.9,
      'meth': 0.8,
      'drink with me': 0.5,
      'smoke together': 0.6,
      'get high': 0.6,
    },
    'personal_info': {
      // French
      'donne moi ton snap': 0.5,
      'donne moi ton instagram': 0.5,
      'donne moi ton num': 0.6,
      'ton adresse': 0.7,
      'ta ville': 0.4,
      'ton école': 0.5,
      // English
      'give me your snap': 0.5,
      'give me your insta': 0.5,
      'give me your number': 0.6,
      'your address': 0.7,
      'your school': 0.5,
    },
  };

  /// Analyze text and return risk scores by category
  /// Returns: Map with scores 0.0-1.0 for each category + overall unsafe score
  static Map<String, double> analyze(String text) {
    if (text.isEmpty) {
      return {
        'safe': 1.0,
        'unsafe': 0.0,
        'sexual': 0.0,
        'grooming': 0.0,
        'violence': 0.0,
        'unsafe_substances': 0.0,
        'personal_info': 0.0,
        'detected_keywords': 0.0,
      };
    }

    final lowerText = text.toLowerCase();
    final results = <String, double>{
      'sexual': 0.0,
      'grooming': 0.0,
      'violence': 0.0,
      'unsafe_substances': 0.0,
      'personal_info': 0.0,
    };

    int detectedKeywordCount = 0;

    // Check each category
    for (final category in _riskKeywords.entries) {
      final categoryName = category.key;
      final keywords = category.value;

      for (final entry in keywords.entries) {
        final keyword = entry.key;
        final weight = entry.value;

        if (lowerText.contains(keyword)) {
          // Add weighted score
          results[categoryName] = 
              ((results[categoryName] ?? 0.0) + weight).clamp(0.0, 1.0);
          detectedKeywordCount++;
          
          if (kDebugMode) {
            debugPrint('🔍 TextAnalyzer detected: "$keyword" (weight: $weight)');
          }
        }
      }
    }

    // Calculate overall unsafe score (max of all categories)
    final unsafeScore = [
      results['sexual'] ?? 0.0,
      results['grooming'] ?? 0.0,
      results['violence'] ?? 0.0,
      results['unsafe_substances'] ?? 0.0,
      results['personal_info'] ?? 0.0,
    ].reduce((a, b) => a > b ? a : b);

    // Boost score if multiple categories detected (combination risk)
    final nonZeroCategories = results.values.where((v) => v > 0).length;
    final combinationBoost = nonZeroCategories > 1 ? 0.15 : 0.0;
    
    final finalUnsafeScore = (unsafeScore + combinationBoost).clamp(0.0, 1.0);

    return {
      'safe': (1.0 - finalUnsafeScore).clamp(0.0, 1.0),
      'unsafe': finalUnsafeScore,
      'sexual': results['sexual'] ?? 0.0,
      'grooming': results['grooming'] ?? 0.0,
      'violence': results['violence'] ?? 0.0,
      'unsafe_substances': results['unsafe_substances'] ?? 0.0,
      'personal_info': results['personal_info'] ?? 0.0,
      'detected_keywords': detectedKeywordCount.toDouble(),
    };
  }

  /// Get risk level string from score
  static String getRiskLevel(double unsafeScore) {
    if (unsafeScore < 0.2) return 'safe';
    if (unsafeScore < 0.4) return 'low';
    if (unsafeScore < 0.6) return 'medium';
    if (unsafeScore < 0.8) return 'high';
    return 'critical';
  }

  /// Analyze multiple texts and return aggregate scores
  static Map<String, dynamic> analyzeBatch(List<String> texts) {
    var maxUnsafe = 0.0;
    var maxSexual = 0.0;
    var maxGrooming = 0.0;
    var maxViolence = 0.0;
    var totalKeywords = 0;

    for (final text in texts) {
      final result = analyze(text);
      maxUnsafe = maxUnsafe > result['unsafe']! ? maxUnsafe : result['unsafe']!;
      maxSexual = maxSexual > result['sexual']! ? maxSexual : result['sexual']!;
      maxGrooming = maxGrooming > result['grooming']! ? maxGrooming : result['grooming']!;
      maxViolence = maxViolence > result['violence']! ? maxViolence : result['violence']!;
      totalKeywords += result['detected_keywords']!.toInt();
    }

    return {
      'safe': (1.0 - maxUnsafe).clamp(0.0, 1.0),
      'unsafe': maxUnsafe,
      'sexual': maxSexual,
      'grooming': maxGrooming,
      'violence': maxViolence,
      'detected_keywords': totalKeywords,
      'message_count': texts.length,
      'risk_level': getRiskLevel(maxUnsafe),
    };
  }
}
