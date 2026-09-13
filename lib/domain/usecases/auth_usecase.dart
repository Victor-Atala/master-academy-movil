import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class AuthUseCase {
  final AuthRepository repository;

  AuthUseCase(this.repository);

  Future<({User user, String token})> login(String email, String password) async {
    return await repository.login(email, password);
  }

  Future<({User user, String token})> register(String name, String email, String password) async {
    return await repository.register(name, email, password);
  }

  Future<User> getProfile() async {
    return await repository.getProfile();
  }

  Future<User?> getSavedUser() async {
    return await repository.getSavedUser();
  }

  Future<User> updateProfile(String name, String email) async {
    return await repository.updateProfile(name, email);
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    return await repository.updatePassword(currentPassword, newPassword);
  }

  Future<void> logout() async {
    return await repository.logout();
  }
}
