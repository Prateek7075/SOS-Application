import 'auth_token_service.dart';

class AuthenticatedApiService {
  final AuthTokenService _tokenService = AuthTokenService();

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('User is not logged in.');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> handleUnauthorized(int statusCode) async {
    if (statusCode != 401) {
      return;
    }

    await _tokenService.clearSession();

    throw Exception('Session expired. Please log in again.');
  }
}
