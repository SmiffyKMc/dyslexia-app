import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;

/// Result model for OCR operations
class OCRResult {
  final String text;
  final double? confidence;
  final String? error;

  const OCRResult({
    required this.text,
    this.confidence,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get hasText => text.isNotEmpty;

  @override
  String toString() => 'OCRResult(text: "$text", confidence: $confidence, error: $error)';
}

/// OCRService using Gemma 3n vision capabilities for offline text extraction
class OcrService {
  static const String _ocrPrompt = '''
You are an expert OCR assistant. Extract ALL visible text from this image accurately.

Rules:
1. Return ONLY the extracted text, no explanations or comments
2. Maintain original formatting, line breaks, and spacing when possible
3. If text is handwritten, do your best to interpret it clearly
4. If no text is visible, return an empty response
5. For printed text, be extremely accurate
6. For mixed content, prioritize readability

Extract the text:''';

  /// Main OCR method using Gemma 3n vision
  Future<OCRResult> scanImage(File imageFile) async {
    try {
      developer.log('🔍 Starting OCR scan for image: ${imageFile.path}', name: 'dyslexic_ai.ocr');
      
      // Get the AI inference model
      final plugin = FlutterGemmaPlugin.instance;
      final inferenceModel = plugin.initializedModel;
      
      if (inferenceModel == null) {
        throw Exception('AI model not initialized. Please ensure the model is loaded first.');
      }

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      developer.log('📷 Image loaded: ${imageBytes.length} bytes', name: 'dyslexic_ai.ocr');

      // Create a fresh session for OCR
      final session = await inferenceModel.createSession(
        temperature: 0.1, // Low temperature for consistent OCR
        topK: 1,          // Most deterministic output
      );

      try {
        // Add vision message with OCR prompt
        await session.addQueryChunk(Message.withImage(
          text: _ocrPrompt,
          imageBytes: imageBytes,
          isUser: true,
        ));

        // Get response
        final extractedText = await session.getResponse();
        
        // Clean and validate the response
        final cleanedText = _cleanOCRResult(extractedText);
        
        developer.log('✅ OCR completed: ${cleanedText.length} characters extracted', name: 'dyslexic_ai.ocr');
        
        return OCRResult(
          text: cleanedText,
          confidence: _estimateConfidence(cleanedText),
        );
      } finally {
        // Always close the session
        await session.close();
      }
    } catch (e, stackTrace) {
      developer.log('❌ OCR failed: $e', name: 'dyslexic_ai.ocr', error: e, stackTrace: stackTrace);
      
      return OCRResult(
        text: '',
        error: 'Failed to extract text: ${e.toString()}',
      );
    }
  }

  /// Legacy method for backward compatibility
  Future<String> extractTextFromImage(File imageFile) async {
    final result = await scanImage(imageFile);
    return result.isSuccess ? result.text : '';
  }

  /// Legacy method for Reading Coach compatibility
  Future<String> processImageForReading(File imageFile) async {
    final result = await scanImage(imageFile);
    if (result.isSuccess) {
      return cleanAndFormatText(result.text);
    } else {
      throw Exception(result.error ?? 'OCR processing failed');
    }
  }

  /// Clean and format text for reading applications
  String cleanAndFormatText(String rawText) {
    return rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[^\w\s\.\,\!\?\;\:\-\'\"]'), '') // Keep basic punctuation
        .trim();
  }

  /// Clean OCR result from AI response
  String _cleanOCRResult(String rawResponse) {
    // Remove common AI response artifacts
    return rawResponse
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '')
        .replaceAll(RegExp(r'^(Here is the extracted text:|Extracted text:|Text:)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Normalize excessive line breaks
        .trim();
  }

  /// Estimate confidence based on text characteristics
  double? _estimateConfidence(String text) {
    if (text.isEmpty) return 0.0;
    
    // Simple heuristics for confidence estimation
    double confidence = 0.8; // Base confidence
    
    // Boost confidence for structured text
    if (text.contains(RegExp(r'[.!?]'))) confidence += 0.1;
    if (text.split(' ').length > 3) confidence += 0.05;
    if (text.contains(RegExp(r'\d'))) confidence += 0.05; // Contains numbers
    
    // Reduce confidence for very short text
    if (text.length < 10) confidence -= 0.2;
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Check if vision OCR is available
  Future<bool> isVisionOCRAvailable() async {
    try {
      final plugin = FlutterGemmaPlugin.instance;
      final model = plugin.initializedModel;
      
      if (model == null) {
        developer.log('❌ No model initialized', name: 'dyslexic_ai.ocr');
        return false;
      }
      
      // Try to create a session to verify model is ready
      try {
        final session = await model.createSession();
        await session.close();
        developer.log('✅ Vision OCR available and tested', name: 'dyslexic_ai.ocr');
        return true;
      } catch (sessionError) {
        developer.log('❌ Model session test failed: $sessionError', name: 'dyslexic_ai.ocr');
        return false;
      }
    } catch (e) {
      developer.log('❌ Vision OCR check failed: $e', name: 'dyslexic_ai.ocr');
      return false;
    }
  }

  /// Get OCR capability status
  Future<String> getOCRStatus() async {
    if (await isVisionOCRAvailable()) {
      return 'Gemma 3n Vision OCR Ready';
    } else {
      return 'OCR Not Available - Model not loaded';
    }
  }
} 