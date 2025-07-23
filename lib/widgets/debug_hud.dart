import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/inference_metrics.dart';

class DebugHud extends StatelessWidget {
  const DebugHud({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: InferenceMetrics.contextTokens,
      builder: (context, ctx, _) => ValueListenableBuilder<int>(
        valueListenable: InferenceMetrics.lastLatencyMs,
        builder: (context, ms, __) {
          return Positioned(
            top: 32,
            right: 16,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'CTX $ctx/2048 • ${ms}ms',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 