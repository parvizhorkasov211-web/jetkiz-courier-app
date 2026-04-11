import '../data/auth_repository.dart';
import 'auth_entity.dart';

class AuthUseCase {
  final AuthRepository repo;

  AuthUseCase(this.repo);

  Future<void> requestCode(String phone) {
    return repo.requestCode(phone);
  }

  Future<AuthSession> verifyCode(String phone, String code) {
    return repo.verifyCode(phone, code);
  }
}