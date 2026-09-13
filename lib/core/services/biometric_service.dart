import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'session_storage_service.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage;
  final SessionStorageService _sessionStorage;
  static const String _biometricKey = 'user_biometrics_enabled';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: false,
  );

  BiometricService({
    SessionStorageService? sessionStorage,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(aOptions: _androidOptions),
        _sessionStorage = sessionStorage ??
            SessionStorageService(
              secureStorage: storage ?? const FlutterSecureStorage(aOptions: _androidOptions),
            );

  static bool? _cachedBiometricEnabled;
  static bool _firstLoginCompleted = false;

  /// Habilita el acceso biométrico tras el inicio de sesión exitoso si el usuario no lo ha deshabilitado explícitamente.
  static Future<void> enableBiometricAfterFirstLogin({SessionStorageService? sessionStorage}) async {
    _firstLoginCompleted = true;
    try {
      if (sessionStorage != null) {
        final existing = await sessionStorage.getBiometricPreference();
        if (existing == null) {
          _cachedBiometricEnabled = true;
          await sessionStorage.saveBiometricPreference(true);
        } else {
          _cachedBiometricEnabled = existing;
        }
        return;
      }

      const storage = FlutterSecureStorage(aOptions: _androidOptions);
      final existing = await storage.read(key: _biometricKey);
      // Solo habilitar por defecto si el usuario aún no tomó una decisión explícita
      if (existing == null) {
        _cachedBiometricEnabled = true;
        await storage.write(key: _biometricKey, value: 'true');
      } else {
        _cachedBiometricEnabled = existing == 'true';
      }
    } catch (_) {
      _cachedBiometricEnabled = true;
    }
  }

  /// Indica si el usuario ya completó el primer inicio de sesión.
  static bool get isBiometricEnabledAfterFirstLogin => _cachedBiometricEnabled ?? _firstLoginCompleted;

  /// Lee si la biometría está habilitada por el usuario en almacenamiento persistente.
  Future<bool> isBiometricEnabled() async {
    if (_cachedBiometricEnabled != null) {
      return _cachedBiometricEnabled!;
    }

    final val = await _sessionStorage.getBiometricPreference();
    if (val != null) {
      _cachedBiometricEnabled = val;
      return _cachedBiometricEnabled!;
    }

    try {
      final strVal = await _storage.read(key: _biometricKey);
      if (strVal != null) {
        _cachedBiometricEnabled = strVal == 'true';
        return _cachedBiometricEnabled!;
      }
    } catch (_) {}
    return _firstLoginCompleted;
  }

  /// Guarda la preferencia del usuario (activar o desactivar en Ajustes).
  Future<void> setBiometricEnabled(bool enabled) async {
    _cachedBiometricEnabled = enabled;
    _firstLoginCompleted = enabled;

    await _sessionStorage.saveBiometricPreference(enabled);

    try {
      await _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
    } catch (_) {}
  }

  /// Comprueba si el dispositivo soporta biometría y si el usuario la tiene activada.
  Future<bool> canUseBiometric() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) {
      return false; // Desactivado por el usuario o antes del primer login
    }
    return await isDeviceBiometricSupported();
  }

  /// Revisa si el dispositivo físico soporta lectura biométrica.
  Future<bool> isDeviceBiometricSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Ejecuta la autenticación biométrica
  Future<bool> authenticate({
    String reason = 'Confirma tu identidad para ingresar',
  }) async {
    try {
      final bool allowed = await canUseBiometric();
      if (!allowed) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
