import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class FontPreferenceService {
  static const String _fontPreferenceKey = 'dyslexic_ai_font_preference';
  static const String _robotoFont = 'Roboto';
  static const String _openDyslexicFont = 'OpenDyslexic';

  // Singleton pattern
  static final FontPreferenceService _instance = FontPreferenceService._internal();
  factory FontPreferenceService() => _instance;
  FontPreferenceService._internal();

  // Notifier for font changes
  final ValueNotifier<String> fontNotifier = ValueNotifier<String>(_robotoFont);

  /// Get the current font preference
  /// Returns 'Roboto' by default, 'OpenDyslexic' if user has selected it
  Future<String> getCurrentFont() async {
    final prefs = await SharedPreferences.getInstance();
    final isOpenDyslexic = prefs.getBool(_fontPreferenceKey) ?? false;
    final font = isOpenDyslexic ? _openDyslexicFont : _robotoFont;
    
    developer.log('Current font preference: $font', name: 'dyslexic_ai.font_preference');
    return font;
  }

  /// Check if OpenDyslexic font is currently selected
  Future<bool> isOpenDyslexicSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fontPreferenceKey) ?? false;
  }

  /// Set font preference
  /// @param useOpenDyslexic: true for OpenDyslexic, false for Roboto
  Future<void> setFontPreference(bool useOpenDyslexic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fontPreferenceKey, useOpenDyslexic);
    
    final font = useOpenDyslexic ? _openDyslexicFont : _robotoFont;
    fontNotifier.value = font;
    
    developer.log('Font preference set to: $font', name: 'dyslexic_ai.font_preference');
  }

  /// Initialize the service and load current preference
  Future<void> init() async {
    final currentFont = await getCurrentFont();
    fontNotifier.value = currentFont;
    developer.log('FontPreferenceService initialized with font: $currentFont', name: 'dyslexic_ai.font_preference');
  }

  /// Get the font family name for the current preference
  String get currentFontFamily => fontNotifier.value;
  
  /// Get the current font family for use in TextStyle
  /// This is a synchronous method that returns the current font from the notifier
  String getCurrentFontFamily() => fontNotifier.value;

  /// Get Roboto font family name
  static String get robotoFont => _robotoFont;

  /// Get OpenDyslexic font family name  
  static String get openDyslexicFont => _openDyslexicFont;
} 