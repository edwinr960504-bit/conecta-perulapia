import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MobileSession {
  MobileSession._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'mobile_access_token';
  static String? _accessToken;

  static String? get accessToken => _accessToken;
  static bool get isAuthenticated => _accessToken != null;

  static Future<void> restore() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  static Future<void> save(String token) async {
    if (token.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Must not be empty.');
    }
    await _storage.write(key: _tokenKey, value: token);
    _accessToken = token;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    _accessToken = null;
  }

  static Future<void> logout(String apiBaseUrl) async {
    final token = _accessToken;
    if (token == null) return;
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/mobile/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError(
          'El servidor no confirmó el cierre de sesión '
          '(HTTP ${response.statusCode}).',
        );
      }
    } finally {
      await clear();
    }
  }
}
