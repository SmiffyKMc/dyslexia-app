import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('CDN Model URL Tests', () {
    test('CDN model URL should be accessible', () async {
      const String modelUrl = 'https://kaggle-gemma3.b-cdn.net/gemma-3n-E2B-it-int4.task';
      
      try {
        // Make a HEAD request to check if the URL is accessible
        final response = await http.head(Uri.parse(modelUrl));
        
        // Check that the response is successful (200-299 range)
        expect(response.statusCode, lessThan(400), 
               reason: 'CDN URL should be accessible. Status: ${response.statusCode}');
        
        // Check that it's a substantial file (should be multi-GB)
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          final fileSizeBytes = int.parse(contentLength);
          // Expect at least 1GB (1024^3 bytes)
          expect(fileSizeBytes, greaterThan(1024 * 1024 * 1024), 
                 reason: 'Model file should be larger than 1GB. Size: ${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB');
        }
        
        if (contentLength != null) {
        }
        
      } catch (e) {
        fail('Failed to access CDN URL: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
} 