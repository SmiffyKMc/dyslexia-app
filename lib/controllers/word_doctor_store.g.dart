// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_doctor_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WordDoctorStore on _WordDoctorStore, Store {
  Computed<bool>? _$canAnalyzeComputed;

  @override
  bool get canAnalyze =>
      (_$canAnalyzeComputed ??= Computed<bool>(() => super.canAnalyze,
              name: '_WordDoctorStore.canAnalyze'))
          .value;
  Computed<bool>? _$hasCurrentAnalysisComputed;

  @override
  bool get hasCurrentAnalysis => (_$hasCurrentAnalysisComputed ??=
          Computed<bool>(() => super.hasCurrentAnalysis,
              name: '_WordDoctorStore.hasCurrentAnalysis'))
      .value;
  Computed<bool>? _$isCurrentWordSavedComputed;

  @override
  bool get isCurrentWordSaved => (_$isCurrentWordSavedComputed ??=
          Computed<bool>(() => super.isCurrentWordSaved,
              name: '_WordDoctorStore.isCurrentWordSaved'))
      .value;
  Computed<int>? _$savedWordsCountComputed;

  @override
  int get savedWordsCount =>
      (_$savedWordsCountComputed ??= Computed<int>(() => super.savedWordsCount,
              name: '_WordDoctorStore.savedWordsCount'))
          .value;
  Computed<int>? _$recentWordsCountComputed;

  @override
  int get recentWordsCount => (_$recentWordsCountComputed ??= Computed<int>(
          () => super.recentWordsCount,
          name: '_WordDoctorStore.recentWordsCount'))
      .value;

  late final _$currentAnalysisAtom =
      Atom(name: '_WordDoctorStore.currentAnalysis', context: context);

  @override
  WordAnalysis? get currentAnalysis {
    _$currentAnalysisAtom.reportRead();
    return super.currentAnalysis;
  }

  @override
  set currentAnalysis(WordAnalysis? value) {
    _$currentAnalysisAtom.reportWrite(value, super.currentAnalysis, () {
      super.currentAnalysis = value;
    });
  }

  late final _$savedWordsAtom =
      Atom(name: '_WordDoctorStore.savedWords', context: context);

  @override
  ObservableList<WordAnalysis> get savedWords {
    _$savedWordsAtom.reportRead();
    return super.savedWords;
  }

  @override
  set savedWords(ObservableList<WordAnalysis> value) {
    _$savedWordsAtom.reportWrite(value, super.savedWords, () {
      super.savedWords = value;
    });
  }

  late final _$recentWordsAtom =
      Atom(name: '_WordDoctorStore.recentWords', context: context);

  @override
  ObservableList<WordAnalysis> get recentWords {
    _$recentWordsAtom.reportRead();
    return super.recentWords;
  }

  @override
  set recentWords(ObservableList<WordAnalysis> value) {
    _$recentWordsAtom.reportWrite(value, super.recentWords, () {
      super.recentWords = value;
    });
  }

  late final _$isAnalyzingAtom =
      Atom(name: '_WordDoctorStore.isAnalyzing', context: context);

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
      Atom(name: '_WordDoctorStore.isLoading', context: context);

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
      Atom(name: '_WordDoctorStore.errorMessage', context: context);

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

  late final _$inputWordAtom =
      Atom(name: '_WordDoctorStore.inputWord', context: context);

  @override
  String get inputWord {
    _$inputWordAtom.reportRead();
    return super.inputWord;
  }

  @override
  set inputWord(String value) {
    _$inputWordAtom.reportWrite(value, super.inputWord, () {
      super.inputWord = value;
    });
  }

  late final _$analyzeCurrentWordAsyncAction =
      AsyncAction('_WordDoctorStore.analyzeCurrentWord', context: context);

  @override
  Future<void> analyzeCurrentWord() {
    return _$analyzeCurrentWordAsyncAction
        .run(() => super.analyzeCurrentWord());
  }

  late final _$analyzeWordAsyncAction =
      AsyncAction('_WordDoctorStore.analyzeWord', context: context);

  @override
  Future<void> analyzeWord(String word) {
    return _$analyzeWordAsyncAction.run(() => super.analyzeWord(word));
  }

  late final _$reAnalyzeWordAsyncAction =
      AsyncAction('_WordDoctorStore.reAnalyzeWord', context: context);

  @override
  Future<void> reAnalyzeWord(WordAnalysis analysis) {
    return _$reAnalyzeWordAsyncAction.run(() => super.reAnalyzeWord(analysis));
  }

  late final _$speakSyllableAsyncAction =
      AsyncAction('_WordDoctorStore.speakSyllable', context: context);

  @override
  Future<void> speakSyllable(String syllable) {
    return _$speakSyllableAsyncAction.run(() => super.speakSyllable(syllable));
  }

  late final _$speakWordAsyncAction =
      AsyncAction('_WordDoctorStore.speakWord', context: context);

  @override
  Future<void> speakWord(String word) {
    return _$speakWordAsyncAction.run(() => super.speakWord(word));
  }

  late final _$speakExampleSentenceAsyncAction =
      AsyncAction('_WordDoctorStore.speakExampleSentence', context: context);

  @override
  Future<void> speakExampleSentence(String sentence) {
    return _$speakExampleSentenceAsyncAction
        .run(() => super.speakExampleSentence(sentence));
  }

  late final _$saveCurrentWordAsyncAction =
      AsyncAction('_WordDoctorStore.saveCurrentWord', context: context);

  @override
  Future<void> saveCurrentWord() {
    return _$saveCurrentWordAsyncAction.run(() => super.saveCurrentWord());
  }

  late final _$removeSavedWordAsyncAction =
      AsyncAction('_WordDoctorStore.removeSavedWord', context: context);

  @override
  Future<void> removeSavedWord(String word) {
    return _$removeSavedWordAsyncAction.run(() => super.removeSavedWord(word));
  }

  late final _$_loadSavedWordsAsyncAction =
      AsyncAction('_WordDoctorStore._loadSavedWords', context: context);

  @override
  Future<void> _loadSavedWords() {
    return _$_loadSavedWordsAsyncAction.run(() => super._loadSavedWords());
  }

  late final _$_loadRecentWordsAsyncAction =
      AsyncAction('_WordDoctorStore._loadRecentWords', context: context);

  @override
  Future<void> _loadRecentWords() {
    return _$_loadRecentWordsAsyncAction.run(() => super._loadRecentWords());
  }

  late final _$clearRecentWordsAsyncAction =
      AsyncAction('_WordDoctorStore.clearRecentWords', context: context);

  @override
  Future<void> clearRecentWords() {
    return _$clearRecentWordsAsyncAction.run(() => super.clearRecentWords());
  }

  late final _$_WordDoctorStoreActionController =
      ActionController(name: '_WordDoctorStore', context: context);

  @override
  void setInputWord(String word) {
    final _$actionInfo = _$_WordDoctorStoreActionController.startAction(
        name: '_WordDoctorStore.setInputWord');
    try {
      return super.setInputWord(word);
    } finally {
      _$_WordDoctorStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCurrentAnalysis() {
    final _$actionInfo = _$_WordDoctorStoreActionController.startAction(
        name: '_WordDoctorStore.clearCurrentAnalysis');
    try {
      return super.clearCurrentAnalysis();
    } finally {
      _$_WordDoctorStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_WordDoctorStoreActionController.startAction(
        name: '_WordDoctorStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_WordDoctorStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentAnalysis: ${currentAnalysis},
savedWords: ${savedWords},
recentWords: ${recentWords},
isAnalyzing: ${isAnalyzing},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
inputWord: ${inputWord},
canAnalyze: ${canAnalyze},
hasCurrentAnalysis: ${hasCurrentAnalysis},
isCurrentWordSaved: ${isCurrentWordSaved},
savedWordsCount: ${savedWordsCount},
recentWordsCount: ${recentWordsCount}
    ''';
  }
}
