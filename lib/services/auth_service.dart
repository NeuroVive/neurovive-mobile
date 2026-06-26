import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_constants.dart';
import 'api_config.dart';

class AuthService {
  static const _loggedInKey = 'auth_logged_in';
  static const _tokenKey = 'auth_token';
  static const _mockUsernameKey = 'mock_auth_username';
  static const _mockPasswordKey = 'mock_auth_password';

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    if (!AppConstants.useRealAuth) {
      return _mockRegister(username: username, password: password);
    }

    return _sendAuthRequest(
      endpoint: '/register',
      username: username,
      password: password,
    );
  }

  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    if (!AppConstants.useRealAuth) {
      return _mockLogin(username: username, password: password);
    }

    return _sendAuthRequest(
      endpoint: '/login',
      username: username,
      password: password,
    );
  }

  Future<AuthResult> _sendAuthRequest({
    required String endpoint,
    required String username,
    required String password,
  }) async {
    try {
      final baseUrl = await ApiConfig.loadBaseUrl();
      if (baseUrl.isEmpty) {
        return const AuthResult.failure(
          'Could not load the API URL. Make sure the server URL is configured.',
        );
      }

      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: const {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      Map<String, dynamic>? body;
      String? textMessage;
      if (response.body.isNotEmpty) {
        final decoded = _tryDecodeJson(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          textMessage = response.body;
        }
      }

      final message = body?['message']?.toString() ?? textMessage;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult.failure(message ?? 'Authentication failed.');
      }

      final prefs = await SharedPreferences.getInstance();
      final token =
          body?['token']?.toString() ?? body?['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await prefs.setString(_tokenKey, token);
      }
      await prefs.setBool(_loggedInKey, true);

      return AuthResult.success(message);
    } on SocketException {
      return const AuthResult.failure(
        'Could not connect to the server. Make sure it is running.',
      );
    } catch (e) {
      return AuthResult.failure('Authentication failed: $e');
    }
  }

  Future<AuthResult> _mockRegister({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mockUsernameKey, username);
    await prefs.setString(_mockPasswordKey, password);
    await prefs.setBool(_loggedInKey, true);
    await prefs.remove(_tokenKey);
    return const AuthResult.success();
  }

  Future<AuthResult> _mockLogin({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_mockUsernameKey);
    final savedPassword = prefs.getString(_mockPasswordKey);
    final matched = username == savedUsername && password == savedPassword;

    if (!matched) {
      return const AuthResult.failure('Invalid username or password');
    }

    await prefs.setBool(_loggedInKey, true);
    await prefs.remove(_tokenKey);
    return const AuthResult.success();
  }

  Object? _tryDecodeJson(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } on FormatException {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    await prefs.remove(_tokenKey);
  }
}

class AuthResult {
  const AuthResult._({
    required this.success,
    this.message,
  });

  const AuthResult.success([String? message])
      : this._(success: true, message: message);

  const AuthResult.failure(String message)
      : this._(success: false, message: message);

  final bool success;
  final String? message;
}
