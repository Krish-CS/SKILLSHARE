import 'package:flutter/foundation.dart';

import '../services/app_lock_service.dart';

class AppLockProvider extends ChangeNotifier {
  AppLockProvider({AppLockService? service})
      : _service = service ?? AppLockService();

  final AppLockService _service;

  bool _initialized = false;
  bool _enabled = false;
  String _type = AppLockService.typeNone;
  String? _secretHash;
  bool _sessionUnlocked = false;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  String get type => _type;
  bool get requiresUnlock => _enabled && !_sessionUnlocked;
  bool get isSecretType =>
      _type == AppLockService.typePin || _type == AppLockService.typePattern;

  Future<void> initialize() async {
    final config = await _service.loadConfig();
    _enabled = config.enabled;
    _type = config.type;
    _secretHash = config.secretHash;
    _sessionUnlocked = !_enabled;
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    final config = await _service.loadConfig();
    _enabled = config.enabled;
    _type = config.type;
    _secretHash = config.secretHash;
    if (!_enabled) {
      _sessionUnlocked = true;
    }
    notifyListeners();
  }

  void lockNow() {
    if (!_enabled) return;
    _sessionUnlocked = false;
    notifyListeners();
  }

  Future<void> disable() async {
    await _service.disableLock();
    _enabled = false;
    _type = AppLockService.typeNone;
    _secretHash = null;
    _sessionUnlocked = true;
    notifyListeners();
  }

  Future<void> enablePin(String pin) async {
    await _service.setPinLock(pin);
    _enabled = true;
    _type = AppLockService.typePin;
    _secretHash = (await _service.loadConfig()).secretHash;
    _sessionUnlocked = true;
    notifyListeners();
  }

  Future<void> enablePattern(String pattern) async {
    await _service.setPatternLock(pattern);
    _enabled = true;
    _type = AppLockService.typePattern;
    _secretHash = (await _service.loadConfig()).secretHash;
    _sessionUnlocked = true;
    notifyListeners();
  }

  Future<bool> enableBiometric() async {
    final canUse = await _service.canUseBiometric();
    if (!canUse) return false;
    final verified = await _service.authenticateBiometric();
    if (!verified) return false;

    await _service.setBiometricLock();
    _enabled = true;
    _type = AppLockService.typeBiometric;
    _secretHash = null;
    _sessionUnlocked = true;
    notifyListeners();
    return true;
  }

  bool tryUnlockWithSecret(String value) {
    final ok = _service.verifySecret(input: value, secretHash: _secretHash);
    if (ok) {
      _sessionUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> tryUnlockWithBiometric() async {
    final ok = await _service.authenticateBiometric();
    if (ok) {
      _sessionUnlocked = true;
      notifyListeners();
    }
    return ok;
  }
}
