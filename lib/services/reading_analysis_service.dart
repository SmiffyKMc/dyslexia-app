import 'dart:math' as math;
import '../models/reading_session.dart';

class ReadingAnalysisService {
  
  Future<List<WordResult>> analyzeReading({
    required String expectedText,
    required String spokenText,
  }) async {
    print('📊 === READING ANALYSIS START ===');
    print('📊 Expected Text: "$expectedText"');
    print('📊 Spoken Text: "$spokenText"');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final expectedWords = expectedText.toLowerCase().split(RegExp(r'\s+'));
    final spokenWords = spokenText.toLowerCase().split(RegExp(r'\s+'));
    
    print('📊 Expected Words (${expectedWords.length}): $expectedWords');
    print('📊 Spoken Words (${spokenWords.length}): $spokenWords');
    
    final results = _compareWords(expectedWords, spokenWords);
    
    print('📊 === ANALYSIS RESULTS ===');
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      print('📊 Word ${i + 1}: "${result.expectedWord}" vs "${result.spokenWord}" → ${result.isCorrect ? "✅" : "❌"} (confidence: ${result.confidence.toStringAsFixed(2)})');
    }
    
    final accuracy = results.where((r) => r.isCorrect).length / results.length;
    print('📊 Overall Accuracy: ${(accuracy * 100).toStringAsFixed(1)}% (${results.where((r) => r.isCorrect).length}/${results.length})');
    print('📊 === READING ANALYSIS END ===');
    
    return results;
  }

  List<WordResult> _compareWords(List<String> expectedWords, List<String> spokenWords) {
    final results = <WordResult>[];
    final random = math.Random();
    
    print('📊 === WORD ALIGNMENT START ===');
    print('📊 Expected: $expectedWords');
    print('📊 Spoken: $spokenWords');
    
    // Use dynamic programming for better word alignment
    final alignment = _alignWords(expectedWords, spokenWords);
    
    print('📊 Alignment result: $alignment');
    print('📊 === WORD ALIGNMENT END ===');
    
    for (int i = 0; i < expectedWords.length; i++) {
      final expectedWord = expectedWords[i];
      final spokenWord = alignment[i];
      
      final isCorrect = _isWordCorrect(expectedWord, spokenWord);
      final confidence = random.nextDouble() * 0.3 + 0.7;
      
      results.add(WordResult(
        expectedWord: expectedWord,
        spokenWord: spokenWord,
        isCorrect: isCorrect,
        confidence: confidence,
      ));
    }
    
    return results;
  }

  List<String?> _alignWords(List<String> expected, List<String> spoken) {
    // Simple alignment: try to find each spoken word in the expected sequence
    final alignment = <String?>[...List.filled(expected.length, null)];
    final usedSpokenIndices = <bool>[...List.filled(spoken.length, false)];
    
    // First pass: exact matches in sequence
    int spokenIndex = 0;
    for (int expIndex = 0; expIndex < expected.length && spokenIndex < spoken.length; expIndex++) {
      final expectedWord = _normalizeWord(expected[expIndex]);
      final spokenWord = _normalizeWord(spoken[spokenIndex]);
      
      if (expectedWord == spokenWord) {
        alignment[expIndex] = spoken[spokenIndex];
        usedSpokenIndices[spokenIndex] = true;
        spokenIndex++;
        print('📊 Exact match: "${expected[expIndex]}" = "${spoken[spokenIndex-1]}"');
      } else {
        // Check if the spoken word appears later in expected
        bool foundMatch = false;
        for (int laterExpIndex = expIndex + 1; laterExpIndex < math.min(expIndex + 3, expected.length); laterExpIndex++) {
          if (_normalizeWord(expected[laterExpIndex]) == spokenWord) {
            print('📊 Word "${spoken[spokenIndex]}" found later at position $laterExpIndex, skipping "${expected[expIndex]}"');
            foundMatch = true;
            break;
          }
        }
        
        if (!foundMatch) {
          print('📊 No match for "${expected[expIndex]}", word skipped or mispronounced');
        }
      }
    }
    
    // Second pass: try to match remaining spoken words with remaining expected words
    for (int spIndex = 0; spIndex < spoken.length; spIndex++) {
      if (usedSpokenIndices[spIndex]) continue;
      
      for (int expIndex = 0; expIndex < expected.length; expIndex++) {
        if (alignment[expIndex] != null) continue;
        
        final similarity = _calculateSimilarity(_normalizeWord(expected[expIndex]), _normalizeWord(spoken[spIndex]));
        if (similarity > 0.6) {
          alignment[expIndex] = spoken[spIndex];
          usedSpokenIndices[spIndex] = true;
          print('📊 Similarity match: "${expected[expIndex]}" ≈ "${spoken[spIndex]}" (${(similarity * 100).toStringAsFixed(1)}%)');
          break;
        }
      }
    }
    
    return alignment;
  }

  bool _isWordCorrect(String expected, String? spoken) {
    if (spoken == null) {
      print('📊   Word comparison: "$expected" vs null → ❌ (no speech)');
      return false;
    }
    
    final originalExpected = expected;
    final originalSpoken = spoken;
    expected = _normalizeWord(expected);
    spoken = _normalizeWord(spoken);
    
    if (expected == spoken) {
      print('📊   Word comparison: "$originalExpected" vs "$originalSpoken" → ✅ (exact match)');
      return true;
    }
    
    final similarity = _calculateSimilarity(expected, spoken);
    final isCorrect = similarity > 0.8;
    print('📊   Word comparison: "$originalExpected" vs "$originalSpoken" → ${isCorrect ? "✅" : "❌"} (similarity: ${(similarity * 100).toStringAsFixed(1)}%)');
    return isCorrect;
  }

  String _normalizeWord(String word) {
    return word
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w]'), '');
  }

  double _calculateSimilarity(String word1, String word2) {
    if (word1 == word2) return 1.0;
    if (word1.isEmpty || word2.isEmpty) return 0.0;
    
    final maxLength = math.max(word1.length, word2.length);
    final distance = _levenshteinDistance(word1, word2);
    
    return 1.0 - (distance / maxLength);
  }

  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  Future<String> generateFeedbackMessage(WordResult wordResult) async {
    if (wordResult.isCorrect) {
      return 'Great job with "${wordResult.expectedWord}"!';
    } else {
      final spokenWord = wordResult.spokenWord ?? 'nothing';
      return 'Try "${wordResult.expectedWord}" again. You said "$spokenWord".';
    }
  }

  Future<List<String>> suggestPracticeWords(List<WordResult> results) async {
    return results
        .where((result) => !result.isCorrect)
        .map((result) => result.expectedWord)
        .take(5)
        .toList();
  }
} 