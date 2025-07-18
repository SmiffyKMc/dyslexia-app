import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:get_it/get_it.dart';

typedef DownloadProgressCallback = void Function(double progress);
typedef DownloadErrorCallback = void Function(String error);
typedef DownloadSuccessCallback = void Function();

class ModelDownloadService {
  final _gemmaPlugin = FlutterGemmaPlugin.instance;
  final _dio = Dio();
  
  static const String _prefsKeyModelDownloaded = 'dyslexic_ai_model_downloaded';
  static const String _prefsKeyModelPath = 'dyslexic_ai_model_path';
  static const String _modelFileName = 'gemma-3n-E2B-it-int4.task';
  static const String _modelUrl = 'https://kaggle-gemma3.b-cdn.net/gemma-3n-E2B-it-int4.task';
  
  bool isModelReady = false;
  String? downloadError;
  double downloadProgress = 0.0;
  
  ModelDownloadService() {
    // Configure Dio for large file downloads
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 30);
    _dio.options.sendTimeout = const Duration(minutes: 30);
    _dio.options.headers = {
      'Accept': '*/*',
      'User-Agent': 'Flutter-App-DyslexicAI/1.0',
    };
    
    developer.log('📚 ModelDownloadService initialized', name: 'dyslexic_ai.model_download');
  }
  
  Future<bool> isModelAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool(_prefsKeyModelDownloaded) ?? false;
    final modelPath = prefs.getString(_prefsKeyModelPath);
    
    developer.log('🔍 Model availability check - Downloaded: $isDownloaded, Path: $modelPath', name: 'dyslexic_ai.model_download');
    
    if (isDownloaded && modelPath != null) {
      final file = File(modelPath);
      final exists = file.existsSync();
      developer.log('📁 Model file exists: $exists', name: 'dyslexic_ai.model_download');
      return exists;
    }
    
    return false;
  }

  Future<String> _getModelFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(appDir.path, 'models'));
    
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
      developer.log('📁 Created models directory: ${modelDir.path}', name: 'dyslexic_ai.model_download');
    }
    
    final modelPath = path.join(modelDir.path, _modelFileName);
    developer.log('📍 Model path: $modelPath', name: 'dyslexic_ai.model_download');
    return modelPath;
  }

  Future<bool> _downloadWithDio(String url, String savePath, DownloadProgressCallback? onProgress) async {
    try {
      developer.log('🌐 Starting Dio download from: $url', name: 'dyslexic_ai.model_download');
      developer.log('💾 Saving to: $savePath', name: 'dyslexic_ai.model_download');
      
      // Clean up any existing file
      final file = File(savePath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted existing file', name: 'dyslexic_ai.model_download');
      }
      
      // Ensure directory exists
      await file.parent.create(recursive: true);
      
      // Download the file
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final progressPercent = (progress * 100).toStringAsFixed(1);
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            
            developer.log('📥 Download progress: $progressPercent% ($receivedMB/$totalMB MB)', name: 'dyslexic_ai.model_download');
            onProgress?.call(progress);
          }
        },
      );
      
      // Verify the file was created and has content
      if (!file.existsSync()) {
        throw Exception('Download completed but file was not created');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Download completed but file is empty');
      }
      
      developer.log('✅ Download completed successfully. File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB', name: 'dyslexic_ai.model_download');
      return true;
      
    } catch (e) {
      developer.log('❌ Dio download failed: $e', name: 'dyslexic_ai.model_download');
      
      // Clean up failed download
      final file = File(savePath);
      if (file.existsSync()) {
        try {
          await file.delete();
          developer.log('🗑️ Cleaned up failed download', name: 'dyslexic_ai.model_download');
        } catch (cleanupError) {
          developer.log('⚠️ Failed to clean up: $cleanupError', name: 'dyslexic_ai.model_download');
        }
      }
      
      return false;
    }
  }

  Future<bool> _setModelPathInFlutterGemma(String modelPath) async {
    try {
      developer.log('🔧 Setting model path in flutter_gemma: $modelPath', name: 'dyslexic_ai.model_download');
      
      // Check if file exists before setting path
      final file = File(modelPath);
      if (!file.existsSync()) {
        developer.log('❌ Model file does not exist before setting path', name: 'dyslexic_ai.model_download');
        return false;
      }
      
      final fileSize = await file.length();
      developer.log('📊 Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB', name: 'dyslexic_ai.model_download');
      
      // Get flutter_gemma model manager
      final modelManager = _gemmaPlugin.modelManager;
      developer.log('📚 Got flutter_gemma model manager: ${modelManager.runtimeType}', name: 'dyslexic_ai.model_download');
      
      // Check current installation status
      final isCurrentlyInstalled = await modelManager.isModelInstalled;
      developer.log('📋 Current installation status: $isCurrentlyInstalled', name: 'dyslexic_ai.model_download');
      
      // Set the model path
      developer.log('⚙️ Calling setModelPath...', name: 'dyslexic_ai.model_download');
      await modelManager.setModelPath(modelPath);
      
      // Check if path was set successfully
      final isNowInstalled = await modelManager.isModelInstalled;
      developer.log('✅ Model installation status after setModelPath: $isNowInstalled', name: 'dyslexic_ai.model_download');
      
      if (!isNowInstalled) {
        developer.log('❌ Model path setting failed', name: 'dyslexic_ai.model_download');
        return false;
      }
      
      // Now initialize the model for inference
      developer.log('🚀 Initializing model for inference...', name: 'dyslexic_ai.model_download');
      
      try {
        Future<InferenceModel?> _createModelWithFallback() async {
          try {
            return await _gemmaPlugin.createModel(
              modelType: ModelType.gemmaIt,
              preferredBackend: PreferredBackend.gpu, // Try GPU first
              maxTokens: 2048,
              supportImage: true,
              maxNumImages: 1,
            );
          } catch (gpuError) {
            developer.log('GPU backend failed, falling back to CPU: $gpuError', name: 'dyslexic_ai.model_download');
            return await _gemmaPlugin.createModel(
              modelType: ModelType.gemmaIt,
              preferredBackend: PreferredBackend.cpu, // CPU fallback
              maxTokens: 2048,
              supportImage: true,
              maxNumImages: 1,
            );
          }
        }

        final inferenceModel = await _createModelWithFallback();
        if (inferenceModel != null) {
          developer.log('✅ Model initialized successfully for inference', name: 'dyslexic_ai.model_download');
          
          // Register the model with the service locator
          final getIt = GetIt.instance;
          if (getIt.isRegistered<InferenceModel>()) {
            getIt.unregister<InferenceModel>();
          }
          getIt.registerSingleton<InferenceModel>(inferenceModel);
          
          // Note: AIInferenceService will be created on-demand by service locator
          developer.log('✅ Model registered successfully', name: 'dyslexic_ai.model_download');
          return true;
        } else {
          developer.log('❌ Model initialization returned null', name: 'dyslexic_ai.model_download');
          return false;
        }
      } catch (initError) {
        developer.log('❌ Error during model initialization: $initError', name: 'dyslexic_ai.model_download');
        return false;
      }
      
    } catch (e) {
      developer.log('❌ Error setting model path: $e', name: 'dyslexic_ai.model_download');
      return false;
    }
  }
  
  Future<void> downloadModelIfNeeded({
    DownloadProgressCallback? onProgress,
    DownloadErrorCallback? onError,
    DownloadSuccessCallback? onSuccess,
  }) async {
    developer.log('🚀 Starting model download process...', name: 'dyslexic_ai.model_download');
    
    downloadError = null;
    downloadProgress = 0.0;
    onProgress?.call(0.0);
    
    try {
      // Check if model is already available
      if (await isModelAvailable()) {
        developer.log('✅ Model already available, loading existing model...', name: 'dyslexic_ai.model_download');
        
        final prefs = await SharedPreferences.getInstance();
        final existingPath = prefs.getString(_prefsKeyModelPath);
        
        if (existingPath != null) {
          // Signal UI to switch to circular progress for model initialization
          onProgress?.call(-1.0);
          
          final success = await _setModelPathInFlutterGemma(existingPath);
          if (success) {
            isModelReady = true;
            downloadProgress = 1.0;
            onProgress?.call(1.0);
            onSuccess?.call();
            return;
          } else {
            developer.log('⚠️ Failed to load existing model, will re-download', name: 'dyslexic_ai.model_download');
          }
        }
      }
      
      // Download the model
      developer.log('📥 Starting model download...', name: 'dyslexic_ai.model_download');
      final modelPath = await _getModelFilePath();
      
      final downloadSuccess = await _downloadWithDio(
        _modelUrl,
        modelPath,
        (progress) {
          downloadProgress = progress;
          onProgress?.call(progress);
        },
      );
      
      if (!downloadSuccess) {
        throw Exception('Failed to download model file');
      }
      
      // Set the model path in flutter_gemma
      developer.log('🔧 Setting up model in flutter_gemma...', name: 'dyslexic_ai.model_download');
      
      // Signal UI to switch to circular progress for model initialization
      onProgress?.call(-1.0);
      
      final setupSuccess = await _setModelPathInFlutterGemma(modelPath);
      
      if (!setupSuccess) {
        throw Exception('Failed to set model path in flutter_gemma');
      }
      
      // Save success state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyModelDownloaded, true);
      await prefs.setString(_prefsKeyModelPath, modelPath);
      
      isModelReady = true;
      downloadProgress = 1.0;
      onProgress?.call(1.0);
      
      developer.log('🎉 Model download and setup completed successfully!', name: 'dyslexic_ai.model_download');
      onSuccess?.call();
      
    } catch (e, stackTrace) {
      final errorString = 'Model download failed: $e';
      developer.log(errorString, name: 'dyslexic_ai.model_download', error: e, stackTrace: stackTrace);
      downloadError = errorString;
      onError?.call(errorString);
    }
  }
  
  Future<void> clearModelData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyModelDownloaded);
    await prefs.remove(_prefsKeyModelPath);
    
    // Also try to delete the actual file
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted model file', name: 'dyslexic_ai.model_download');
      }
    } catch (e) {
      developer.log('⚠️ Error deleting model file: $e', name: 'dyslexic_ai.model_download');
    }
    
    isModelReady = false;
    downloadProgress = 0.0;
    downloadError = null;
    developer.log('🧹 Model data cleared', name: 'dyslexic_ai.model_download');
  }
} 