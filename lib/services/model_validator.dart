import 'dart:developer' as developer;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

enum ValidationResult {
  valid,
  fileNotFound,
  sizeMismatch,
  corrupted,
  unknownError
}

class FileValidationResult {
  final ValidationResult result;
  final String? error;
  final int? actualSize;
  final int? expectedSize;

  const FileValidationResult({
    required this.result,
    this.error,
    this.actualSize,
    this.expectedSize,
  });

  bool get isValid => result == ValidationResult.valid;
  bool get isCorrupted => result == ValidationResult.sizeMismatch || result == ValidationResult.corrupted;
}

class ModelValidator {
  static const String _expectedSizeCacheKey = 'expected_model_size';

  /// Validate model file integrity
  /// This method determines if a file is actually corrupted vs just having initialization issues
  Future<FileValidationResult> validateModelFile(String modelPath) async {
    try {
      developer.log('🔍 Validating model file: $modelPath', name: 'dyslexic_ai.model_validator');
      
      final file = File(modelPath);
      
      // Check if file exists
      if (!file.existsSync()) {
        developer.log('❌ Model file does not exist', name: 'dyslexic_ai.model_validator');
        return const FileValidationResult(
          result: ValidationResult.fileNotFound,
          error: 'Model file does not exist',
        );
      }

      // Get actual file size
      final actualSize = await file.length();
      developer.log('📊 Actual file size: ${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB', 
                   name: 'dyslexic_ai.model_validator');

      // Check if file is empty
      if (actualSize == 0) {
        developer.log('❌ Model file is empty', name: 'dyslexic_ai.model_validator');
        return FileValidationResult(
          result: ValidationResult.corrupted,
          error: 'Model file is empty',
          actualSize: actualSize,
        );
      }

      // Get expected size from cache or server
      final expectedSize = await _getExpectedModelSize();
      if (expectedSize == null) {
        developer.log('⚠️ Cannot validate file size - no expected size available', 
                     name: 'dyslexic_ai.model_validator');
        
        // If we can't validate size, assume file is valid if it exists and has content
        // This prevents unnecessary deletions when server is unreachable
        return FileValidationResult(
          result: ValidationResult.valid,
          actualSize: actualSize,
        );
      }

      developer.log('📏 Expected file size: ${(expectedSize / (1024 * 1024)).toStringAsFixed(1)}MB', 
                   name: 'dyslexic_ai.model_validator');

      // Validate file size matches exactly
      if (actualSize != expectedSize) {
        final error = 'File size mismatch - Expected: ${(expectedSize / (1024 * 1024)).toStringAsFixed(1)}MB, '
                     'Actual: ${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB';
        developer.log('❌ $error', name: 'dyslexic_ai.model_validator');
        
        return FileValidationResult(
          result: ValidationResult.sizeMismatch,
          error: error,
          actualSize: actualSize,
          expectedSize: expectedSize,
        );
      }

      // File passed all validation checks
      developer.log('✅ Model file validation passed', name: 'dyslexic_ai.model_validator');
      return FileValidationResult(
        result: ValidationResult.valid,
        actualSize: actualSize,
        expectedSize: expectedSize,
      );

    } catch (e) {
      final error = 'Error during file validation: $e';
      developer.log('❌ $error', name: 'dyslexic_ai.model_validator');
      
      return FileValidationResult(
        result: ValidationResult.unknownError,
        error: error,
      );
    }
  }

  /// Check if a file exists and has basic validity (non-empty)
  /// This is a lightweight check that doesn't require server validation
  Future<bool> isFileBasicallyValid(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!file.existsSync()) return false;
      
      final size = await file.length();
      return size > 0;
    } catch (e) {
      developer.log('❌ Error in basic file check: $e', name: 'dyslexic_ai.model_validator');
      return false;
    }
  }

  /// Get expected model size from cache or server
  /// Returns null if unable to determine expected size
  Future<int?> _getExpectedModelSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First try to get cached expected size
      final cachedSize = prefs.getInt(_expectedSizeCacheKey);
      if (cachedSize != null) {
        developer.log('📦 Using cached expected size: ${(cachedSize / (1024 * 1024)).toStringAsFixed(1)}MB', 
                     name: 'dyslexic_ai.model_validator');
        return cachedSize;
      }

      developer.log('⚠️ No cached expected size available', name: 'dyslexic_ai.model_validator');
      return null;
      
    } catch (e) {
      developer.log('❌ Error getting expected model size: $e', name: 'dyslexic_ai.model_validator');
      return null;
    }
  }

  /// Check if a model file should be considered corrupted and deleted
  /// This provides a conservative approach - only delete files that are clearly corrupted
  Future<bool> shouldDeleteCorruptedFile(String modelPath) async {
    final validation = await validateModelFile(modelPath);
    
    switch (validation.result) {
      case ValidationResult.valid:
        return false; // File is valid, don't delete
        
      case ValidationResult.fileNotFound:
        return false; // File doesn't exist, nothing to delete
        
      case ValidationResult.sizeMismatch:
        // Only delete if size is significantly wrong (not just a few bytes off)
        if (validation.actualSize != null && validation.expectedSize != null) {
          final sizeDiff = (validation.actualSize! - validation.expectedSize!).abs();
          final sizeDiffPercent = sizeDiff / validation.expectedSize! * 100;
          
          // Delete if size difference is more than 1%
          final shouldDelete = sizeDiffPercent > 1.0;
          developer.log('📊 Size difference: ${sizeDiffPercent.toStringAsFixed(2)}%, shouldDelete: $shouldDelete', 
                       name: 'dyslexic_ai.model_validator');
          return shouldDelete;
        }
        return true; // If we can't determine sizes, assume corruption
        
      case ValidationResult.corrupted:
        return true; // File is clearly corrupted (empty, etc.)
        
      case ValidationResult.unknownError:
        return false; // When in doubt, don't delete - preserve user's download
    }
  }

  /// Clear cached validation data (useful when starting fresh download)
  Future<void> clearValidationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_expectedSizeCacheKey);
      developer.log('🧹 Cleared validation cache', name: 'dyslexic_ai.model_validator');
    } catch (e) {
      developer.log('❌ Error clearing validation cache: $e', name: 'dyslexic_ai.model_validator');
    }
  }
} 