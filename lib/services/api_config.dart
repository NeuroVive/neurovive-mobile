import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class ApiConfig {
  static const String _appBaseUrlSource =
      'https://gist.githubusercontent.com/EveryTGames/93816d02d5a780bbb48883c1c4dda8d6/raw/neurovive%2520testing%2520gist.txt';
  static const String _aiBaseUrlSource =
      String.fromEnvironment('AI_BASE_URL_SOURCE', defaultValue: '');
  static const String _aiBaseUrlOverride =
      String.fromEnvironment('AI_BASE_URL', defaultValue: '');

  static String _baseUrl = "";
  static String _aiBaseUrl = "";

  static Future<String> loadBaseUrl() async {
    _baseUrl = await _loadRemoteUrl(_appBaseUrlSource);
    return _baseUrl;
  }

  static Future<String> loadAiBaseUrl() async {
    if (_aiBaseUrlOverride.trim().isNotEmpty) {
      _aiBaseUrl = _aiBaseUrlOverride.trim();
      return _aiBaseUrl;
    }

    final source = _aiBaseUrlSource.trim().isNotEmpty
        ? _aiBaseUrlSource.trim()
        : _appBaseUrlSource;
    _aiBaseUrl = await _loadRemoteUrl(source);
    return _aiBaseUrl;
  }

  static Future<String> _loadRemoteUrl(String source) async {
    try {
      final uri = Uri.parse(
        '$source?timestamp=${DateTime.timestamp().microsecondsSinceEpoch}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        if (document.body == null) {
          throw Exception('API URL response has no body');
        }
        return document.body!.innerHtml.trim();
      } else {
        throw Exception('Failed to load API URL');
      }
    } catch (e) {
      print("error happened: $e");
      return "";
    }
  }

  static String get baseUrl => _baseUrl;
  static String get aiBaseUrl => _aiBaseUrl;
}
