import 'dart:io';
import 'dart:async';

class OcrService {
  
  Future<String> extractTextFromImage(File imageFile) async {
    await Future.delayed(const Duration(seconds: 2));
    
    return '''The quick brown fox jumps over the lazy dog. 
This is a sample text extracted from the image.
Reading is a wonderful skill that helps us learn and explore new worlds.
Practice makes perfect when it comes to reading aloud.''';
  }

  Future<String> processImageForReading(File imageFile) async {
    final extractedText = await extractTextFromImage(imageFile);
    
    return cleanAndFormatText(extractedText);
  }

  String cleanAndFormatText(String rawText) {
    return rawText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\.\,\!\?\;\:]'), '')
        .trim();
  }
} 