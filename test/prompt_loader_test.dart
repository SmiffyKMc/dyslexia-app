import 'package:flutter_test/flutter_test.dart';

import 'package:dyslexic_ai/utils/prompt_loader.dart';

void main() {
  group('PromptLoader Tests', () {
    setUpAll(() async {
      // Initialize Flutter bindings for asset loading
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('should load all text simplifier templates', () async {
      // Test base template
      final baseTemplate =
          await PromptLoader.load('text_simplifier', 'base.tmpl');
      expect(baseTemplate, contains('You are helping someone with dyslexia'));
      expect(baseTemplate, contains('{{reading_level}}'));
      expect(baseTemplate, contains('{{target_text}}'));
      expect(baseTemplate, contains('{{profile_adjustments}}'));

      // Test add-on templates
      final explainChanges =
          await PromptLoader.load('text_simplifier', 'explain_changes.tmpl');
      expect(explainChanges, contains('EXPLAIN CHANGES'));

      final defineTerms =
          await PromptLoader.load('text_simplifier', 'define_terms.tmpl');
      expect(defineTerms, contains('DEFINE KEY TERMS'));

      final addVisuals =
          await PromptLoader.load('text_simplifier', 'add_visuals.tmpl');
      expect(addVisuals, contains('VISUAL SUGGESTIONS'));

      final regeneration =
          await PromptLoader.load('text_simplifier', 'regeneration.tmpl');
      expect(regeneration, contains('REGENERATION REQUEST'));
    });

    test('should load story generation templates', () async {
      final storyWithQuestions = await PromptLoader.load(
          'story_generation', 'story_with_questions.tmpl');
      expect(storyWithQuestions,
          contains('educational stories for dyslexic learners'));
      expect(storyWithQuestions, contains('{{sentence_count}}'));
      expect(storyWithQuestions, contains('{{difficulty_level}}'));
      expect(storyWithQuestions, contains('{{phoneme_pattern1}}'));
      expect(storyWithQuestions, contains('{{phoneme_pattern2}}'));

      final storySimple =
          await PromptLoader.load('story_generation', 'story_simple.tmpl');
      expect(storySimple, contains('expert storyteller'));
      expect(storySimple, contains('{{user_confidence}}'));
      expect(storySimple, contains('{{phoneme_patterns}}'));
    });

    test('should load sentence fixer templates', () async {
      final batchGeneration =
          await PromptLoader.load('sentence_fixer', 'batch_generation.tmpl');
      expect(batchGeneration, contains('Generate exactly {{count}}'));

      final singleSentence =
          await PromptLoader.load('sentence_fixer', 'single_sentence.tmpl');
      expect(singleSentence,
          contains('Create {{count}} beginner practice sentences'));

      final simpleSentence =
          await PromptLoader.load('sentence_fixer', 'simple_sentence.tmpl');
      expect(simpleSentence,
          contains('Create 1 sentence with exactly 1 SPELLING mistake'));
    });

    test('should load profile analysis template', () async {
      final fullUpdate =
          await PromptLoader.load('profile_analysis', 'full_update.tmpl');
      expect(fullUpdate, contains('Analyze dyslexia learning data'));
      expect(fullUpdate, contains('{{current_profile}}'));
      expect(fullUpdate, contains('{{session_data}}'));
      expect(fullUpdate, contains('{{suggested_tools}}'));
    });

    test('should load word analysis templates', () async {
      final definition =
          await PromptLoader.load('word_analysis', 'definition.tmpl');
      expect(definition, contains('simple definition'));
      expect(definition, contains('{{word_target}}'));
    });

    test('should load shared templates', () async {
      final legacySimplification = await PromptLoader.load(
          'shared', 'legacy_sentence_simplification.tmpl');
      expect(legacySimplification, contains('helping someone with dyslexia'));
      expect(legacySimplification, contains('{{target_sentence}}'));
    });

    test('should build composite templates correctly', () async {
      final variables = {
        'reading_level': 'elementary',
        'target_text': 'This is a test sentence.',
        'profile_adjustments': 'Use simple words.',
      };

      final compositeTemplate = await PromptLoader.buildComposite(
        'text_simplifier',
        'base.tmpl',
        ['explain_changes.tmpl', 'define_terms.tmpl'],
        variables,
      );

      expect(compositeTemplate, contains('elementary'));
      expect(compositeTemplate, contains('This is a test sentence.'));
      expect(compositeTemplate, contains('Use simple words.'));
      expect(compositeTemplate, contains('EXPLAIN CHANGES'));
      expect(compositeTemplate, contains('DEFINE KEY TERMS'));
    });

    test('should validate required variables', () async {
      final template = 'Hello {{name}}, welcome to {{app_name}}!';
      final requiredVars = PromptLoader.getRequiredVariables(template);

      expect(requiredVars, contains('name'));
      expect(requiredVars, contains('app_name'));
      expect(requiredVars.length, equals(2));
    });

    test('should throw exception for missing variables', () async {
      final template = 'Hello {{name}}!';
      final variables = <String, String>{}; // Missing 'name'

      expect(
        () => PromptLoader.fill(template, variables),
        throwsA(isA<PromptVariableException>()),
      );
    });

    test('should handle template loading errors gracefully', () async {
      expect(
        () => PromptLoader.load('nonexistent', 'template.tmpl'),
        throwsA(isA<PromptLoadingException>()),
      );
    });
  });
}
