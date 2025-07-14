// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learner_profile_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LearnerProfileStore on _LearnerProfileStore, Store {
  Computed<bool>? _$hasProfileComputed;

  @override
  bool get hasProfile =>
      (_$hasProfileComputed ??= Computed<bool>(() => super.hasProfile,
              name: '_LearnerProfileStore.hasProfile'))
          .value;
  Computed<bool>? _$isInitialProfileComputed;

  @override
  bool get isInitialProfile => (_$isInitialProfileComputed ??= Computed<bool>(
          () => super.isInitialProfile,
          name: '_LearnerProfileStore.isInitialProfile'))
      .value;
  Computed<bool>? _$needsUpdateComputed;

  @override
  bool get needsUpdate =>
      (_$needsUpdateComputed ??= Computed<bool>(() => super.needsUpdate,
              name: '_LearnerProfileStore.needsUpdate'))
          .value;
  Computed<String>? _$recommendedToolComputed;

  @override
  String get recommendedTool => (_$recommendedToolComputed ??= Computed<String>(
          () => super.recommendedTool,
          name: '_LearnerProfileStore.recommendedTool'))
      .value;
  Computed<String>? _$currentFocusComputed;

  @override
  String get currentFocus =>
      (_$currentFocusComputed ??= Computed<String>(() => super.currentFocus,
              name: '_LearnerProfileStore.currentFocus'))
          .value;
  Computed<List<String>>? _$phonemeConfusionsComputed;

  @override
  List<String> get phonemeConfusions => (_$phonemeConfusionsComputed ??=
          Computed<List<String>>(() => super.phonemeConfusions,
              name: '_LearnerProfileStore.phonemeConfusions'))
      .value;
  Computed<String>? _$learningAdviceComputed;

  @override
  String get learningAdvice =>
      (_$learningAdviceComputed ??= Computed<String>(() => super.learningAdvice,
              name: '_LearnerProfileStore.learningAdvice'))
          .value;
  Computed<List<String>>? _$strengthAreasComputed;

  @override
  List<String> get strengthAreas => (_$strengthAreasComputed ??=
          Computed<List<String>>(() => super.strengthAreas,
              name: '_LearnerProfileStore.strengthAreas'))
      .value;
  Computed<List<String>>? _$improvementAreasComputed;

  @override
  List<String> get improvementAreas => (_$improvementAreasComputed ??=
          Computed<List<String>>(() => super.improvementAreas,
              name: '_LearnerProfileStore.improvementAreas'))
      .value;
  Computed<String>? _$confidenceLevelComputed;

  @override
  String get confidenceLevel => (_$confidenceLevelComputed ??= Computed<String>(
          () => super.confidenceLevel,
          name: '_LearnerProfileStore.confidenceLevel'))
      .value;
  Computed<String>? _$accuracyLevelComputed;

  @override
  String get accuracyLevel =>
      (_$accuracyLevelComputed ??= Computed<String>(() => super.accuracyLevel,
              name: '_LearnerProfileStore.accuracyLevel'))
          .value;
  Computed<bool>? _$canUpdateManuallyComputed;

  @override
  bool get canUpdateManually => (_$canUpdateManuallyComputed ??= Computed<bool>(
          () => super.canUpdateManually,
          name: '_LearnerProfileStore.canUpdateManually'))
      .value;

  late final _$currentProfileAtom =
      Atom(name: '_LearnerProfileStore.currentProfile', context: context);

  @override
  LearnerProfile? get currentProfile {
    _$currentProfileAtom.reportRead();
    return super.currentProfile;
  }

  @override
  set currentProfile(LearnerProfile? value) {
    _$currentProfileAtom.reportWrite(value, super.currentProfile, () {
      super.currentProfile = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_LearnerProfileStore.isLoading', context: context);

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

  late final _$isUpdatingAtom =
      Atom(name: '_LearnerProfileStore.isUpdating', context: context);

  @override
  bool get isUpdating {
    _$isUpdatingAtom.reportRead();
    return super.isUpdating;
  }

  @override
  set isUpdating(bool value) {
    _$isUpdatingAtom.reportWrite(value, super.isUpdating, () {
      super.isUpdating = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_LearnerProfileStore.errorMessage', context: context);

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

  late final _$sessionsSinceLastUpdateAtom = Atom(
      name: '_LearnerProfileStore.sessionsSinceLastUpdate', context: context);

  @override
  int get sessionsSinceLastUpdate {
    _$sessionsSinceLastUpdateAtom.reportRead();
    return super.sessionsSinceLastUpdate;
  }

  @override
  set sessionsSinceLastUpdate(int value) {
    _$sessionsSinceLastUpdateAtom
        .reportWrite(value, super.sessionsSinceLastUpdate, () {
      super.sessionsSinceLastUpdate = value;
    });
  }

  late final _$profileHistoryAtom =
      Atom(name: '_LearnerProfileStore.profileHistory', context: context);

  @override
  List<LearnerProfile> get profileHistory {
    _$profileHistoryAtom.reportRead();
    return super.profileHistory;
  }

  @override
  set profileHistory(List<LearnerProfile> value) {
    _$profileHistoryAtom.reportWrite(value, super.profileHistory, () {
      super.profileHistory = value;
    });
  }

  late final _$initializeAsyncAction =
      AsyncAction('_LearnerProfileStore.initialize', context: context);

  @override
  Future<void> initialize() {
    return _$initializeAsyncAction.run(() => super.initialize());
  }

  late final _$updateProfileAsyncAction =
      AsyncAction('_LearnerProfileStore.updateProfile', context: context);

  @override
  Future<void> updateProfile(LearnerProfile newProfile) {
    return _$updateProfileAsyncAction
        .run(() => super.updateProfile(newProfile));
  }

  late final _$resetProfileAsyncAction =
      AsyncAction('_LearnerProfileStore.resetProfile', context: context);

  @override
  Future<void> resetProfile() {
    return _$resetProfileAsyncAction.run(() => super.resetProfile());
  }

  late final _$restorePreviousProfileAsyncAction = AsyncAction(
      '_LearnerProfileStore.restorePreviousProfile',
      context: context);

  @override
  Future<void> restorePreviousProfile() {
    return _$restorePreviousProfileAsyncAction
        .run(() => super.restorePreviousProfile());
  }

  late final _$_LearnerProfileStoreActionController =
      ActionController(name: '_LearnerProfileStore', context: context);

  @override
  void incrementSessionCount() {
    final _$actionInfo = _$_LearnerProfileStoreActionController.startAction(
        name: '_LearnerProfileStore.incrementSessionCount');
    try {
      return super.incrementSessionCount();
    } finally {
      _$_LearnerProfileStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_LearnerProfileStoreActionController.startAction(
        name: '_LearnerProfileStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_LearnerProfileStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setUpdating(bool updating) {
    final _$actionInfo = _$_LearnerProfileStoreActionController.startAction(
        name: '_LearnerProfileStore.setUpdating');
    try {
      return super.setUpdating(updating);
    } finally {
      _$_LearnerProfileStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void startUpdate() {
    final _$actionInfo = _$_LearnerProfileStoreActionController.startAction(
        name: '_LearnerProfileStore.startUpdate');
    try {
      return super.startUpdate();
    } finally {
      _$_LearnerProfileStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void finishUpdate() {
    final _$actionInfo = _$_LearnerProfileStoreActionController.startAction(
        name: '_LearnerProfileStore.finishUpdate');
    try {
      return super.finishUpdate();
    } finally {
      _$_LearnerProfileStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentProfile: ${currentProfile},
isLoading: ${isLoading},
isUpdating: ${isUpdating},
errorMessage: ${errorMessage},
sessionsSinceLastUpdate: ${sessionsSinceLastUpdate},
profileHistory: ${profileHistory},
hasProfile: ${hasProfile},
isInitialProfile: ${isInitialProfile},
needsUpdate: ${needsUpdate},
recommendedTool: ${recommendedTool},
currentFocus: ${currentFocus},
phonemeConfusions: ${phonemeConfusions},
learningAdvice: ${learningAdvice},
strengthAreas: ${strengthAreas},
improvementAreas: ${improvementAreas},
confidenceLevel: ${confidenceLevel},
accuracyLevel: ${accuracyLevel},
canUpdateManually: ${canUpdateManually}
    ''';
  }
}
