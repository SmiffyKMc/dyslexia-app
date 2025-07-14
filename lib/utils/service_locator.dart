import 'package:get_it/get_it.dart';
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
import '../services/story_service.dart';
import '../services/phonics_sounds_service.dart';
import '../services/model_download_service.dart';
import '../services/session_logging_service.dart';
import '../services/gemma_profile_update_service.dart';
import 'dart:developer' as developer;

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
  getIt.registerLazySingleton<ModelDownloadService>(
      () => ModelDownloadService());

  // Register new learner profiler services
  getIt.registerLazySingleton<SessionLogStore>(() => SessionLogStore());
  getIt.registerLazySingleton<LearnerProfileStore>(() => LearnerProfileStore());
  getIt.registerLazySingleton<SessionLoggingService>(
      () => SessionLoggingService());
  getIt.registerLazySingleton<GemmaProfileUpdateService>(
      () => GemmaProfileUpdateService());

  // Initialize font preference service
  await getIt<FontPreferenceService>().init();

  // Initialize learner profiler stores
  await getIt<SessionLogStore>().initialize();
  await getIt<LearnerProfileStore>().initialize();

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
}

/// Helper function to get the GlobalSessionManager
GlobalSessionManager getGlobalSessionManager() {
  return getIt<GlobalSessionManager>();
}

/// Helper function to get AI inference service if available
/// This will reuse the singleton instance if already created
AIInferenceService? getAIInferenceService() {
  try {
    developer.log('🔍 Getting AI inference service...',
        name: 'dyslexic_ai.service_locator');

    // Check if we already have a registered singleton
    if (getIt.isRegistered<AIInferenceService>()) {
      developer.log('✅ Reusing existing AIInferenceService singleton',
          name: 'dyslexic_ai.service_locator');
      return getIt<AIInferenceService>();
    }

    final plugin = FlutterGemmaPlugin.instance;
    developer.log('📚 Got flutter_gemma plugin: ${plugin.runtimeType}',
        name: 'dyslexic_ai.service_locator');

    final inferenceModel = plugin.initializedModel;
    developer.log(
        '🤖 Initialized model: ${inferenceModel?.runtimeType ?? 'null'}',
        name: 'dyslexic_ai.service_locator');

    if (inferenceModel != null) {
      developer.log('✅ Creating new AIInferenceService singleton',
          name: 'dyslexic_ai.service_locator');
      final service = AIInferenceService(inferenceModel);
      getIt.registerSingleton<AIInferenceService>(service);
      return service;
    } else {
      developer.log('❌ No initialized model available',
          name: 'dyslexic_ai.service_locator');
      return null;
    }
  } catch (e) {
    developer.log('❌ Error getting AI service: $e',
        name: 'dyslexic_ai.service_locator');
    return null;
  }
}
