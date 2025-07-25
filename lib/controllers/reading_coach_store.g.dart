// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_coach_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ReadingCoachStore on _ReadingCoachStore, Store {
  Computed<double>? _$currentAccuracyComputed;

  @override
  double get currentAccuracy => (_$currentAccuracyComputed ??= Computed<double>(
          () => super.currentAccuracy,
          name: '_ReadingCoachStore.currentAccuracy'))
      .value;
  Computed<String>? _$formattedAccuracyComputed;

  @override
  String get formattedAccuracy => (_$formattedAccuracyComputed ??=
          Computed<String>(() => super.formattedAccuracy,
              name: '_ReadingCoachStore.formattedAccuracy'))
      .value;
  Computed<bool>? _$canStartReadingComputed;

  @override
  bool get canStartReading =>
      (_$canStartReadingComputed ??= Computed<bool>(() => super.canStartReading,
              name: '_ReadingCoachStore.canStartReading'))
          .value;
  Computed<bool>? _$hasSessionComputed;

  @override
  bool get hasSession =>
      (_$hasSessionComputed ??= Computed<bool>(() => super.hasSession,
              name: '_ReadingCoachStore.hasSession'))
          .value;
  Computed<String>? _$recordingStatusTextComputed;

  @override
  String get recordingStatusText => (_$recordingStatusTextComputed ??=
          Computed<String>(() => super.recordingStatusText,
              name: '_ReadingCoachStore.recordingStatusText'))
      .value;
  Computed<List<bool>>? _$wordHighlightStatesComputed;

  @override
  List<bool> get wordHighlightStates => (_$wordHighlightStatesComputed ??=
          Computed<List<bool>>(() => super.wordHighlightStates,
              name: '_ReadingCoachStore.wordHighlightStates'))
      .value;

  late final _$currentTextAtom =
      Atom(name: '_ReadingCoachStore.currentText', context: context);

  @override
  String get currentText {
    _$currentTextAtom.reportRead();
    return super.currentText;
  }

  @override
  set currentText(String value) {
    _$currentTextAtom.reportWrite(value, super.currentText, () {
      super.currentText = value;
    });
  }

  late final _$currentSessionAtom =
      Atom(name: '_ReadingCoachStore.currentSession', context: context);

  @override
  ReadingSession? get currentSession {
    _$currentSessionAtom.reportRead();
    return super.currentSession;
  }

  @override
  set currentSession(ReadingSession? value) {
    _$currentSessionAtom.reportWrite(value, super.currentSession, () {
      super.currentSession = value;
    });
  }

  late final _$recognizedSpeechAtom =
      Atom(name: '_ReadingCoachStore.recognizedSpeech', context: context);

  @override
  String get recognizedSpeech {
    _$recognizedSpeechAtom.reportRead();
    return super.recognizedSpeech;
  }

  @override
  set recognizedSpeech(String value) {
    _$recognizedSpeechAtom.reportWrite(value, super.recognizedSpeech, () {
      super.recognizedSpeech = value;
    });
  }

  late final _$isListeningAtom =
      Atom(name: '_ReadingCoachStore.isListening', context: context);

  @override
  bool get isListening {
    _$isListeningAtom.reportRead();
    return super.isListening;
  }

  @override
  set isListening(bool value) {
    _$isListeningAtom.reportWrite(value, super.isListening, () {
      super.isListening = value;
    });
  }

  late final _$recordingStatusAtom =
      Atom(name: '_ReadingCoachStore.recordingStatus', context: context);

  @override
  RecordingStatus get recordingStatus {
    _$recordingStatusAtom.reportRead();
    return super.recordingStatus;
  }

  @override
  set recordingStatus(RecordingStatus value) {
    _$recordingStatusAtom.reportWrite(value, super.recordingStatus, () {
      super.recordingStatus = value;
    });
  }

  late final _$silenceSecondsAtom =
      Atom(name: '_ReadingCoachStore.silenceSeconds', context: context);

  @override
  int get silenceSeconds {
    _$silenceSecondsAtom.reportRead();
    return super.silenceSeconds;
  }

  @override
  set silenceSeconds(int value) {
    _$silenceSecondsAtom.reportWrite(value, super.silenceSeconds, () {
      super.silenceSeconds = value;
    });
  }

  late final _$isAnalyzingAtom =
      Atom(name: '_ReadingCoachStore.isAnalyzing', context: context);

  @override
  bool get isAnalyzing {
    _$isAnalyzingAtom.reportRead();
    return super.isAnalyzing;
  }

  @override
  set isAnalyzing(bool value) {
    _$isAnalyzingAtom.reportWrite(value, super.isAnalyzing, () {
      super.isAnalyzing = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ReadingCoachStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_ReadingCoachStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$isGeneratingStoryAtom =
      Atom(name: '_ReadingCoachStore.isGeneratingStory', context: context);

  @override
  bool get isGeneratingStory {
    _$isGeneratingStoryAtom.reportRead();
    return super.isGeneratingStory;
  }

  @override
  set isGeneratingStory(bool value) {
    _$isGeneratingStoryAtom.reportWrite(value, super.isGeneratingStory, () {
      super.isGeneratingStory = value;
    });
  }

  late final _$liveFeedbackAtom =
      Atom(name: '_ReadingCoachStore.liveFeedback', context: context);

  @override
  List<String> get liveFeedback {
    _$liveFeedbackAtom.reportRead();
    return super.liveFeedback;
  }

  @override
  set liveFeedback(List<String> value) {
    _$liveFeedbackAtom.reportWrite(value, super.liveFeedback, () {
      super.liveFeedback = value;
    });
  }

  late final _$practiceWordsAtom =
      Atom(name: '_ReadingCoachStore.practiceWords', context: context);

  @override
  List<String> get practiceWords {
    _$practiceWordsAtom.reportRead();
    return super.practiceWords;
  }

  @override
  set practiceWords(List<String> value) {
    _$practiceWordsAtom.reportWrite(value, super.practiceWords, () {
      super.practiceWords = value;
    });
  }

  late final _$presetStoriesAtom =
      Atom(name: '_ReadingCoachStore.presetStories', context: context);

  @override
  List<PresetStory> get presetStories {
    _$presetStoriesAtom.reportRead();
    return super.presetStories;
  }

  @override
  set presetStories(List<PresetStory> value) {
    _$presetStoriesAtom.reportWrite(value, super.presetStories, () {
      super.presetStories = value;
    });
  }

  late final _$currentTextWordsAtom =
      Atom(name: '_ReadingCoachStore.currentTextWords', context: context);

  @override
  List<String> get currentTextWords {
    _$currentTextWordsAtom.reportRead();
    return super.currentTextWords;
  }

  @override
  set currentTextWords(List<String> value) {
    _$currentTextWordsAtom.reportWrite(value, super.currentTextWords, () {
      super.currentTextWords = value;
    });
  }

  late final _$recognizedWordsAtom =
      Atom(name: '_ReadingCoachStore.recognizedWords', context: context);

  @override
  List<String> get recognizedWords {
    _$recognizedWordsAtom.reportRead();
    return super.recognizedWords;
  }

  @override
  set recognizedWords(List<String> value) {
    _$recognizedWordsAtom.reportWrite(value, super.recognizedWords, () {
      super.recognizedWords = value;
    });
  }

  late final _$initializeAsyncAction =
      AsyncAction('_ReadingCoachStore.initialize', context: context);

  @override
  Future<void> initialize() {
    return _$initializeAsyncAction.run(() => super.initialize());
  }

  late final _$generateAIStoryAsyncAction =
      AsyncAction('_ReadingCoachStore.generateAIStory', context: context);

  @override
  Future<void> generateAIStory(dynamic Function(String) onTextUpdate) {
    return _$generateAIStoryAsyncAction
        .run(() => super.generateAIStory(onTextUpdate));
  }

  late final _$pickImageFromGalleryAsyncAction =
      AsyncAction('_ReadingCoachStore.pickImageFromGallery', context: context);

  @override
  Future<void> pickImageFromGallery() {
    return _$pickImageFromGalleryAsyncAction
        .run(() => super.pickImageFromGallery());
  }

  late final _$startReadingAsyncAction =
      AsyncAction('_ReadingCoachStore.startReading', context: context);

  @override
  Future<void> startReading() {
    return _$startReadingAsyncAction.run(() => super.startReading());
  }

  late final _$stopReadingAsyncAction =
      AsyncAction('_ReadingCoachStore.stopReading', context: context);

  @override
  Future<void> stopReading() {
    return _$stopReadingAsyncAction.run(() => super.stopReading());
  }

  late final _$pauseReadingAsyncAction =
      AsyncAction('_ReadingCoachStore.pauseReading', context: context);

  @override
  Future<void> pauseReading() {
    return _$pauseReadingAsyncAction.run(() => super.pauseReading());
  }

  late final _$resumeReadingAsyncAction =
      AsyncAction('_ReadingCoachStore.resumeReading', context: context);

  @override
  Future<void> resumeReading() {
    return _$resumeReadingAsyncAction.run(() => super.resumeReading());
  }

  late final _$restartSessionAsyncAction =
      AsyncAction('_ReadingCoachStore.restartSession', context: context);

  @override
  Future<void> restartSession() {
    return _$restartSessionAsyncAction.run(() => super.restartSession());
  }

  late final _$speakWordAsyncAction =
      AsyncAction('_ReadingCoachStore.speakWord', context: context);

  @override
  Future<void> speakWord(String word) {
    return _$speakWordAsyncAction.run(() => super.speakWord(word));
  }

  late final _$speakTextAsyncAction =
      AsyncAction('_ReadingCoachStore.speakText', context: context);

  @override
  Future<void> speakText(String text) {
    return _$speakTextAsyncAction.run(() => super.speakText(text));
  }

  late final _$restartListeningAsyncAction =
      AsyncAction('_ReadingCoachStore.restartListening', context: context);

  @override
  Future<void> restartListening() {
    return _$restartListeningAsyncAction.run(() => super.restartListening());
  }

  late final _$requestMicrophonePermissionAsyncAction = AsyncAction(
      '_ReadingCoachStore.requestMicrophonePermission',
      context: context);

  @override
  Future<void> requestMicrophonePermission() {
    return _$requestMicrophonePermissionAsyncAction
        .run(() => super.requestMicrophonePermission());
  }

  late final _$_handleRecordingCompleteAsyncAction = AsyncAction(
      '_ReadingCoachStore._handleRecordingComplete',
      context: context);

  @override
  Future<void> _handleRecordingComplete() {
    return _$_handleRecordingCompleteAsyncAction
        .run(() => super._handleRecordingComplete());
  }

  late final _$_analyzeCompleteRecordingAsyncAction = AsyncAction(
      '_ReadingCoachStore._analyzeCompleteRecording',
      context: context);

  @override
  Future<void> _analyzeCompleteRecording() {
    return _$_analyzeCompleteRecordingAsyncAction
        .run(() => super._analyzeCompleteRecording());
  }

  late final _$_ReadingCoachStoreActionController =
      ActionController(name: '_ReadingCoachStore', context: context);

  @override
  void setCurrentText(String text) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore.setCurrentText');
    try {
      return super.setCurrentText(text);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectPresetStory(PresetStory story) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore.selectPresetStory');
    try {
      return super.selectPresetStory(story);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSession() {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore.clearSession');
    try {
      return super.clearSession();
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onSpeechRecognized(String speech) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore._onSpeechRecognized');
    try {
      return super._onSpeechRecognized(speech);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onListeningChanged(bool listening) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore._onListeningChanged');
    try {
      return super._onListeningChanged(listening);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onRecordingStatusChanged(RecordingStatus status) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore._onRecordingStatusChanged');
    try {
      return super._onRecordingStatusChanged(status);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onSilenceSecondsChanged(int seconds) {
    final _$actionInfo = _$_ReadingCoachStoreActionController.startAction(
        name: '_ReadingCoachStore._onSilenceSecondsChanged');
    try {
      return super._onSilenceSecondsChanged(seconds);
    } finally {
      _$_ReadingCoachStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentText: ${currentText},
currentSession: ${currentSession},
recognizedSpeech: ${recognizedSpeech},
isListening: ${isListening},
recordingStatus: ${recordingStatus},
silenceSeconds: ${silenceSeconds},
isAnalyzing: ${isAnalyzing},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
isGeneratingStory: ${isGeneratingStory},
liveFeedback: ${liveFeedback},
practiceWords: ${practiceWords},
presetStories: ${presetStories},
currentTextWords: ${currentTextWords},
recognizedWords: ${recognizedWords},
currentAccuracy: ${currentAccuracy},
formattedAccuracy: ${formattedAccuracy},
canStartReading: ${canStartReading},
hasSession: ${hasSession},
recordingStatusText: ${recordingStatusText},
wordHighlightStates: ${wordHighlightStates}
    ''';
  }
}
