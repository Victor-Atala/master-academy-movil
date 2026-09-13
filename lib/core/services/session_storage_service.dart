import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/user_model.dart';

/// Servicio centralizado de sesión con Doble Persistencia:
/// 1. Almacenamiento seguro primario (FlutterSecureStorage con resetOnError: false).
/// 2. Bóveda local secundaria (session_vault.json en el sandbox privado de la app).
/// Es 100% inmune a reinicios de Android Keystore, borrados accidentales de SharedPreferences y cierres de la app.
class SessionStorageService {
  final FlutterSecureStorage _secureStorage;

  static const String _tokenKey = 'jwt_auth_token';
  static const String _userKey = 'auth_user_data';
  static const String _lastActivityKey = 'session_last_activity';
  static const String _biometricKey = 'user_biometrics_enabled';
  static const String _vaultFileName = 'session_vault.json';

  static const AndroidOptions safeAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: false,
  );

  // Caché en memoria para acceso síncrono ultra rápido y libre de condiciones de carrera
  String? _cachedToken;
  UserModel? _cachedUser;
  int? _cachedLastActivity;
  bool? _cachedBiometric;

  SessionStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(aOptions: safeAndroidOptions);

  Future<File> _getVaultFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_vaultFileName');
  }

  Future<Map<String, dynamic>?> _readVaultFile() async {
    try {
      final file = await _getVaultFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      }
    } catch (e) {
      debugPrint('[SessionVault] Error reading vault file: $e');
    }
    return null;
  }

  Future<void> _writeVaultFile(Map<String, dynamic> data) async {
    try {
      final file = await _getVaultFile();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[SessionVault] Error writing vault file: $e');
    }
  }

  /// Guarda la sesión completa en memoria, SecureStorage y Bóveda de archivos
  Future<void> saveSession({
    required String token,
    required UserModel user,
    int? lastActivityMs,
  }) async {
    final now = lastActivityMs ?? DateTime.now().millisecondsSinceEpoch;
    _cachedToken = token;
    _cachedUser = user;
    _cachedLastActivity = now;

    // 1. Guardar en SecureStorage
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
      await _secureStorage.write(key: _lastActivityKey, value: now.toString());
    } catch (e) {
      debugPrint('[SessionVault] SecureStorage write error: $e');
    }

    // 2. Guardar en Bóveda Local (persistente contra cierres y reinicios)
    final vaultData = <String, dynamic>{
      'token': token,
      'user': user.toJson(),
      'last_activity': now,
      'biometrics_enabled': _cachedBiometric ?? true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _writeVaultFile(vaultData);
  }

  /// Lee la sesión restaurando automáticamente desde Bóveda si SecureStorage falló
  Future<({String? token, UserModel? user, int? lastActivityMs})> readSession() async {
    // Si ya está en memoria y es válido, retornarlo
    if (_cachedToken != null && _cachedToken!.isNotEmpty && _cachedUser != null) {
      return (
        token: _cachedToken,
        user: _cachedUser,
        lastActivityMs: _cachedLastActivity,
      );
    }

    String? token;
    UserModel? user;
    int? lastActivity;

    // 1. Intentar leer de SecureStorage
    try {
      token = await _secureStorage.read(key: _tokenKey);
      final userJson = await _secureStorage.read(key: _userKey);
      final activityStr = await _secureStorage.read(key: _lastActivityKey);

      if (activityStr != null) {
        lastActivity = int.tryParse(activityStr);
      }
      if (userJson != null && userJson.trim().isNotEmpty) {
        final decoded = jsonDecode(userJson);
        if (decoded is Map<String, dynamic>) {
          user = UserModel.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[SessionVault] SecureStorage read warning: $e');
    }

    // 2. Si falta el token o el usuario, recurrir a la Bóveda Local
    if (token == null || token.isEmpty || user == null) {
      final vault = await _readVaultFile();
      if (vault != null) {
        final vaultToken = vault['token']?.toString();
        final vaultUserMap = vault['user'];
        final vaultActivity = vault['last_activity'];

        if (vaultToken != null && vaultToken.isNotEmpty && vaultUserMap is Map<String, dynamic>) {
          token = vaultToken;
          user = UserModel.fromJson(vaultUserMap);
          if (vaultActivity is int) {
            lastActivity = vaultActivity;
          } else if (vaultActivity != null) {
            lastActivity = int.tryParse(vaultActivity.toString());
          }

          // Autorreparar SecureStorage en segundo plano
          try {
            await _secureStorage.write(key: _tokenKey, value: token);
            await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
            if (lastActivity != null) {
              await _secureStorage.write(key: _lastActivityKey, value: lastActivity.toString());
            }
          } catch (_) {}
        }
      }
    }

    _cachedToken = token;
    _cachedUser = user;
    _cachedLastActivity = lastActivity;

    return (
      token: token,
      user: user,
      lastActivityMs: lastActivity,
    );
  }

  /// Retorna el token JWT actual de forma confiable
  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    final session = await readSession();
    return session.token;
  }

  /// Guarda únicamente el token
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {}

    final vault = await _readVaultFile() ?? <String, dynamic>{};
    vault['token'] = token;
    vault['updated_at'] = DateTime.now().toIso8601String();
    await _writeVaultFile(vault);
  }

  /// Limpia el token
  Future<void> clearToken() async {
    _cachedToken = null;
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {}

    final vault = await _readVaultFile();
    if (vault != null) {
      vault.remove('token');
      await _writeVaultFile(vault);
    }
  }

  /// Obtiene el JSON del usuario
  Future<String?> getUserJson() async {
    if (_cachedUser != null) {
      return jsonEncode(_cachedUser!.toJson());
    }
    final session = await readSession();
    if (session.user != null) {
      return jsonEncode(session.user!.toJson());
    }
    return null;
  }

  /// Guarda el JSON del usuario
  Future<void> saveUserJson(String userJson) async {
    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        _cachedUser = UserModel.fromJson(decoded);
      }
    } catch (_) {}

    try {
      await _secureStorage.write(key: _userKey, value: userJson);
    } catch (_) {}

    final vault = await _readVaultFile() ?? <String, dynamic>{};
    if (_cachedUser != null) {
      vault['user'] = _cachedUser!.toJson();
    }
    await _writeVaultFile(vault);
  }

  /// Limpia los datos de usuario
  Future<void> clearUser() async {
    _cachedUser = null;
    try {
      await _secureStorage.delete(key: _userKey);
    } catch (_) {}

    final vault = await _readVaultFile();
    if (vault != null) {
      vault.remove('user');
      await _writeVaultFile(vault);
    }
  }

  /// Retorna la marca de tiempo de la última actividad
  Future<int?> getLastActivity() async {
    if (_cachedLastActivity != null) return _cachedLastActivity;
    final session = await readSession();
    return session.lastActivityMs;
  }

  /// Registra una nueva marca de actividad para la regla de los 7 días
  Future<void> recordActivity([int? timestampMs]) async {
    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    _cachedLastActivity = now;

    try {
      await _secureStorage.write(key: _lastActivityKey, value: now.toString());
    } catch (_) {}

    try {
      final vault = await _readVaultFile();
      if (vault != null) {
        vault['last_activity'] = now;
        await _writeVaultFile(vault);
      }
    } catch (_) {}
  }

  /// Borra la sesión por completo (al cerrar sesión voluntariamente o por inactividad > 7 días)
  Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUser = null;
    _cachedLastActivity = null;

    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
      await _secureStorage.delete(key: _lastActivityKey);
    } catch (_) {}

    try {
      final file = await _getVaultFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Guarda la preferencia biométrica en ambas capas
  Future<void> saveBiometricPreference(bool enabled) async {
    _cachedBiometric = enabled;
    try {
      await _secureStorage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
    } catch (_) {}

    try {
      final vault = await _readVaultFile() ?? <String, dynamic>{};
      vault['biometrics_enabled'] = enabled;
      await _writeVaultFile(vault);
    } catch (_) {}
  }

  /// Lee la preferencia biométrica de ambas capas
  Future<bool?> getBiometricPreference() async {
    if (_cachedBiometric != null) return _cachedBiometric;

    try {
      final val = await _secureStorage.read(key: _biometricKey);
      if (val != null) {
        _cachedBiometric = val == 'true';
        return _cachedBiometric;
      }
    } catch (_) {}

    final vault = await _readVaultFile();
    if (vault != null && vault.containsKey('biometrics_enabled')) {
      final val = vault['biometrics_enabled'];
      if (val is bool) {
        _cachedBiometric = val;
        return _cachedBiometric;
      }
    }

    return null;
  }
}
