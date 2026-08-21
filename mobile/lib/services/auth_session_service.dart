import 'auth_token_service.dart';
import 'phone_auth_api_service.dart';

class AuthSessionService {
  final PhoneAuthApiService _authApiService = PhoneAuthApiService();
  final AuthTokenService _tokenService = AuthTokenService();

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _authApiService.verifyOtp(phone: phone, otp: otp);

    final registrationRequired = response['registration_required'] == true;

    if (!registrationRequired) {
      await _saveTokenFromResponse(response);
    }

    return response;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String registrationToken,
  }) async {
    final response = await _authApiService.register(
      name: name,
      registrationToken: registrationToken,
    );

    await _saveTokenFromResponse(response);

    return response;
  }

  Future<void> _saveTokenFromResponse(Map<String, dynamic> response) async {
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid authentication response.');
    }

    final token = data['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Authentication token is missing.');
    }

    final user = data['user'];

    if (user is! Map<String, dynamic>) {
      throw Exception('User data is missing.');
    }

    final userId = user['id'];

    if (userId is! int) {
      throw Exception('User ID is missing.');
    }

    await _tokenService.saveSession(token: token, userId: userId);
  }

  Future<void> requestOtp(String phone) async {
    await _authApiService.requestOtp(phone);
  }

  Future<void> logout() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty) {
      await _tokenService.clearSession();
      return;
    }

    await _authApiService.logout(token);

    await _tokenService.clearSession();
  }
}
