import '../domain/auth_entity.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository(this._api);

  final AuthApi _api;

  Future<void> requestCode(String phone) {
    return _api.requestCode(phone);
  }

  Future<AuthSession> verifyCode(String phone, String code) async {
    final result = await _api.verifyCode(
      phone: phone,
      code: code,
    );

    final accessToken = (result['accessToken'] ?? '').toString();
    final refreshToken = (result['refreshToken'] ?? '').toString();

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw Exception('Tokens not found in verify response');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}