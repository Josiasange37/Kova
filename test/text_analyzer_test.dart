import 'package:flutter_test/flutter_test.dart';
import 'package:kova/child/services/text_analyzer.dart';

void main() {
  group('TextAnalyzer keyword detection', () {
    test('"fuck you" scores as violence high', () {
      final result = TextAnalyzer.analyze('fuck you');
      expect(result['violence'], greaterThan(0.5),
          reason: '"fuck you" should trigger violence score > 0.5');
      expect(result['unsafe'], greaterThan(0.5),
          reason: 'Overall unsafe score should be > 0.5');
    });

    test('"commit suicide" scores as critical violence', () {
      final result = TextAnalyzer.analyze('commit suicide');
      expect(result['violence'], greaterThanOrEqualTo(0.85),
          reason: '"commit suicide" should trigger violence score >= 0.85');
    });

    test('"kill myself" scores as critical self-harm', () {
      final result = TextAnalyzer.analyze('i want to kill myself');
      expect(result['violence'], equals(1.0),
          reason: '"kill myself" should be max severity');
    });

    test('"send nudes" scores as sexual', () {
      final result = TextAnalyzer.analyze('send nudes');
      expect(result['sexual'], greaterThanOrEqualTo(0.9));
    });

    test('"our secret" scores as grooming', () {
      final result = TextAnalyzer.analyze("this is our secret, don't tell");
      expect(result['grooming'], greaterThan(0.5));
    });

    test('safe message returns low risk', () {
      final result = TextAnalyzer.analyze('how was school today?');
      expect(result['unsafe'], lessThan(0.2));
    });
  });
}
