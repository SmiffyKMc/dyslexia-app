// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adaptive_story_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AdaptiveStoryStore on _AdaptiveStoryStore, Store {
  Computed<StoryPart?>? _$currentPartComputed;

  @override
  StoryPart? get currentPart =>
      (_$currentPartComputed ??= Computed<StoryPart?>(() => super.currentPart,
              name: '_AdaptiveStoryStore.currentPart'))
          .value;
  Computed<Question?>? _$currentQuestionComputed;

  @override
  Question? get currentQuestion => (_$currentQuestionComputed ??=
          Computed<Question?>(() => super.currentQuestion,
              name: '_AdaptiveStoryStore.currentQuestion'))
      .value;
  Computed<String>? _$currentPartContentWithMaskingComputed;

  @override
  String get currentPartContentWithMasking =>
      (_$currentPartContentWithMaskingComputed ??= Computed<String>(
              () => super.currentPartContentWithMasking,
              name: '_AdaptiveStoryStore.currentPartContentWithMasking'))
          .value;
  Computed<bool>? _$hasCurrentStoryComputed;

  @override
  bool get hasCurrentStory =>
      (_$hasCurrentStoryComputed ??= Computed<bool>(() => super.hasCurrentStory,
              name: '_AdaptiveStoryStore.hasCurrentStory'))
          .value;
  Computed<bool>? _$hasCurrentQuestionComputed;

  @override
  bool get hasCurrentQuestion => (_$hasCurrentQuestionComputed ??=
          Computed<bool>(() => super.hasCurrentQuestion,
              name: '_AdaptiveStoryStore.hasCurrentQuestion'))
      .value;
  Computed<bool>? _$isOnLastPartComputed;

  @override
  bool get isOnLastPart =>
      (_$isOnLastPartComputed ??= Computed<bool>(() => super.isOnLastPart,
              name: '_AdaptiveStoryStore.isOnLastPart'))
          .value;
  Computed<bool>? _$isOnLastQuestionComputed;

  @override
  bool get isOnLastQuestion => (_$isOnLastQuestionComputed ??= Computed<bool>(
          () => super.isOnLastQuestion,
          name: '_AdaptiveStoryStore.isOnLastQuestion'))
      .value;
  Computed<bool>? _$canGoNextComputed;

  @override
  bool get canGoNext =>
      (_$canGoNextComputed ??= Computed<bool>(() => super.canGoNext,
              name: '_AdaptiveStoryStore.canGoNext'))
          .value;
  Computed<bool>? _$canGoPreviousComputed;

  @override
  bool get canGoPrevious =>
      (_$canGoPreviousComputed ??= Computed<bool>(() => super.canGoPrevious,
              name: '_AdaptiveStoryStore.canGoPrevious'))
          .value;
  Computed<double>? _$progressPercentageComputed;

  @override
  double get progressPercentage => (_$progressPercentageComputed ??=
          Computed<double>(() => super.progressPercentage,
              name: '_AdaptiveStoryStore.progressPercentage'))
      .value;
  Computed<int>? _$totalQuestionsAnsweredComputed;

  @override
  int get totalQuestionsAnswered => (_$totalQuestionsAnsweredComputed ??=
          Computed<int>(() => super.totalQuestionsAnswered,
              name: '_AdaptiveStoryStore.totalQuestionsAnswered'))
      .value;
  Computed<List<String>>? _$uniquePracticedWordsComputed;

  @override
  List<String> get uniquePracticedWords => (_$uniquePracticedWordsComputed ??=
          Computed<List<String>>(() => super.uniquePracticedWords,
              name: '_AdaptiveStoryStore.uniquePracticedWords'))
      .value;
  Computed<List<String>>? _$practicedPatternsComputed;

  @override
  List<String> get practicedPatterns => (_$practicedPatternsComputed ??=
          Computed<List<String>>(() => super.practicedPatterns,
              name: '_AdaptiveStoryStore.practicedPatterns'))
      .value;

  late final _$currentStoryAtom =
      Atom(name: '_AdaptiveStoryStore.currentStory', context: context);

  @override
  Story? get currentStory {
    _$currentStoryAtom.reportRead();
    return super.currentStory;
  }

  @override
  set currentStory(Story? value) {
    _$currentStoryAtom.reportWrite(value, super.currentStory, () {
      super.currentStory = value;
    });
  }

  late final _$progressAtom =
      Atom(name: '_AdaptiveStoryStore.progress', context: context);

  @override
  StoryProgress? get progress {
    _$progressAtom.reportRead();
    return super.progress;
  }

  @override
  set progress(StoryProgress? value) {
    _$progressAtom.reportWrite(value, super.progress, () {
      super.progress = value;
    });
  }

  late final _$currentPartIndexAtom =
      Atom(name: '_AdaptiveStoryStore.currentPartIndex', context: context);

  @override
  int get currentPartIndex {
    _$currentPartIndexAtom.reportRead();
    return super.currentPartIndex;
  }

  @override
  set currentPartIndex(int value) {
    _$currentPartIndexAtom.reportWrite(value, super.currentPartIndex, () {
      super.currentPartIndex = value;
    });
  }

  late final _$currentQuestionIndexAtom =
      Atom(name: '_AdaptiveStoryStore.currentQuestionIndex', context: context);

  @override
  int get currentQuestionIndex {
    _$currentQuestionIndexAtom.reportRead();
    return super.currentQuestionIndex;
  }

  @override
  set currentQuestionIndex(int value) {
    _$currentQuestionIndexAtom.reportWrite(value, super.currentQuestionIndex,
        () {
      super.currentQuestionIndex = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_AdaptiveStoryStore.isLoading', context: context);

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
      Atom(name: '_AdaptiveStoryStore.errorMessage', context: context);

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

  late final _$showingFeedbackAtom =
      Atom(name: '_AdaptiveStoryStore.showingFeedback', context: context);

  @override
  bool get showingFeedback {
    _$showingFeedbackAtom.reportRead();
    return super.showingFeedback;
  }

  @override
  set showingFeedback(bool value) {
    _$showingFeedbackAtom.reportWrite(value, super.showingFeedback, () {
      super.showingFeedback = value;
    });
  }

  late final _$storyCompletedAtom =
      Atom(name: '_AdaptiveStoryStore.storyCompleted', context: context);

  @override
  bool get storyCompleted {
    _$storyCompletedAtom.reportRead();
    return super.storyCompleted;
  }

  @override
  set storyCompleted(bool value) {
    _$storyCompletedAtom.reportWrite(value, super.storyCompleted, () {
      super.storyCompleted = value;
    });
  }

  late final _$lastAnswerAtom =
      Atom(name: '_AdaptiveStoryStore.lastAnswer', context: context);

  @override
  UserAnswer? get lastAnswer {
    _$lastAnswerAtom.reportRead();
    return super.lastAnswer;
  }

  @override
  set lastAnswer(UserAnswer? value) {
    _$lastAnswerAtom.reportWrite(value, super.lastAnswer, () {
      super.lastAnswer = value;
    });
  }

  late final _$practicedWordsAtom =
      Atom(name: '_AdaptiveStoryStore.practicedWords', context: context);

  @override
  ObservableList<String> get practicedWords {
    _$practicedWordsAtom.reportRead();
    return super.practicedWords;
  }

  @override
  set practicedWords(ObservableList<String> value) {
    _$practicedWordsAtom.reportWrite(value, super.practicedWords, () {
      super.practicedWords = value;
    });
  }

  late final _$patternPracticeCountAtom =
      Atom(name: '_AdaptiveStoryStore.patternPracticeCount', context: context);

  @override
  ObservableMap<String, int> get patternPracticeCount {
    _$patternPracticeCountAtom.reportRead();
    return super.patternPracticeCount;
  }

  @override
  set patternPracticeCount(ObservableMap<String, int> value) {
    _$patternPracticeCountAtom.reportWrite(value, super.patternPracticeCount,
        () {
      super.patternPracticeCount = value;
    });
  }

  late final _$discoveredPatternsAtom =
      Atom(name: '_AdaptiveStoryStore.discoveredPatterns', context: context);

  @override
  ObservableList<LearningPattern> get discoveredPatterns {
    _$discoveredPatternsAtom.reportRead();
    return super.discoveredPatterns;
  }

  @override
  set discoveredPatterns(ObservableList<LearningPattern> value) {
    _$discoveredPatternsAtom.reportWrite(value, super.discoveredPatterns, () {
      super.discoveredPatterns = value;
    });
  }

  late final _$startStoryAsyncAction =
      AsyncAction('_AdaptiveStoryStore.startStory', context: context);

  @override
  Future<void> startStory(String storyId) {
    return _$startStoryAsyncAction.run(() => super.startStory(storyId));
  }

  late final _$answerQuestionAsyncAction =
      AsyncAction('_AdaptiveStoryStore.answerQuestion', context: context);

  @override
  Future<void> answerQuestion(String answer) {
    return _$answerQuestionAsyncAction.run(() => super.answerQuestion(answer));
  }

  late final _$nextQuestionAsyncAction =
      AsyncAction('_AdaptiveStoryStore.nextQuestion', context: context);

  @override
  Future<void> nextQuestion() {
    return _$nextQuestionAsyncAction.run(() => super.nextQuestion());
  }

  late final _$nextPartAsyncAction =
      AsyncAction('_AdaptiveStoryStore.nextPart', context: context);

  @override
  Future<void> nextPart() {
    return _$nextPartAsyncAction.run(() => super.nextPart());
  }

  late final _$completeStoryAsyncAction =
      AsyncAction('_AdaptiveStoryStore.completeStory', context: context);

  @override
  Future<void> completeStory() {
    return _$completeStoryAsyncAction.run(() => super.completeStory());
  }

  late final _$skipCurrentQuestionAsyncAction =
      AsyncAction('_AdaptiveStoryStore.skipCurrentQuestion', context: context);

  @override
  Future<void> skipCurrentQuestion() {
    return _$skipCurrentQuestionAsyncAction
        .run(() => super.skipCurrentQuestion());
  }

  late final _$restartStoryAsyncAction =
      AsyncAction('_AdaptiveStoryStore.restartStory', context: context);

  @override
  Future<void> restartStory() {
    return _$restartStoryAsyncAction.run(() => super.restartStory());
  }

  late final _$goToPreviousPartAsyncAction =
      AsyncAction('_AdaptiveStoryStore.goToPreviousPart', context: context);

  @override
  Future<void> goToPreviousPart() {
    return _$goToPreviousPartAsyncAction.run(() => super.goToPreviousPart());
  }

  late final _$speakCurrentContentAsyncAction =
      AsyncAction('_AdaptiveStoryStore.speakCurrentContent', context: context);

  @override
  Future<void> speakCurrentContent() {
    return _$speakCurrentContentAsyncAction
        .run(() => super.speakCurrentContent());
  }

  late final _$speakQuestionAsyncAction =
      AsyncAction('_AdaptiveStoryStore.speakQuestion', context: context);

  @override
  Future<void> speakQuestion() {
    return _$speakQuestionAsyncAction.run(() => super.speakQuestion());
  }

  late final _$speakCorrectAnswerAsyncAction =
      AsyncAction('_AdaptiveStoryStore.speakCorrectAnswer', context: context);

  @override
  Future<void> speakCorrectAnswer() {
    return _$speakCorrectAnswerAsyncAction
        .run(() => super.speakCorrectAnswer());
  }

  late final _$_AdaptiveStoryStoreActionController =
      ActionController(name: '_AdaptiveStoryStore', context: context);

  @override
  List<Story> getAllStories() {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore.getAllStories');
    try {
      return super.getAllStories();
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _updateDiscoveredPatterns(String pattern) {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore._updateDiscoveredPatterns');
    try {
      return super._updateDiscoveredPatterns(pattern);
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void finishStory() {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore.finishStory');
    try {
      return super.finishStory();
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void hideFeedback() {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore.hideFeedback');
    try {
      return super.hideFeedback();
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCurrentStory() {
    final _$actionInfo = _$_AdaptiveStoryStoreActionController.startAction(
        name: '_AdaptiveStoryStore.clearCurrentStory');
    try {
      return super.clearCurrentStory();
    } finally {
      _$_AdaptiveStoryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentStory: ${currentStory},
progress: ${progress},
currentPartIndex: ${currentPartIndex},
currentQuestionIndex: ${currentQuestionIndex},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
showingFeedback: ${showingFeedback},
storyCompleted: ${storyCompleted},
lastAnswer: ${lastAnswer},
practicedWords: ${practicedWords},
patternPracticeCount: ${patternPracticeCount},
discoveredPatterns: ${discoveredPatterns},
currentPart: ${currentPart},
currentQuestion: ${currentQuestion},
currentPartContentWithMasking: ${currentPartContentWithMasking},
hasCurrentStory: ${hasCurrentStory},
hasCurrentQuestion: ${hasCurrentQuestion},
isOnLastPart: ${isOnLastPart},
isOnLastQuestion: ${isOnLastQuestion},
canGoNext: ${canGoNext},
canGoPrevious: ${canGoPrevious},
progressPercentage: ${progressPercentage},
totalQuestionsAnswered: ${totalQuestionsAnswered},
uniquePracticedWords: ${uniquePracticedWords},
practicedPatterns: ${practicedPatterns}
    ''';
  }
}
