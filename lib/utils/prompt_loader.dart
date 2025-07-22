import 'package:flutter/services.dart' show rootBundle;

class PromptLoader {
  static Future<String> load(String name) {
    return rootBundle.loadString('lib/prompts/$name');
  }

  static String fill(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
} 