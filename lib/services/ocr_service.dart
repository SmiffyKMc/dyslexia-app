import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../utils/service_locator.dart';

/// OCR result data class
class OCRResult {
  final String text;
  final double? confidence;
  final String? error;

  OCRResult({
    required this.text,
    this.confidence,
    this.error,
  });

  // Compatibility getters
  bool get isSuccess => error == null;
  bool get hasText => text.isNotEmpty;
}

/// Enhanced OCR service with activity-based session management
class OcrService {
  // Simple image constraints for mobile OCR
  static const int _maxImageSize = 400;
  static const int _maxImageBytes = 256 * 1024; // 256KB max
  
  // Simple OCR prompt
  static const String _ocrPrompt = '''
Extract all text from this image. Return only the text content, no additional formatting or explanations.
If no text is found, return an empty response.
''';

  OcrService();
  
  /// Main OCR method with simple error handling
  Future<OCRResult> scanImage(File imageFile) async {
      try {
      developer.log('Starting OCR scan for image: ${imageFile.path}', name: 'dyslexic_ai.ocr');
        
      // Simple image processing
      final processedBytes = await _resizeImage(imageFile);
      developer.log('Image resized: ${processedBytes.length} bytes', name: 'dyslexic_ai.ocr');

      // Perform OCR
      final result = await _performOCR(processedBytes);
      
      developer.log('OCR completed successfully', name: 'dyslexic_ai.ocr');
      return result;
      
    } catch (e) {
      developer.log('OCR scan failed: $e', name: 'dyslexic_ai.ocr');
      return OCRResult(
        text: '',
        error: 'OCR processing failed: ${e.toString()}',
      );
    }
  }

  /// Legacy compatibility method
  Future<String> processImageForReading(File imageFile) async {
    final result = await scanImage(imageFile);
    if (result.isSuccess) {
      return cleanAndFormatText(result.text);
    } else {
      throw Exception(result.error ?? 'OCR processing failed');
    }
  }

  /// Legacy compatibility method
  Future<String> extractTextFromImage(File imageFile) async {
    final result = await scanImage(imageFile);
    return result.isSuccess ? result.text : '';
  }

  /// Clean and format text for reading applications
  String cleanAndFormatText(String rawText) {
    return rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Get OCR status for compatibility
  Future<String> getOCRStatus() async {
    try {
      final aiService = getAIInferenceService();
      if (aiService != null) {
        return 'OCR Ready';
      } else {
        return 'OCR Not Available - AI service not initialized';
      }
    } catch (e) {
      return 'OCR Not Available - Model not loaded';
    }
  }

  /// Simple image resizing to optimize for mobile OCR
  Future<Uint8List> _resizeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Invalid image format');
      }

      // Resize to maximum dimensions while maintaining aspect ratio
      final resized = img.copyResize(
        image, 
        width: image.width > image.height ? _maxImageSize : null,
        height: image.height > image.width ? _maxImageSize : null,
      );

      // Convert to JPEG with good quality
      final resizedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      
      // Check size constraint
      if (resizedBytes.length > _maxImageBytes) {
        // If still too large, reduce quality
        final compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 50));
        return compressedBytes;
      }
      
      return resizedBytes;
      
    } catch (e) {
      developer.log('Image resizing failed: $e', name: 'dyslexic_ai.ocr');
      rethrow;
    }
  }

  /// Perform OCR operation with activity-based session management
  Future<OCRResult> _performOCR(Uint8List imageBytes) async {
    try {
      final aiService = getAIInferenceService();
      if (aiService == null) {
        return OCRResult(
          text: '',
          confidence: 0.0,
          error: 'AI service not available. Please ensure the model is loaded.',
        );
      }
      
      developer.log('OCR session: ${aiService.getSessionDebugInfo()}', name: 'dyslexic_ai.ocr');
      
      // Use the new multimodal response method which handles OCR sessions properly
      final response = await aiService.generateMultimodalResponse(_ocrPrompt, imageBytes);
      developer.log('OCR response received: ${response.length} chars', name: 'dyslexic_ai.ocr');
      
      final extractedText = response.trim();
      
      // Basic validation
      if (extractedText.isEmpty) {
        return OCRResult(
          text: '',
          confidence: 0.0,
          error: 'No text could be extracted from the image.',
        );
      }
      
      // Simple confidence estimation based on text length and character diversity
      final confidence = _estimateConfidence(extractedText);
      
      return OCRResult(
        text: extractedText,
        confidence: confidence,
      );
      
    } catch (e) {
      developer.log('OCR operation failed: $e', name: 'dyslexic_ai.ocr');
      
      // Provide user-friendly error message
      String userError = 'OCR processing failed. Please try again with a different image.';
      if (e.toString().contains('memory')) {
        userError = 'Not enough memory available. Please try with a smaller image.';
      } else if (e.toString().contains('timeout')) {
        userError = 'OCR operation timed out. Please try with a clearer image.';
      }
      
      return OCRResult(
        text: '',
        confidence: 0.0,
        error: userError,
      );
    }
  }

  /// Simple confidence estimation
  double _estimateConfidence(String text) {
    if (text.isEmpty) return 0.0;
      
    // Basic heuristics for confidence
    double confidence = 0.7; // Base confidence
    
    // Longer text generally means better extraction
    if (text.length > 50) confidence += 0.1;
    if (text.length > 100) confidence += 0.1;
    
    // Presence of common words increases confidence
    final commonWords = ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had', 'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how', 'its', 'may', 'new', 'now', 'old', 'see', 'two', 'who', 'boy', 'did', 'man', 'way', 'too'];
    final lowerText = text.toLowerCase();
    final foundCommonWords = commonWords.where((word) => lowerText.contains(word)).length;
    confidence += (foundCommonWords / commonWords.length) * 0.2;
    
    return confidence.clamp(0.0, 1.0);
    }
  
  /// Dispose method for cleanup
  Future<void> dispose() async {
    // Session cleanup is now handled by AIInferenceService
    developer.log('OCR service disposed', name: 'dyslexic_ai.ocr');
  }
} 