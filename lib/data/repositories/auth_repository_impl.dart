import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<({User user, String token})> login(String email, String password) async {
    return await remoteDataSource.login(email, password);
  }

  @override
  Future<({User user, String token})> register(String name, String email, String password) async {
    return await remoteDataSource.register(name, email, password);
  }

  @override
  Future<User> getProfile() async {
    return await remoteDataSource.getProfile();
  }

  @override
  Future<User?> getSavedUser() async {
    return await remoteDataSource.getSavedUser();
  }

  @override
  Future<User> updateProfile(String name, String email) async {
    return await remoteDataSource.updateProfile(name, email);
  }

  @override
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    return await remoteDataSource.updatePassword(currentPassword, newPassword);
  }

  @override
  Future<void> logout() async {
    return await remoteDataSource.logout();
  }
}
