import 'package:flutter/foundation.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../domain/auth_usecase.dart';

class AuthController extends ChangeNotifier {
  AuthController()
    : _useCase = AuthUseCase(
        AuthRepository(
          AuthApi(),
        ),
      );

  final AuthUseCase _useCase;

  bool isLoading = false;
  String error = '';

  Future<bool> requestCode(String phone) async {
    try {
      error = '';
      isLoading = true;
      notifyListeners();

      await _useCase.requestCode(phone);
      return true;
    } catch (e) {
      error = 'Не удалось отправить код';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyCode(String phone, String code) async {
    try {
      error = '';
      isLoading = true;
      notifyListeners();

      final session = await _useCase.verifyCode(phone, code);

      await TokenStorage().saveTokens(
        session.accessToken,
        session.refreshToken,
      );

      return true;
    } catch (e) {
      error = 'Неверный код';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await TokenStorage().clear();
    error = '';
    isLoading = false;
    notifyListeners();
  }
}