import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/notification_permission_service.dart';
import '../../core/services/session_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/auth_usecase.dart';
import 'course_viewmodel.dart';

enum AuthStatus { unauthenticated, authenticating, syncing, authenticated }

class AuthViewModel extends ChangeNotifier {
  final AuthUseCase? _authUseCase;
  final BiometricService _biometricService;
  final NotificationPermissionService _permissionService;
  final FlutterSecureStorage _storage;
  final SessionStorageService _sessionStorage;

  static const int oneWeekMs = 7 * 24 * 60 * 60 * 1000; // 7 días exactos en milisegundos
  static const String _lastActivityKey = 'session_last_activity';

  bool _isRestoring = false;

  AuthViewModel({
    AuthUseCase? authUseCase,
    BiometricService? biometricService,
    NotificationPermissionService? permissionService,
    FlutterSecureStorage? storage,
    SessionStorageService? sessionStorage,
  })  : _authUseCase = authUseCase,
        _biometricService = biometricService ?? BiometricService(),
        _permissionService = permissionService ?? NotificationPermissionService(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: false,
              ),
            ),
        _sessionStorage = sessionStorage ??
            SessionStorageService(
              secureStorage: storage ??
                  const FlutterSecureStorage(
                    aOptions: AndroidOptions(
                      encryptedSharedPreferences: true,
                      resetOnError: false,
                    ),
                  ),
            );

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  User? _currentUser;
  User? get currentUser => _currentUser;

  String? get currentUserEmail => _currentUser?.email ?? _cachedEmail;
  String? get currentUserName => _currentUser?.name ?? _cachedName;

  String? _cachedEmail;
  String? _cachedName;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Registra la marca de tiempo de actividad reciente en ambas capas
  Future<void> recordActivity() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sessionStorage.recordActivity(now);
    try {
      await _storage.write(
        key: _lastActivityKey,
        value: now.toString(),
      );
    } catch (_) {}
  }

  /// Verifica si han transcurrido más de 7 días de inactividad
  Future<void> checkInactivityOrRecordActivity() async {
    if (_status != AuthStatus.authenticated) return;
    try {
      int? lastActivity = await _sessionStorage.getLastActivity();

      if (lastActivity == null) {
        final lastActivityStr = await _storage.read(key: _lastActivityKey);
        if (lastActivityStr != null) {
          lastActivity = int.tryParse(lastActivityStr);
        }
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      if (lastActivity != null && (now - lastActivity) > oneWeekMs) {
        // Expirado estrictamente tras 7 días de inactividad
        await logout();
        return;
      }
      await recordActivity();
    } catch (_) {}
  }

  /// Restaura la sesión persistente de forma segura y garantiza la regla de 7 días
  Future<void> restoreSession() async {
    if (_isRestoring) return;
    _isRestoring = true;

    try {
      User? user;
      int? lastActivity;

      // 1. Intentar leer desde SessionStorageService (SecureStorage + Bóveda local)
      final session = await _sessionStorage.readSession();
      if (session.user != null) {
        user = session.user;
        lastActivity = session.lastActivityMs;
      }

      // 2. Si no se obtuvo, intentar mediante AuthUseCase
      if (user == null && _authUseCase != null) {
        try {
          user = await _authUseCase!.getSavedUser();
        } catch (_) {}
      }

      // 3. Si se localizó el usuario, comprobar la regla de 7 días de inactividad
      if (user != null) {
        if (lastActivity == null) {
          try {
            final lastActivityStr = await _storage.read(key: _lastActivityKey);
            if (lastActivityStr != null) {
              lastActivity = int.tryParse(lastActivityStr);
            }
          } catch (_) {}
        }

        final int now = DateTime.now().millisecondsSinceEpoch;

        if (lastActivity != null && (now - lastActivity) > oneWeekMs) {
          // Sesión expirada únicamente tras 7 días de inactividad continua
          await logout();
          return;
        }

        // Sesión válida dentro del rango de 7 días: Mantener autenticado
        _currentUser = user;
        _cachedEmail = user.email;
        _cachedName = user.name;
        _status = AuthStatus.authenticated;
        await recordActivity();
        notifyListeners();

        if (sl.isRegistered<CourseViewModel>()) {
          sl<CourseViewModel>().fetchLearningCourses(force: true);
        }
        return;
      }
    } catch (_) {
    } finally {
      _isRestoring = false;
    }

    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Por favor ingresa correo y contraseña.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      String token = '';
      if (_authUseCase != null) {
        final result = await _authUseCase!.login(email, password);
        _currentUser = result.user;
        _cachedEmail = result.user.email;
        _cachedName = result.user.name;
        token = result.token;
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        _cachedEmail = email.trim();
        _cachedName = email.split('@').first;
        _currentUser = User(id: 1, name: _cachedName!, email: _cachedEmail!);
        token = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Sincronización
      _status = AuthStatus.syncing;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 400));

      // Habilitar biometría y solicitar permisos de notificación fluidamente
      await BiometricService.enableBiometricAfterFirstLogin(sessionStorage: _sessionStorage);
      await _permissionService.requestNotificationPermission();

      if (_currentUser != null) {
        final userModel = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          avatar: _currentUser!.avatar,
          role: _currentUser!.role,
        );

        await _sessionStorage.saveSession(
          token: token.isNotEmpty ? token : 'jwt_token_${DateTime.now().millisecondsSinceEpoch}',
          user: userModel,
        );

        try {
          await _storage.write(key: 'last_authenticated_user_email', value: _currentUser!.email);
          await _storage.write(key: 'last_authenticated_user_name', value: _currentUser!.name);
        } catch (_) {}
      }

      _status = AuthStatus.authenticated;
      await recordActivity();
      notifyListeners();
      if (sl.isRegistered<CourseViewModel>()) {
        sl<CourseViewModel>().fetchLearningCourses(force: true);
      }
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    final bool authenticated = await _biometricService.authenticate();
    if (authenticated) {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      User? savedUser;
      final session = await _sessionStorage.readSession();
      savedUser = session.user;

      if (savedUser == null && _authUseCase != null) {
        savedUser = await _authUseCase!.getSavedUser();
      }

      if (savedUser != null) {
        _currentUser = savedUser;
        _cachedEmail = savedUser.email;
        _cachedName = savedUser.name;
      } else {
        String? lastEmail;
        String? lastName;
        try {
          lastEmail = await _storage.read(key: 'last_authenticated_user_email');
          lastName = await _storage.read(key: 'last_authenticated_user_name');
        } catch (_) {}
        _cachedEmail = lastEmail ?? _cachedEmail ?? 'usuario@masteracademy.com';
        _cachedName = lastName ?? _cachedName ?? 'Usuario Master';
        _currentUser = User(id: 1, name: _cachedName!, email: _cachedEmail!);
      }

      _status = AuthStatus.syncing;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      _status = AuthStatus.authenticated;
      await recordActivity();
      notifyListeners();
      if (sl.isRegistered<CourseViewModel>()) {
        sl<CourseViewModel>().fetchLearningCourses(force: true);
      }
      return true;
    } else {
      _errorMessage = 'Autenticación biométrica fallida o no habilitada.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Por favor completa todos los campos requeridos.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      String token = '';
      if (_authUseCase != null) {
        final result = await _authUseCase!.register(name, email, password);
        _currentUser = result.user;
        _cachedEmail = result.user.email;
        _cachedName = result.user.name;
        token = result.token;
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        _cachedName = name.trim();
        _cachedEmail = email.trim();
        _currentUser = User(id: 1, name: _cachedName!, email: _cachedEmail!);
        token = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
      }

      await BiometricService.enableBiometricAfterFirstLogin(sessionStorage: _sessionStorage);
      await _permissionService.requestNotificationPermission();

      _status = AuthStatus.syncing;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 400));

      if (_currentUser != null) {
        final userModel = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          avatar: _currentUser!.avatar,
          role: _currentUser!.role,
        );

        await _sessionStorage.saveSession(
          token: token.isNotEmpty ? token : 'jwt_token_${DateTime.now().millisecondsSinceEpoch}',
          user: userModel,
        );

        try {
          await _storage.write(key: 'last_authenticated_user_email', value: _currentUser!.email);
          await _storage.write(key: 'last_authenticated_user_name', value: _currentUser!.name);
        } catch (_) {}
      }

      _status = AuthStatus.authenticated;
      await recordActivity();
      notifyListeners();
      if (sl.isRegistered<CourseViewModel>()) {
        sl<CourseViewModel>().fetchLearningCourses(force: true);
      }
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    if (currentPassword.trim().isEmpty || newPassword.trim().isEmpty) {
      _errorMessage = 'Por favor ingresa tu contraseña actual y la nueva contraseña.';
      notifyListeners();
      return false;
    }

    try {
      if (_authUseCase != null) {
        await _authUseCase!.updatePassword(currentPassword, newPassword);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _sessionStorage.clearSession();
    } catch (_) {}

    if (_authUseCase != null) {
      try {
        await _authUseCase!.logout();
      } catch (_) {}
    }
    try {
      await _storage.delete(key: _lastActivityKey);
    } catch (_) {}
    try {
      if (sl.isRegistered<CourseViewModel>()) {
        await sl<CourseViewModel>().clearEnrolledCourses();
      }
    } catch (_) {}
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _cachedEmail = null;
    _cachedName = null;
    _errorMessage = null;
    notifyListeners();
  }
}
