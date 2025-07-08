import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;

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
Extract ALL visible text from this image accurately.

Rules:
- Return ONLY the extracted text, no explanations
- Maintain original formatting and line breaks
- If handwritten, interpret clearly
- If no text is visible, return empty response
- For printed text, be extremely accurate

Extract the text:''';

  // Conservative image constraints to prevent memory pressure 
  static const int _maxImageWidth = 768;   // Reduced from 1024
  static const int _maxImageHeight = 768;  // Reduced from 1024
  static const int _maxImageBytes = 512 * 1024; // 512KB max (reduced from 1MB)

  // Session tracking for memory management
  static int _sessionCount = 0;

  /// Main OCR method using Gemma 3n vision with flutter_gemma optimizations
  Future<OCRResult> scanImage(File imageFile) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch;
    InferenceModelSession? session;
    
    try {
      developer.log('🔍 [Session $sessionId] Starting OCR scan for image: ${imageFile.path}', name: 'dyslexic_ai.ocr');
      
      // Add memory pressure check before proceeding
      await _checkMemoryPressure(sessionId);
      
      // Use the SAME pattern as working AIInferenceService (singleton model access)
      final plugin = FlutterGemmaPlugin.instance;
      final inferenceModel = plugin.initializedModel;
      
      if (inferenceModel == null) {
        developer.log('❌ [Session $sessionId] Model not initialized', name: 'dyslexic_ai.ocr');
        throw Exception('AI model not initialized. Please ensure the model is loaded first.');
      }

      developer.log('🤖 [Session $sessionId] Model retrieved successfully (${inferenceModel.runtimeType})', name: 'dyslexic_ai.ocr');

      // Process image following flutter_gemma best practices
      final processedBytes = await _optimizeImageForFlutterGemma(imageFile);
      developer.log('📷 [Session $sessionId] Image optimized: ${processedBytes.length} bytes', name: 'dyslexic_ai.ocr');

      // Create session with SAME parameters as working AIInferenceService
      developer.log('🆕 [Session $sessionId] Creating fresh session (OCR)...', name: 'dyslexic_ai.ocr');
      session = await inferenceModel.createSession(
        temperature: 0.3,    // Same as AIInferenceService for consistency
        topK: 10,            // Same as AIInferenceService
      );
      developer.log('✅ [Session $sessionId] Fresh session created successfully', name: 'dyslexic_ai.ocr');

      try {
        // Use CORRECT flutter_gemma multimodal message format
        final message = Message(
          text: _ocrPrompt,
          imageBytes: processedBytes,
          isUser: true,
        );
        
        developer.log('📤 [Session $sessionId] Sending message to model...', name: 'dyslexic_ai.ocr');
        
        // Use the correct flutter_gemma method for sending messages
        await session.addQueryChunk(message);
        
        developer.log('📥 [Session $sessionId] Getting response from model...', name: 'dyslexic_ai.ocr');
        
        // Get response using flutter_gemma's direct API
        final response = await session.getResponse();
        developer.log('📥 [Session $sessionId] Response received: ${response.length} chars', name: 'dyslexic_ai.ocr');
        
        final extractedText = response.trim();
        
        // Clean and validate the response
        final cleanedText = _cleanOCRResult(extractedText);
        
        developer.log('✅ [Session $sessionId] OCR completed: ${cleanedText.length} characters extracted', name: 'dyslexic_ai.ocr');
        
        return OCRResult(
          text: cleanedText,
          confidence: _estimateConfidence(cleanedText),
        );
      } finally {
        // Clean up session after use (same pattern as AIInferenceService)
        await session.close();
        developer.log('Session closed after successful OCR', name: 'dyslexic_ai.ocr');
        
        // Add cooling off period to prevent memory accumulation
        await _performPostOCRCleanup(sessionId);
      }
    } catch (e, stackTrace) {
      developer.log('Error in OCR scanImage: $e', name: 'dyslexic_ai.ocr', error: e, stackTrace: stackTrace);
      
      // Clean up session on error (same pattern as AIInferenceService)
      if (session != null) {
        try {
          await session.close();
          developer.log('Session closed after error', name: 'dyslexic_ai.ocr');
        } catch (closeError) {
          developer.log('Error closing session: $closeError', name: 'dyslexic_ai.ocr');
        }
      }
      
      return OCRResult(
        text: '',
        error: 'OCR failed: ${e.toString()}',
      );
    }
  }

  /// Optimize image for flutter_gemma processing (mobile-focused)
  Future<Uint8List> _optimizeImageForFlutterGemma(File imageFile) async {
    try {
      // Read original image
      final originalBytes = await imageFile.readAsBytes();
      developer.log('📊 Original image: ${originalBytes.length} bytes', name: 'dyslexic_ai.ocr');
      
      // Quick check - if already small enough, use as-is
      if (originalBytes.length <= _maxImageBytes) {
        // Decode to check dimensions
        final image = img.decodeImage(originalBytes);
        if (image != null && 
            image.width <= _maxImageWidth && 
            image.height <= _maxImageHeight) {
          developer.log('✅ Image already optimized', name: 'dyslexic_ai.ocr');
          return originalBytes;
        }
      }
      
      // Decode image for processing
      final image = img.decodeImage(originalBytes);
      if (image == null) {
        throw Exception('Invalid image format');
      }
      
      developer.log('📐 Original dimensions: ${image.width}x${image.height}', name: 'dyslexic_ai.ocr');
      
      // Calculate optimal resize maintaining aspect ratio
      final scale = math.min(
        _maxImageWidth / image.width,
        _maxImageHeight / image.height,
      );
      
      img.Image processedImage = image;
      
      // Resize if needed
      if (scale < 1.0) {
        final newWidth = (image.width * scale).round();
        final newHeight = (image.height * scale).round();
        
        processedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear, // Good quality for text
        );
        
        developer.log('🔄 Resized to: ${newWidth}x$newHeight (scale: ${scale.toStringAsFixed(2)})', name: 'dyslexic_ai.ocr');
      }
      
      // Encode as JPEG with conservative quality to reduce memory pressure
      final optimizedBytes = img.encodeJpg(
        processedImage,
        quality: 75, // Lower quality to reduce memory usage
      );
      
      developer.log('✅ Optimized image: ${optimizedBytes.length} bytes (${(originalBytes.length - optimizedBytes.length) / originalBytes.length * 100}% reduction)', name: 'dyslexic_ai.ocr');
      
      return Uint8List.fromList(optimizedBytes);
    } catch (e) {
      developer.log('⚠️ Image optimization failed, using original: $e', name: 'dyslexic_ai.ocr');
      // Fallback to original if optimization fails
      return await imageFile.readAsBytes();
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
        .replaceAll(RegExp("[^\\w\\s\\.\\,\\!\\?\\;\\:\\-'\"]+"), '') // Keep basic punctuation
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

  /// Check memory pressure and add delays if needed
  Future<void> _checkMemoryPressure(int sessionId) async {
    try {
      _sessionCount++;
      
      // Add progressively longer delays as session count increases
      final delayMs = _sessionCount >= 3 ? 300 : 100;
      await Future.delayed(Duration(milliseconds: delayMs));
      
      developer.log('🧠 [Session $sessionId] Memory pressure check completed (sessions: $_sessionCount)', name: 'dyslexic_ai.ocr');
    } catch (e) {
      developer.log('⚠️ [Session $sessionId] Memory pressure check failed: $e', name: 'dyslexic_ai.ocr');
    }
  }

  /// Perform cleanup after OCR to prevent memory accumulation
  Future<void> _performPostOCRCleanup(int sessionId) async {
    try {
      // Add progressively longer cooling off periods for higher session counts
      final delayMs = _sessionCount >= 3 ? 500 : 200;
      await Future.delayed(Duration(milliseconds: delayMs));
      
      developer.log('🧹 [Session $sessionId] Post-OCR cleanup completed (sessions: $_sessionCount)', name: 'dyslexic_ai.ocr');
    } catch (e) {
      developer.log('⚠️ [Session $sessionId] Post-OCR cleanup failed: $e', name: 'dyslexic_ai.ocr');
    }
  }
} 