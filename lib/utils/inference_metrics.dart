import 'package:flutter/foundation.dart';

class InferenceMetrics {
  static final ValueNotifier<int> contextTokens = ValueNotifier<int>(0);
  static final ValueNotifier<int> lastLatencyMs = ValueNotifier<int>(0);
} 