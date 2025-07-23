import 'dart:developer' as developer;
import 'inference_metrics.dart';

class InferenceTrace {
  final Stopwatch _sw = Stopwatch()..start();
  final String promptSnippet;
  InferenceTrace(String prompt)
      : promptSnippet = prompt.replaceAll(RegExp(r'\s+'), ' ').trim() {
    developer.log('🧠 START $promptSnippet', name: 'ai.trace');
  }

  void done(int tokens) {
    _sw.stop();
    InferenceMetrics.lastLatencyMs.value = _sw.elapsedMilliseconds;
    developer.log(
      '🧠 END   $promptSnippet [${_sw.elapsedMilliseconds} ms, $tokens tokens]',
      name: 'ai.trace',
    );
  }
} 