import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenService {
  static const String _tokenKey = 'auth_sanctum_token';
  static const String _userIdKey = 'auth_user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }

  Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasSession() async {
    final token = await getToken();
    final userId = await getUserId();

    return token != null && token.isNotEmpty && userId != null;
  }

  Future<void> saveSession({required String token, required int userId}) async {
    try {
      await _storage.write(key: _tokenKey, value: token);

      await _storage.write(key: _userIdKey, value: userId.toString());
    } catch (_) {
      await clearSession();
      rethrow;
    }
  }
}
