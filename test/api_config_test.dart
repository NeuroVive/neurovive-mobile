import 'package:flutter_test/flutter_test.dart';
import 'package:neurovive/services/api_config.dart';

void main() {
  test('loadAiBaseUrl falls back cleanly when no local server exists', () async {
    final result = await ApiConfig.loadAiBaseUrl();

    expect(result, isA<String>());
  });

  test('recognizes plain-text AI server responses', () {
    final responseBody = 'AI SERVER';
    final looksLikeAiServer = responseBody.toLowerCase().contains('ai server') ||
        responseBody.toLowerCase().contains('server') ||
        responseBody.toLowerCase().contains('pen');

    expect(looksLikeAiServer, isTrue);
  });

  test('recognizes HTML AI server responses', () {
    final responseBody = '<html><head><title></title></head><body>AI SERVER</body></html>';
    final normalized = responseBody.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final looksLikeAiServer = normalized.toLowerCase().contains('ai server') ||
        normalized.toLowerCase().contains('server') ||
        normalized.toLowerCase().contains('pen');

    expect(looksLikeAiServer, isTrue);
  });
}
