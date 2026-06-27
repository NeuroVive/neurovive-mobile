import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class ApiConfig {
  static const String _appBaseUrlSource =
      'https://gist.githubusercontent.com/EveryTGames/93816d02d5a780bbb48883c1c4dda8d6/raw/neurovive%2520testing%2520gist.txt';
  static const String _aiBaseUrlSource =
      String.fromEnvironment('AI_BASE_URL_SOURCE', defaultValue: 'https://gist.githubusercontent.com/EveryTGames/57efa2115beeafc400ae641063dfb74b/raw/4ca21f673308b45a6268e832c1c9d3ba6868a3d7/gistfile1.txt');
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

    final localUrl = await _tryDetectLocalAiBaseUrl();
    if (localUrl != null && localUrl.trim().isNotEmpty) {
      _aiBaseUrl = localUrl.trim();
      return _aiBaseUrl;
    }

    final source = _aiBaseUrlSource.trim().isNotEmpty
        ? _aiBaseUrlSource.trim()
        : _appBaseUrlSource;
    _aiBaseUrl = await _loadRemoteUrl(source);
    return _aiBaseUrl;
  }

  static Future<String?> _tryDetectLocalAiBaseUrl() async {
    final priorityHosts = <String>{'localhost', '127.0.0.1', '10.0.2.2'};
    for (final host in priorityHosts) {
      final detected = await _probeLocalHost(host, port: 80, path: '/');
      if (detected != null && detected.trim().isNotEmpty) {
        return detected;
      }
    }

    final subnetHosts = await _localSubnetHosts(priorityHosts);
    for (var index = 0; index < subnetHosts.length; index += 48) {
      final batch = subnetHosts.skip(index).take(48).toList();
      final detected = await _probeHostsInBatch(batch, port: 80, path: '/');
      if (detected != null && detected.trim().isNotEmpty) {
        return detected;
      }
    }

    return null;
  }

  static Future<List<String>> _localSubnetHosts(Set<String> seenHosts) async {
    final hosts = <String>[];

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length != 4) {
            continue;
          }

          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (var hostNumber = 1; hostNumber <= 254; hostNumber++) {
            final host = '$prefix.$hostNumber';
            if (host == address.address || !seenHosts.add(host)) {
              continue;
            }
            hosts.add(host);
          }
        }
      }
    } catch (_) {
      // Fall back to common local hosts when interface enumeration fails.
      hosts.addAll(<String>{
        '192.168.1.1',
        '192.168.0.1',
        '172.16.0.1',
      });
    }

    return hosts;
  }

  static Future<String?> _probeHostsInBatch(
    List<String> hosts, {
    required int port,
    required String path,
  }) async {
    if (hosts.isEmpty) {
      return null;
    }

    final completer = Completer<String?>();
    var pending = hosts.length;

    for (final host in hosts) {
      unawaited(() async {
        try {
          final detected = await _probeLocalHost(host, port: port, path: path);
          if (detected != null && detected.trim().isNotEmpty && !completer.isCompleted) {
            completer.complete(detected);
          }
        } finally {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }());
    }

    return completer.future;
  }

  static Future<String?> _probeLocalHost(String host, {required int port, required String path}) async {
    if (host.trim().isEmpty) {
      return null;
    }

    final baseHost = host.trim().replaceAll(RegExp(r'^https?://'), '').split(':').first;
    if (baseHost.isEmpty) {
      return null;
    }

    final probeUri = Uri.parse('http://$baseHost:$port$path');

    try {
      final response = await http
          .get(
            probeUri,
            headers: {
              'Accept': 'application/json,text/plain,text/html,*/*',
              'User-Agent': 'NeuroVive-Mobile-App',
            },
          )
          .timeout(const Duration(milliseconds: 900));

      if (response.statusCode >= 200 && response.statusCode < 500) {
        final body = response.body.trim();
        if (_looksLikeAiServerResponse(body)) {
          return probeUri.toString().replaceAll(RegExp(r'/+$'), '');
        }
      }
    } catch (_) {
      // Try the next host.
    }

    return null;
  }

  static bool _looksLikeAiServerResponse(String responseBody) {
    final sanitizedBody = _sanitizeResponseBody(responseBody);
    if (sanitizedBody.trim().isEmpty) {
      return false;
    }

    String visibleText = sanitizedBody;
    try {
      final document = html_parser.parse(sanitizedBody);
      visibleText = document.body?.text ?? document.documentElement?.text ?? sanitizedBody;
    } catch (_) {
      // Fall back to the sanitized plain text body if the HTML parser rejects it.
    }

    final normalizedText = _sanitizeResponseBody(visibleText)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    return normalizedText.contains('ai server') ||
        normalizedText.contains('ai') && normalizedText.contains('server') ||
        normalizedText.contains('server') ||
        normalizedText.contains('pen');
  }

  static String _sanitizeResponseBody(String responseBody) {
    return responseBody
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\u007F]'), '')
        .replaceAll('\u0000', '');
  }

  static Future<String> _loadRemoteUrl(String source) async {
    try {
      final uri = Uri.parse(
        '$source?timestamp=${DateTime.timestamp().microsecondsSinceEpoch}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final sanitizedBody = _sanitizeResponseBody(response.body);
        final document = html_parser.parse(sanitizedBody);
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
