import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';
import '../services/reading_analysis_service.dart';
import '../services/word_analysis_service.dart';
import '../services/personal_dictionary_service.dart';
import '../services/ai_inference_service.dart';
import '../services/font_preference_service.dart';
import '../services/global_session_manager.dart';
import '../controllers/reading_coach_store.dart';
import '../controllers/word_doctor_store.dart';
import '../controllers/adaptive_story_store.dart';
import '../controllers/phonics_game_store.dart';
import '../controllers/learner_profile_store.dart';
import '../controllers/session_log_store.dart';
import '../controllers/text_simplifier_store.dart';
import '../controllers/sentence_fixer_store.dart';
import '../services/story_service.dart';
import '../services/phonics_sounds_service.dart';
import '../services/model_download_service.dart';
import '../services/background_download_manager.dart';
import '../services/download_notification_service.dart';
import '../services/session_logging_service.dart';
import '../services/gemma_profile_update_service.dart';
import '../services/text_simplifier_service.dart';
import '../services/ai_phonics_generation_service.dart';
import 'dart:developer' as developer;

// Conditional logging - automatically disabled in production builds
void debugLog(String message, {String? name}) {
  if (kDebugMode) {
    developer.log(message, name: name ?? 'dyslexic_ai');
  }
}

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  await Hive.initFlutter();

  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Register global session manager (must be early for other services to use)
  getIt.registerSingleton<GlobalSessionManager>(GlobalSessionManager());

  // Register font preference service
  getIt.registerLazySingleton<FontPreferenceService>(
      () => FontPreferenceService());

  getIt.registerFactory<SpeechRecognitionService>(
      () => SpeechRecognitionService());
  getIt.registerFactory<TextToSpeechService>(() => TextToSpeechService());
  getIt.registerLazySingleton<OcrService>(() => OcrService());
  getIt.registerLazySingleton<ReadingAnalysisService>(
      () => ReadingAnalysisService());
  getIt.registerLazySingleton<WordAnalysisService>(() => WordAnalysisService());
  getIt.registerLazySingleton<PersonalDictionaryService>(
      () => PersonalDictionaryService());
  getIt.registerLazySingleton<StoryService>(() => StoryService());
  getIt.registerLazySingleton<PhonicsSoundsService>(
      () => PhonicsSoundsService());
  getIt.registerLazySingleton<AIPhonicsGenerationService>(
      () => AIPhonicsGenerationService());
  getIt.registerLazySingleton<ModelDownloadService>(
      () => ModelDownloadService());

  // Register background download services
  getIt.registerSingleton<BackgroundDownloadManager>(BackgroundDownloadManager.instance);
  getIt.registerSingleton<DownloadNotificationService>(DownloadNotificationService.instance);

  // Register new learner profiler services
  getIt.registerLazySingleton<SessionLogStore>(() => SessionLogStore());
  getIt.registerLazySingleton<LearnerProfileStore>(() => LearnerProfileStore());
  getIt.registerLazySingleton<SessionLoggingService>(
      () => SessionLoggingService());
  getIt.registerLazySingleton<GemmaProfileUpdateService>(
      () => GemmaProfileUpdateService());
  
  // Register text simplifier service
  getIt.registerLazySingleton<TextSimplifierService>(
      () => TextSimplifierService());

  // Initialize font preference service
  await getIt<FontPreferenceService>().init();

  // Initialize learner profiler stores
  await getIt<SessionLogStore>().initialize();
  await getIt<LearnerProfileStore>().initialize();
  
  // Initialize text simplifier service
  getIt<TextSimplifierService>().initialize();

  // Initialize background download services
  await getIt<BackgroundDownloadManager>().initialize();
  await getIt<DownloadNotificationService>().initialize();
  
  // Clean up any orphaned background tasks on app startup
  await getIt<BackgroundDownloadManager>().validateAndCleanupBackgroundTasks();

  getIt.registerFactory<ReadingCoachStore>(() => ReadingCoachStore());

  getIt.registerFactory<WordDoctorStore>(() => WordDoctorStore(
        analysisService: getIt<WordAnalysisService>(),
        dictionaryService: getIt<PersonalDictionaryService>(),
        ttsService: getIt<TextToSpeechService>(),
        ocrService: getIt<OcrService>(),
      ));

  getIt.registerFactory<AdaptiveStoryStore>(() => AdaptiveStoryStore(
        storyService: getIt<StoryService>(),
        ttsService: getIt<TextToSpeechService>(),
      ));

  getIt.registerFactory<PhonicsGameStore>(() => PhonicsGameStore());
  
  getIt.registerFactory<TextSimplifierStore>(() => TextSimplifierStore());
  
  getIt.registerFactory<SentenceFixerStore>(() => SentenceFixerStore());
}

/// Helper function to get the GlobalSessionManager
GlobalSessionManager getGlobalSessionManager() {
  return getIt<GlobalSessionManager>();
}

/// Helper function to get AI inference service if available
/// This will reuse the singleton instance if already created
AIInferenceService? getAIInferenceService() {
  try {
    debugLog('🔍 Getting AI inference service...');

    // Check if we already have a registered singleton
    if (getIt.isRegistered<AIInferenceService>()) {
      debugLog('✅ Reusing existing AIInferenceService singleton');
      return getIt<AIInferenceService>();
    }

    final plugin = FlutterGemmaPlugin.instance;
    debugLog('📚 Got flutter_gemma plugin: ${plugin.runtimeType}');

    final inferenceModel = plugin.initializedModel;
    debugLog(
        '🤖 Initialized model: ${inferenceModel?.runtimeType ?? 'null'}');

    if (inferenceModel != null) {
      debugLog('✅ Creating new AIInferenceService singleton');
      final service = AIInferenceService(inferenceModel);
      getIt.registerSingleton<AIInferenceService>(service);
      return service;
    } else {
      debugLog('❌ No initialized model available');
      return null;
    }
  } catch (e) {
    debugLog('❌ Error getting AI service: $e');
    return null;
  }
}
