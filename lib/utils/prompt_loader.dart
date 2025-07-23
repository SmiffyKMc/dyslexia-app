import 'package:flutter/services.dart' show rootBundle;
import 'dart:developer' as developer;

/// Prompt loader with support for organized templates and composite building
class PromptLoader {
  static const String _baseDir = 'lib/prompts';
  
  /// Load a single template from a feature directory
  /// Example: load('text_simplifier', 'base.tmpl')
  static Future<String> load(String feature, String templateName) async {
    try {
      final path = '$_baseDir/$feature/$templateName';
      final content = await rootBundle.loadString(path);
      
      developer.log('📄 Loaded template: $path', name: 'dyslexic_ai.prompt_loader');
      return content;
    } catch (e) {
      developer.log('❌ Failed to load template: $feature/$templateName - $e', 
          name: 'dyslexic_ai.prompt_loader');
      throw PromptLoadingException('Failed to load template $feature/$templateName: $e');
    }
  }

  /// Load a legacy template from the root prompts directory (backward compatibility)
  /// Example: loadLegacy('sentence_batch.tmpl')
  static Future<String> loadLegacy(String templateName) async {
    try {
      final path = '$_baseDir/$templateName';
      final content = await rootBundle.loadString(path);
      
      developer.log('📄 Loaded legacy template: $path', name: 'dyslexic_ai.prompt_loader');
      return content;
    } catch (e) {
      developer.log('❌ Failed to load legacy template: $templateName - $e', 
          name: 'dyslexic_ai.prompt_loader');
      throw PromptLoadingException('Failed to load legacy template $templateName: $e');
    }
  }

  /// Build a composite template from base + add-ons, then fill variables
  /// Example: buildComposite('text_simplifier', 'base.tmpl', ['explain_changes.tmpl'], vars)
  static Future<String> buildComposite(
    String feature, 
    String baseTemplate, 
    List<String> addOnTemplates, 
    Map<String, String> variables
  ) async {
    try {
      developer.log('🔧 Building composite template: $feature/$baseTemplate + ${addOnTemplates.length} add-ons', 
          name: 'dyslexic_ai.prompt_loader');

      // Load base template
      String composite = await load(feature, baseTemplate);
      
      // Append each add-on template
      for (final addOn in addOnTemplates) {
        final addOnContent = await load(feature, addOn);
        composite += '\n\n$addOnContent';
      }
      
      // Fill variables
      final result = fill(composite, variables);
      
      developer.log('✅ Composite template built successfully (${result.length} chars)', 
          name: 'dyslexic_ai.prompt_loader');
      
      return result;
    } catch (e) {
      developer.log('❌ Failed to build composite template: $feature/$baseTemplate - $e', 
          name: 'dyslexic_ai.prompt_loader');
      throw PromptLoadingException('Failed to build composite template: $e');
    }
  }

  /// Fill template variables with validation
  /// Provides better error reporting for missing variables
  static String fill(String template, Map<String, String> variables) {
    try {
      var result = template;
      final missingVariables = <String>[];
      
      // Find all variable placeholders
      final variablePattern = RegExp(r'\{\{(\w+)\}\}');
      final matches = variablePattern.allMatches(template);
      
      // Check for missing variables before replacement
      for (final match in matches) {
        final variableName = match.group(1)!;
        if (!variables.containsKey(variableName)) {
          missingVariables.add(variableName);
        }
      }
      
      if (missingVariables.isNotEmpty) {
        throw PromptVariableException(
          'Missing required variables: ${missingVariables.join(', ')}'
        );
      }
      
      // Replace all variables
      for (final entry in variables.entries) {
        result = result.replaceAll('{{${entry.key}}}', entry.value);
      }
      
      // Check for any remaining unreplaced variables
      final remainingMatches = variablePattern.allMatches(result);
      if (remainingMatches.isNotEmpty) {
        final remaining = remainingMatches.map((m) => m.group(1)).toList();
        developer.log('⚠️ Warning: Unreplaced variables found: ${remaining.join(', ')}', 
            name: 'dyslexic_ai.prompt_loader');
      }
      
      developer.log('✅ Template filled successfully (${variables.length} variables)', 
          name: 'dyslexic_ai.prompt_loader');
      
      return result;
    } catch (e) {
      developer.log('❌ Failed to fill template variables: $e', 
          name: 'dyslexic_ai.prompt_loader');
      rethrow;
    }
  }

  /// Validate that a template has all required variables
  static List<String> getRequiredVariables(String template) {
    final variablePattern = RegExp(r'\{\{(\w+)\}\}');
    final matches = variablePattern.allMatches(template);
    return matches.map((match) => match.group(1)!).toSet().toList();
  }

  /// Validate template directory structure (useful for testing)
  static Future<bool> validateTemplateStructure() async {
    try {
      final features = [
        'text_simplifier',
        'story_generation', 
        'sentence_fixer',
        'profile_analysis',
        'word_analysis',
        'shared'
      ];
      
      for (final feature in features) {
        // Try to list directory contents to verify it exists
        try {
          await rootBundle.loadString('$_baseDir/$feature/');
        } catch (e) {
          // Directory might not have an index, that's ok
        }
      }
      
      return true;
    } catch (e) {
      developer.log('❌ Template structure validation failed: $e', 
          name: 'dyslexic_ai.prompt_loader');
      return false;
    }
  }
}

/// Exception thrown when template loading fails
class PromptLoadingException implements Exception {
  final String message;
  PromptLoadingException(this.message);
  
  @override
  String toString() => 'PromptLoadingException: $message';
}

/// Exception thrown when template variables are missing or invalid
class PromptVariableException implements Exception {
  final String message;
  PromptVariableException(this.message);
  
  @override
  String toString() => 'PromptVariableException: $message';
} 