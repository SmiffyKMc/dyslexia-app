// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_simplifier_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TextSimplifierStore on _TextSimplifierStore, Store {
  Computed<bool>? _$hasOriginalTextComputed;

  @override
  bool get hasOriginalText =>
      (_$hasOriginalTextComputed ??= Computed<bool>(() => super.hasOriginalText,
              name: '_TextSimplifierStore.hasOriginalText'))
          .value;
  Computed<bool>? _$hasSimplifiedTextComputed;

  @override
  bool get hasSimplifiedText => (_$hasSimplifiedTextComputed ??= Computed<bool>(
          () => super.hasSimplifiedText,
          name: '_TextSimplifierStore.hasSimplifiedText'))
      .value;
  Computed<bool>? _$canSimplifyComputed;

  @override
  bool get canSimplify =>
      (_$canSimplifyComputed ??= Computed<bool>(() => super.canSimplify,
              name: '_TextSimplifierStore.canSimplify'))
          .value;
  Computed<bool>? _$canSimplifyAgainComputed;

  @override
  bool get canSimplifyAgain => (_$canSimplifyAgainComputed ??= Computed<bool>(
          () => super.canSimplifyAgain,
          name: '_TextSimplifierStore.canSimplifyAgain'))
      .value;

  late final _$originalTextAtom =
      Atom(name: '_TextSimplifierStore.originalText', context: context);

  @override
  String get originalText {
    _$originalTextAtom.reportRead();
    return super.originalText;
  }

  @override
  set originalText(String value) {
    _$originalTextAtom.reportWrite(value, super.originalText, () {
      super.originalText = value;
    });
  }

  late final _$simplifiedTextAtom =
      Atom(name: '_TextSimplifierStore.simplifiedText', context: context);

  @override
  String get simplifiedText {
    _$simplifiedTextAtom.reportRead();
    return super.simplifiedText;
  }

  @override
  set simplifiedText(String value) {
    _$simplifiedTextAtom.reportWrite(value, super.simplifiedText, () {
      super.simplifiedText = value;
    });
  }

  late final _$isSimplifyingAtom =
      Atom(name: '_TextSimplifierStore.isSimplifying', context: context);

  @override
  bool get isSimplifying {
    _$isSimplifyingAtom.reportRead();
    return super.isSimplifying;
  }

  @override
  set isSimplifying(bool value) {
    _$isSimplifyingAtom.reportWrite(value, super.isSimplifying, () {
      super.isSimplifying = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_TextSimplifierStore.errorMessage', context: context);

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

  late final _$selectedReadingLevelAtom =
      Atom(name: '_TextSimplifierStore.selectedReadingLevel', context: context);

  @override
  String get selectedReadingLevel {
    _$selectedReadingLevelAtom.reportRead();
    return super.selectedReadingLevel;
  }

  @override
  set selectedReadingLevel(String value) {
    _$selectedReadingLevelAtom.reportWrite(value, super.selectedReadingLevel,
        () {
      super.selectedReadingLevel = value;
    });
  }

  late final _$explainChangesAtom =
      Atom(name: '_TextSimplifierStore.explainChanges', context: context);

  @override
  bool get explainChanges {
    _$explainChangesAtom.reportRead();
    return super.explainChanges;
  }

  @override
  set explainChanges(bool value) {
    _$explainChangesAtom.reportWrite(value, super.explainChanges, () {
      super.explainChanges = value;
    });
  }

  late final _$sideBySideViewAtom =
      Atom(name: '_TextSimplifierStore.sideBySideView', context: context);

  @override
  bool get sideBySideView {
    _$sideBySideViewAtom.reportRead();
    return super.sideBySideView;
  }

  @override
  set sideBySideView(bool value) {
    _$sideBySideViewAtom.reportWrite(value, super.sideBySideView, () {
      super.sideBySideView = value;
    });
  }

  late final _$defineKeyTermsAtom =
      Atom(name: '_TextSimplifierStore.defineKeyTerms', context: context);

  @override
  bool get defineKeyTerms {
    _$defineKeyTermsAtom.reportRead();
    return super.defineKeyTerms;
  }

  @override
  set defineKeyTerms(bool value) {
    _$defineKeyTermsAtom.reportWrite(value, super.defineKeyTerms, () {
      super.defineKeyTerms = value;
    });
  }

  late final _$addVisualsAtom =
      Atom(name: '_TextSimplifierStore.addVisuals', context: context);

  @override
  bool get addVisuals {
    _$addVisualsAtom.reportRead();
    return super.addVisuals;
  }

  @override
  set addVisuals(bool value) {
    _$addVisualsAtom.reportWrite(value, super.addVisuals, () {
      super.addVisuals = value;
    });
  }

  late final _$isProcessingOCRAtom =
      Atom(name: '_TextSimplifierStore.isProcessingOCR', context: context);

  @override
  bool get isProcessingOCR {
    _$isProcessingOCRAtom.reportRead();
    return super.isProcessingOCR;
  }

  @override
  set isProcessingOCR(bool value) {
    _$isProcessingOCRAtom.reportWrite(value, super.isProcessingOCR, () {
      super.isProcessingOCR = value;
    });
  }

  late final _$simplificationHistoryAtom = Atom(
      name: '_TextSimplifierStore.simplificationHistory', context: context);

  @override
  List<String> get simplificationHistory {
    _$simplificationHistoryAtom.reportRead();
    return super.simplificationHistory;
  }

  @override
  set simplificationHistory(List<String> value) {
    _$simplificationHistoryAtom.reportWrite(value, super.simplificationHistory,
        () {
      super.simplificationHistory = value;
    });
  }

  late final _$wordDefinitionsAtom =
      Atom(name: '_TextSimplifierStore.wordDefinitions', context: context);

  @override
  Map<String, String> get wordDefinitions {
    _$wordDefinitionsAtom.reportRead();
    return super.wordDefinitions;
  }

  @override
  set wordDefinitions(Map<String, String> value) {
    _$wordDefinitionsAtom.reportWrite(value, super.wordDefinitions, () {
      super.wordDefinitions = value;
    });
  }

  late final _$isSpeakingAtom =
      Atom(name: '_TextSimplifierStore.isSpeaking', context: context);

  @override
  bool get isSpeaking {
    _$isSpeakingAtom.reportRead();
    return super.isSpeaking;
  }

  @override
  set isSpeaking(bool value) {
    _$isSpeakingAtom.reportWrite(value, super.isSpeaking, () {
      super.isSpeaking = value;
    });
  }

  late final _$_TextSimplifierStoreActionController =
      ActionController(name: '_TextSimplifierStore', context: context);

  @override
  void setOriginalText(String text) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setOriginalText');
    try {
      return super.setOriginalText(text);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSimplifiedText(String text) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setSimplifiedText');
    try {
      return super.setSimplifiedText(text);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSimplifiedText() {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.clearSimplifiedText');
    try {
      return super.clearSimplifiedText();
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIsSimplifying(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setIsSimplifying');
    try {
      return super.setIsSimplifying(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setErrorMessage(String? message) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setErrorMessage');
    try {
      return super.setErrorMessage(message);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSelectedReadingLevel(String level) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setSelectedReadingLevel');
    try {
      return super.setSelectedReadingLevel(level);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setExplainChanges(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setExplainChanges');
    try {
      return super.setExplainChanges(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSideBySideView(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setSideBySideView');
    try {
      return super.setSideBySideView(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDefineKeyTerms(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setDefineKeyTerms');
    try {
      return super.setDefineKeyTerms(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setAddVisuals(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setAddVisuals');
    try {
      return super.setAddVisuals(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIsProcessingOCR(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setIsProcessingOCR');
    try {
      return super.setIsProcessingOCR(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addWordDefinition(String word, String definition) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.addWordDefinition');
    try {
      return super.addWordDefinition(word, definition);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIsSpeaking(bool value) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setIsSpeaking');
    try {
      return super.setIsSpeaking(value);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearAll() {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.clearAll');
    try {
      return super.clearAll();
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void pasteFromClipboard(String clipboardText) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.pasteFromClipboard');
    try {
      return super.pasteFromClipboard(clipboardText);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setOCRText(String ocrText) {
    final _$actionInfo = _$_TextSimplifierStoreActionController.startAction(
        name: '_TextSimplifierStore.setOCRText');
    try {
      return super.setOCRText(ocrText);
    } finally {
      _$_TextSimplifierStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
originalText: ${originalText},
simplifiedText: ${simplifiedText},
isSimplifying: ${isSimplifying},
errorMessage: ${errorMessage},
selectedReadingLevel: ${selectedReadingLevel},
explainChanges: ${explainChanges},
sideBySideView: ${sideBySideView},
defineKeyTerms: ${defineKeyTerms},
addVisuals: ${addVisuals},
isProcessingOCR: ${isProcessingOCR},
simplificationHistory: ${simplificationHistory},
wordDefinitions: ${wordDefinitions},
isSpeaking: ${isSpeaking},
hasOriginalText: ${hasOriginalText},
hasSimplifiedText: ${hasSimplifiedText},
canSimplify: ${canSimplify},
canSimplifyAgain: ${canSimplifyAgain}
    ''';
  }
}
