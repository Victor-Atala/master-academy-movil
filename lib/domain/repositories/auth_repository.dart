import '../entities/user.dart';

abstract class AuthRepository {
  Future<({User user, String token})> login(String email, String password);
  Future<({User user, String token})> register(String name, String email, String password);
  Future<User> getProfile();
  Future<User?> getSavedUser();
  Future<User> updateProfile(String name, String email);
  Future<void> updatePassword(String currentPassword, String newPassword);
  Future<void> logout();
}
