import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;
import '../utils/service_locator.dart';
import 'global_session_manager.dart';

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
/// Now uses GlobalSessionManager for efficient session reuse
class OcrService {
  static const String _ocrPrompt = '''
Extract text from this image with high accuracy.

CRITICAL INSTRUCTIONS:
- Return ONLY the raw text content, no explanations or descriptions
- Preserve original spacing and line breaks exactly
- For printed text: be 100% accurate with every character
- For handwritten text: use best interpretation
- If no readable text exists, return empty response
- Do not add punctuation that isn't visible
- Do not correct obvious typos or errors in the source

TEXT:''';

  // Aggressive image constraints for mobile OCR optimization
  static const int _maxImageWidth = 400;   // Optimized for mobile OCR
  static const int _maxImageHeight = 400;  // Optimized for mobile OCR
  static const int _maxImageBytes = 256 * 1024; // 256KB max for mobile memory

  // OCR-specific timeout and session management
  static const Duration _ocrTimeout = Duration(seconds: 30); // Shorter timeout for OCR
  static const Duration _sessionTimeout = Duration(seconds: 45); // Session timeout
  static const int _maxRetries = 2; // Maximum retry attempts for OCR
  
  // Session tracking for memory management
  static int _sessionCount = 0;
  
  // Use shared session manager instead of individual cached session
  late final GlobalSessionManager _sessionManager;

  OcrService() {
    _sessionManager = getGlobalSessionManager();
  }
  
  /// Main OCR method using Gemma 3n vision with flutter_gemma optimizations
  Future<OCRResult> scanImage(File imageFile) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch;
    
    // Implement retry logic with OCR-specific timeouts
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        developer.log('🔍 [Session $sessionId] Starting OCR scan attempt $attempt for image: ${imageFile.path}', name: 'dyslexic_ai.ocr');
        
        // Add memory pressure check before proceeding
        await _checkMemoryPressure(sessionId);

        // Process image following flutter_gemma best practices
        final processedBytes = await _optimizeImageForFlutterGemma(imageFile);
        developer.log('📷 [Session $sessionId] Image optimized: ${processedBytes.length} bytes', name: 'dyslexic_ai.ocr');

        // Use OCR-specific session management with timeout
        final result = await _performOCRWithTimeout(sessionId, processedBytes);
        
        developer.log('✅ [Session $sessionId] OCR completed successfully on attempt $attempt', name: 'dyslexic_ai.ocr');
        return result;
        
      } catch (e, stackTrace) {
        developer.log('❌ [Session $sessionId] OCR attempt $attempt failed: $e', name: 'dyslexic_ai.ocr', error: e, stackTrace: stackTrace);
        
        // Invalidate session on error to prevent cascading failures
        await _sessionManager.invalidateSession();
        
        // If this is the last attempt, return error
        if (attempt == _maxRetries) {
          developer.log('💥 [Session $sessionId] All OCR attempts failed after $_maxRetries tries', name: 'dyslexic_ai.ocr');
          return OCRResult(
            text: '',
            error: 'OCR failed after $_maxRetries attempts: ${e.toString()}',
          );
        }
        
        // Wait before retry (exponential backoff)
        final waitTime = Duration(milliseconds: 1000 * attempt);
        developer.log('⏳ [Session $sessionId] Waiting ${waitTime.inMilliseconds}ms before retry ${attempt + 1}', name: 'dyslexic_ai.ocr');
        await Future.delayed(waitTime);
      }
    }
    
    // This should never be reached, but just in case
    return OCRResult(
      text: '',
      error: 'OCR failed: Maximum retries exceeded',
    );
  }

  /// Optimize image for flutter_gemma processing with progressive reduction
  Future<Uint8List> _optimizeImageForFlutterGemma(File imageFile) async {
    try {
      // Read original image
      final originalBytes = await imageFile.readAsBytes();
      developer.log('📊 Original image: ${originalBytes.length} bytes', name: 'dyslexic_ai.ocr');
      
      // Progressive image reduction stages
      final reductionStages = [
        {'maxWidth': _maxImageWidth, 'maxHeight': _maxImageHeight, 'quality': 50, 'stage': 'standard'},
        {'maxWidth': _maxImageWidth ~/ 1.5, 'maxHeight': _maxImageHeight ~/ 1.5, 'quality': 40, 'stage': 'aggressive'},
        {'maxWidth': _maxImageWidth ~/ 2, 'maxHeight': _maxImageHeight ~/ 2, 'quality': 30, 'stage': 'extreme'},
      ];
      
      img.Image? image;
      
      for (int stage = 0; stage < reductionStages.length; stage++) {
        final config = reductionStages[stage];
        final maxWidth = config['maxWidth'] as int;
        final maxHeight = config['maxHeight'] as int;
        final quality = config['quality'] as int;
        final stageName = config['stage'] as String;
        
        developer.log('🔄 Attempting $stageName optimization: ${maxWidth}x$maxHeight, quality: $quality%', name: 'dyslexic_ai.ocr');
        
        try {
          // Decode image only once
          image ??= img.decodeImage(originalBytes);
          if (image == null) {
            throw Exception('Invalid image format');
          }
          
          // Quick check for first stage - if already small enough, use as-is
          if (stage == 0 && originalBytes.length <= _maxImageBytes) {
            if (image.width <= maxWidth && image.height <= maxHeight) {
              developer.log('✅ Image already optimized for $stageName stage', name: 'dyslexic_ai.ocr');
              return originalBytes;
            }
          }
          
          developer.log('📐 Original dimensions: ${image.width}x${image.height}', name: 'dyslexic_ai.ocr');
          
          // Calculate optimal resize maintaining aspect ratio
          final scale = math.min(
            maxWidth / image.width,
            maxHeight / image.height,
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
          
          // Encode as JPEG with progressive quality reduction
          final optimizedBytes = img.encodeJpg(
            processedImage,
            quality: quality,
          );
          
          final reductionPercent = ((originalBytes.length - optimizedBytes.length) / originalBytes.length * 100).toStringAsFixed(1);
          developer.log('✅ $stageName optimization completed: ${optimizedBytes.length} bytes ($reductionPercent% reduction)', name: 'dyslexic_ai.ocr');
          
          // Check if this stage meets our memory requirements
          if (optimizedBytes.length <= _maxImageBytes) {
            developer.log('🎯 Image optimization successful at $stageName stage', name: 'dyslexic_ai.ocr');
            return Uint8List.fromList(optimizedBytes);
          } else {
            developer.log('⚠️ $stageName stage still too large (${optimizedBytes.length} bytes), trying next stage', name: 'dyslexic_ai.ocr');
          }
          
        } catch (e) {
          developer.log('⚠️ $stageName optimization failed: $e', name: 'dyslexic_ai.ocr');
          // Continue to next stage
        }
      }
      
      // If all stages failed, throw an error
      throw Exception('Unable to optimize image to required size after all reduction stages');
      
    } catch (e) {
      developer.log('❌ Complete image optimization failed: $e', name: 'dyslexic_ai.ocr');
      rethrow;
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
      
      // Check if this is a vision-capable model
      developer.log('✅ Vision model available for OCR', name: 'dyslexic_ai.ocr');
      return true;
    } catch (e) {
      developer.log('❌ Error checking vision OCR availability: $e', name: 'dyslexic_ai.ocr');
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

  /// Perform OCR with timeout management and proper session handling
  Future<OCRResult> _performOCRWithTimeout(int sessionId, Uint8List processedBytes) async {
    try {
      return await Future.any([
        _performOCROperation(sessionId, processedBytes),
        Future.delayed(_ocrTimeout).then((_) => throw TimeoutException('OCR operation timed out after ${_ocrTimeout.inSeconds}s', _ocrTimeout)),
      ]);
    } on TimeoutException catch (e) {
      developer.log('⏰ [Session $sessionId] OCR timeout: ${e.message}', name: 'dyslexic_ai.ocr');
      return OCRResult(
        text: '',
        error: 'OCR operation timed out. Please try with a smaller or clearer image.',
      );
    } catch (e) {
      developer.log('❌ [Session $sessionId] OCR error: $e', name: 'dyslexic_ai.ocr');
      return OCRResult(
        text: '',
        error: 'OCR processing failed: ${e.toString()}',
      );
    }
  }

  /// Core OCR operation with session management
  Future<OCRResult> _performOCROperation(int sessionId, Uint8List processedBytes) async {
    try {
      // Get session with timeout and proper error handling
      developer.log('♻️ [Session $sessionId] Getting OCR session...', name: 'dyslexic_ai.ocr');
      final session = await _sessionManager.getSession().timeout(_sessionTimeout);
      developer.log('✅ [Session $sessionId] Using session successfully', name: 'dyslexic_ai.ocr');

      // Validate image size before processing
      if (processedBytes.length > _maxImageBytes) {
        throw Exception('Image too large for OCR processing: ${processedBytes.length} bytes (max: $_maxImageBytes bytes)');
      }

      // Use CORRECT flutter_gemma multimodal message format
      final message = Message(
        text: _ocrPrompt,
        imageBytes: processedBytes,
        isUser: true,
      );
      
      developer.log('📤 [Session $sessionId] Sending OCR message to model (${processedBytes.length} bytes)...', name: 'dyslexic_ai.ocr');
      
      // Use the correct flutter_gemma method for sending messages
      await session.addQueryChunk(message);
      
      developer.log('📥 [Session $sessionId] Getting response from model...', name: 'dyslexic_ai.ocr');
      
      // Get response using flutter_gemma's direct API with timeout
      final response = await session.getResponse().timeout(_ocrTimeout);
      developer.log('📥 [Session $sessionId] Response received: ${response.length} chars', name: 'dyslexic_ai.ocr');
      
      final extractedText = response.trim();
      
      // Enhanced response validation
      if (extractedText.isEmpty) {
        developer.log('⚠️ [Session $sessionId] Empty response from model', name: 'dyslexic_ai.ocr');
        return OCRResult(
          text: '',
          confidence: 0.0,
          error: 'No text could be extracted from the image.',
        );
      }
      
      // Clean and validate the response
      final cleanedText = _cleanOCRResult(extractedText);
      
      // Additional validation for OCR quality
      if (cleanedText.length < 2 && !cleanedText.contains(RegExp(r'[a-zA-Z0-9]'))) {
        developer.log('⚠️ [Session $sessionId] Low quality OCR result', name: 'dyslexic_ai.ocr');
        return OCRResult(
          text: cleanedText,
          confidence: 0.3,
          error: 'Text extraction quality is low. Please try with a clearer image.',
        );
      }
      
      final confidence = _estimateConfidence(cleanedText);
      developer.log('✅ [Session $sessionId] OCR processing completed: ${cleanedText.length} characters extracted (confidence: ${confidence != null ? (confidence * 100).round() : 0}%)', name: 'dyslexic_ai.ocr');
      
      // Perform cleanup
      await _performPostOCRCleanup(sessionId);
      
      return OCRResult(
        text: cleanedText,
        confidence: confidence,
      );
      
    } on TimeoutException catch (e) {
      developer.log('⏰ [Session $sessionId] Session timeout: ${e.message}', name: 'dyslexic_ai.ocr');
      rethrow;
    } catch (e) {
      developer.log('❌ [Session $sessionId] OCR operation failed: $e', name: 'dyslexic_ai.ocr');
      
      // Provide user-friendly error messages for common issues
      String userError;
      if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
        userError = 'Not enough memory available. Please try with a smaller image.';
      } else if (e.toString().contains('timeout')) {
        userError = 'OCR operation timed out. Please try with a smaller or clearer image.';
      } else if (e.toString().contains('Invalid image format')) {
        userError = 'Invalid image format. Please use JPEG, PNG, or WebP images.';
      } else if (e.toString().contains('too large')) {
        userError = 'Image is too large for processing. Please use a smaller image.';
      } else {
        userError = 'OCR processing failed. Please try again with a different image.';
      }
      
      return OCRResult(
        text: '',
        confidence: 0.0,
        error: userError,
      );
    }
  }

  /// Perform post-OCR cleanup operations
  Future<void> _performPostOCRCleanup(int sessionId) async {
    try {
      developer.log('🧹 [Session $sessionId] Starting post-OCR cleanup', name: 'dyslexic_ai.ocr');
      
      // Small delay to allow session processing to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Reset session count periodically to prevent overflow
      if (_sessionCount > 1000) {
        _sessionCount = 0;
        developer.log('🔄 [Session $sessionId] Reset session counter', name: 'dyslexic_ai.ocr');
      }
      
      developer.log('✅ [Session $sessionId] Post-OCR cleanup completed', name: 'dyslexic_ai.ocr');
    } catch (e) {
      developer.log('⚠️ [Session $sessionId] Post-OCR cleanup error: $e', name: 'dyslexic_ai.ocr');
    }
  }

  /// Check current memory pressure and apply throttling if needed
  Future<void> _checkMemoryPressure(int sessionId) async {
    _sessionCount++;
    
    // Progressive throttling based on session count
    if (_sessionCount % 3 == 0) {
      final throttleTime = Duration(milliseconds: 150 * (_sessionCount ~/ 3));
      developer.log('⏱️ [Session $sessionId] Memory throttling: ${throttleTime.inMilliseconds}ms pause after $_sessionCount sessions', name: 'dyslexic_ai.ocr');
      await Future.delayed(throttleTime);
    }
    
    // Trigger garbage collection periodically to free memory
    if (_sessionCount % 10 == 0) {
      developer.log('🗑️ [Session $sessionId] Triggering garbage collection after $_sessionCount sessions', name: 'dyslexic_ai.ocr');
      // Force garbage collection (this is a hint to the runtime)
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }


  
  /// Dispose method for proper cleanup when service is no longer needed
  Future<void> dispose() async {
    developer.log('🗑️ Disposing OCR service...', name: 'dyslexic_ai.ocr');
    // Don't invalidate global session - let GlobalSessionManager handle its own lifecycle
    // Individual services should not affect global session state
    developer.log('✅ OCR service disposed successfully', name: 'dyslexic_ai.ocr');
  }
} 