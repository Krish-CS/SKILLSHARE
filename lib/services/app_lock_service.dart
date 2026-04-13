import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockConfig {
  const AppLockConfig({
    required this.enabled,
    required this.type,
    this.secretHash,
  });

  final bool enabled;
  final String type;
  final String? secretHash;
}

class AppLockService {
  static const String typeNone = 'none';
  static const String typePin = 'pin';
  static const String typePattern = 'pattern';
  static const String typeBiometric = 'biometric';

  static const _enabledKey = 'app_lock_enabled';
  static const _typeKey = 'app_lock_type';
  static const _secretHashKey = 'app_lock_secret_hash';
  static const _hashVersionPrefix = 'v2';
  static const _hashRounds = 2048;

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      // If plugin channels are not ready on some devices/startup races,
      // fail gracefully instead of crashing app initialization.
      return null;
    }
  }

  Future<AppLockConfig> loadConfig() async {
    final prefs = await _safePrefs();
    return AppLockConfig(
      enabled: prefs?.getBool(_enabledKey) ?? false,
      type: prefs?.getString(_typeKey) ?? typeNone,
      secretHash: prefs?.getString(_secretHashKey),
    );
  }

  Future<void> disableLock() async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setBool(_enabledKey, false);
    await prefs.setString(_typeKey, typeNone);
    await prefs.remove(_secretHashKey);
  }

  Future<void> setPinLock(String pin) async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_typeKey, typePin);
    await prefs.setString(_secretHashKey, _buildSecretHash(pin.trim()));
  }

  Future<void> setPatternLock(String pattern) async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_typeKey, typePattern);
    await prefs.setString(_secretHashKey, _buildSecretHash(pattern.trim()));
  }

  Future<void> setBiometricLock() async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_typeKey, typeBiometric);
    await prefs.remove(_secretHashKey);
  }

  Future<bool> canUseBiometric() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      return supported && canCheck && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock SkillShare',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.noBiometricHardware ||
          e.code == LocalAuthExceptionCode.noBiometricsEnrolled) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool verifySecret({
    required String input,
    required String? secretHash,
  }) {
    if (secretHash == null || secretHash.isEmpty) return false;

    final normalizedInput = input.trim();
    if (secretHash.startsWith('$_hashVersionPrefix:')) {
      final parts = secretHash.split(':');
      if (parts.length != 3) return false;

      final salt = parts[1];
      final storedHash = parts[2];
      return _hashWithSalt(normalizedInput, salt) == storedHash;
    }

    // Backward compatibility for previously stored unsalted hashes.
    return _legacyHash(normalizedInput) == secretHash;
  }

  String _buildSecretHash(String value) {
    final salt = _generateSalt();
    final hash = _hashWithSalt(value, salt);
    return '$_hashVersionPrefix:$salt:$hash';
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashWithSalt(String value, String salt) {
    var hash = sha256.convert(utf8.encode('$salt:$value')).toString();
    for (var i = 0; i < _hashRounds; i++) {
      hash = sha256.convert(utf8.encode('$hash:$salt')).toString();
    }
    return hash;
  }

  String _legacyHash(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
