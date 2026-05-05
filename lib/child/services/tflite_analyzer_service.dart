import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Integrates a quantized TFLite NLP model for on-device text classification.
class TfLiteAnalyzerService {
  static final TfLiteAnalyzerService _instance = TfLiteAnalyzerService._internal();
  factory TfLiteAnalyzerService() => _instance;
  TfLiteAnalyzerService._internal();

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  
  // Sequence length based on model architecture (e.g., 128 for MobileBERT)
  static const int _maxSeqLen = 128;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Map of output tensor indices to KOVA risk categories
  static const Map<int, String> _categories = {
    0: 'safe',
    1: 'sexual',
    2: 'grooming',
    3: 'violence',
    4: 'unsafe_substances',
    5: 'personal_info'
  };

  /// Initialize the TensorFlow Lite interpreter and vocabulary
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Load vocabulary for tokenization
      final vocabString = await rootBundle.loadString('assets/ml/vocab.txt');
      _vocab = _loadVocab(vocabString);

      // 2. Initialize the interpreter with the quantized model
      final options = InterpreterOptions()..threads = 2; // Optimize for mobile
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/text_classifier_quantized.tflite', 
        options: options
      );
      
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('🤖 TfLiteAnalyzerService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize TFLite model: $e');
      }
      _isInitialized = false;
    }
  }

  /// Parses vocabulary file into a fast lookup map
  Map<String, int> _loadVocab(String vocabString) {
    final Map<String, int> vocab = {};
    final lines = vocabString.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    return vocab;
  }

  /// Basic Tokenizer
  /// NOTE: Adjust this logic (WordPiece / SentencePiece) to match how your model was trained.
  List<int> _tokenize(String text) {
    if (_vocab == null) return List.filled(_maxSeqLen, 0);

    // Simple word extraction (replace with Subword tokenization if needed by model)
    final tokens = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));
    final List<int> inputIds = [];
    
    // Add [CLS] token equivalent if needed (e.g., 101 for BERT)
    // inputIds.add(101);

    for (var token in tokens) {
      if (token.isEmpty) continue;
      // Map token to ID, default to [UNK] (e.g. 100) if not in vocab
      inputIds.add(_vocab![token] ?? 100); 
      if (inputIds.length >= _maxSeqLen) break;
    }

    // Pad the sequence with 0s up to _maxSeqLen
    final paddedInput = List<int>.filled(_maxSeqLen, 0);
    for (int i = 0; i < inputIds.length; i++) {
      paddedInput[i] = inputIds[i];
    }

    return paddedInput;
  }

  /// Run inference on incoming text
  Future<Map<String, dynamic>> analyzeText(String text) async {
    if (!_isInitialized || _interpreter == null) {
      if (kDebugMode) debugPrint('⚠️ TFLite not initialized. Returning safe default.');
      return _fallbackSafeResult();
    }

    if (text.trim().isEmpty) {
      return _fallbackSafeResult();
    }

    try {
      // 1. Tokenize the input text into integers
      final inputIds = _tokenize(text);

      // 2. Prepare I/O buffers
      // Input shape: [1, maxSeqLen]. Use int32 or float32 depending on your .tflite input tensor
      var input = [inputIds];
      
      // Output shape: [1, num_categories]
      var output = List.generate(1, (_) => List.filled(_categories.length, 0.0));

      // 3. Run Inference on-device
      _interpreter!.run(input, output);
      
      // 4. Process results
      final scores = output[0]; // probabilities for each category
      
      // Find the highest confidence category
      double maxScore = 0.0;
      int maxIndex = 0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      final detectedCategory = _categories[maxIndex] ?? 'safe';
      
      // Unsafe score = 1.0 - confidence if safe, else it's the threat confidence.
      final unsafeScore = maxIndex == 0 ? (1.0 - maxScore).clamp(0.0, 1.0) : maxScore;
      
      return {
        'safe': (1.0 - unsafeScore).clamp(0.0, 1.0),
        'unsafe': unsafeScore,
        'sexual': detectedCategory == 'sexual' ? maxScore : 0.0,
        'grooming': detectedCategory == 'grooming' ? maxScore : 0.0,
        'violence': detectedCategory == 'violence' ? maxScore : 0.0,
        'unsafe_substances': detectedCategory == 'unsafe_substances' ? maxScore : 0.0,
        'personal_info': detectedCategory == 'personal_info' ? maxScore : 0.0,
        'detected_keywords': 0.0,
      };

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Inference error: $e');
      return _fallbackSafeResult();
    }
  }

  /// Analyze multiple texts and return aggregate scores
  Future<Map<String, dynamic>> analyzeBatch(List<String> texts) async {
    var maxUnsafe = 0.0;
    var maxSexual = 0.0;
    var maxGrooming = 0.0;
    var maxViolence = 0.0;

    for (final text in texts) {
      final result = await analyzeText(text);
      maxUnsafe = maxUnsafe > result['unsafe']! ? maxUnsafe : result['unsafe']!;
      maxSexual = maxSexual > result['sexual']! ? maxSexual : result['sexual']!;
      maxGrooming = maxGrooming > result['grooming']! ? maxGrooming : result['grooming']!;
      maxViolence = maxViolence > result['violence']! ? maxViolence : result['violence']!;
    }

    return {
      'safe': (1.0 - maxUnsafe).clamp(0.0, 1.0),
      'unsafe': maxUnsafe,
      'sexual': maxSexual,
      'grooming': maxGrooming,
      'violence': maxViolence,
      'detected_keywords': 0.0,
      'message_count': texts.length,
      'risk_level': _getRiskLevel(maxUnsafe),
    };
  }

  String _getRiskLevel(double unsafeScore) {
    if (unsafeScore < 0.2) return 'safe';
    if (unsafeScore < 0.4) return 'low';
    if (unsafeScore < 0.6) return 'medium';
    if (unsafeScore < 0.8) return 'high';
    return 'critical';
  }

  /// Dispose the interpreter when no longer needed to free memory
  void close() {
    _interpreter?.close();
    _isInitialized = false;
  }

  Map<String, dynamic> _fallbackSafeResult() {
    // Return all keys that SeverityEngine.calculate() reads.
    // This ensures a TFLite failure doesn't silently zero-out detection.
    // The TextAnalyzer (keyword-based) scores will still be merged on top.
    return {
      'unsafe':            0.0,
      'safe':              1.0,
      'sexual':            0.0,
      'grooming':          0.0,
      'violence':          0.0,
      'unsafe_substances': 0.0,
      'personal_info':     0.0,
      'detected_keywords': 0.0,
    };
  }
}
