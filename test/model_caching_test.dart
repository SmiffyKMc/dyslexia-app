import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dyslexic_ai/services/model_download_service.dart';

void main() {
  group('Model Caching Tests', () {
    late ModelDownloadService service;

    setUp(() {
      service = ModelDownloadService();
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('isModelAvailable returns false when no model downloaded', () async {
      final isAvailable = await service.isModelAvailable();
      expect(isAvailable, false);
    });

    test('isModelAvailable returns true after marking model as downloaded', () async {
      // Simulate model download completion
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dyslexic_ai_model_downloaded', true);
      
      final isAvailable = await service.isModelAvailable();
      expect(isAvailable, true);
    });

    test('clearModelData resets cache state', () async {
      // First mark model as downloaded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dyslexic_ai_model_downloaded', true);
      
      // Verify it's marked as available
      expect(await service.isModelAvailable(), true);
      
      // Clear the data
      await service.clearModelData();
      
      // Verify it's no longer marked as available
      expect(await service.isModelAvailable(), false);
      expect(service.isModelReady, false);
      expect(service.downloadProgress, 0.0);
      expect(service.downloadError, null);
    });

    test('downloadModelIfNeeded behavior with cached model', () async {
      // Mock model as already downloaded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dyslexic_ai_model_downloaded', true);
      
      bool progressCallbackCalled = false;
      bool successCallbackCalled = false;
      bool errorCallbackCalled = false;
      double? finalProgress;
      
      // This should NOT trigger a download, just return cached state
      await service.downloadModelIfNeeded(
        onProgress: (progress) {
          progressCallbackCalled = true;
          finalProgress = progress;
        },
        onSuccess: () {
          successCallbackCalled = true;
        },
        onError: (error) {
          errorCallbackCalled = true;
        },
      );
      
      // Verify cached behavior
      expect(progressCallbackCalled, true, reason: 'Progress callback should be called even for cached model');
      expect(finalProgress, 1.0, reason: 'Progress should be 100% for cached model');
      expect(successCallbackCalled, true, reason: 'Success callback should be called for cached model');
      expect(errorCallbackCalled, false, reason: 'Error callback should not be called for cached model');
      expect(service.isModelReady, true, reason: 'Model should be ready when cached');
      expect(service.downloadProgress, 1.0, reason: 'Download progress should be 100% for cached model');
    });

    test('downloadModelIfNeeded behavior without cached model', () async {
      // Ensure no cached model
      expect(await service.isModelAvailable(), false);
      
      bool progressCallbackCalled = false;
      bool initialProgressWasZero = false;
      
      try {
        // This WOULD trigger a download (but will likely fail in test environment)
        await service.downloadModelIfNeeded(
          onProgress: (progress) {
            progressCallbackCalled = true;
            if (progress == 0.0) {
              initialProgressWasZero = true;
            }
          },
          onSuccess: () {
            // Won't be called in test environment
          },
          onError: (error) {
            // Expected to be called in test environment
            expect(error, isNotNull);
          },
        );
      } catch (e) {
        // Expected in test environment without actual model download capability
      }
      
      // Verify download attempt behavior
      expect(progressCallbackCalled, true, reason: 'Progress callback should be called when attempting download');
      expect(initialProgressWasZero, true, reason: 'Initial progress should be 0% when starting download');
    });
  });
} 