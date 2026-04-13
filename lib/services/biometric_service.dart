import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device supports biometrics (fingerprint / face / etc.)
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
      return false;
    }
  }

  /// Returns the list of enrolled biometric types.
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Prompts the user for biometric authentication.
  /// Returns [BiometricResult] describing the outcome.
  static Future<BiometricResult> authenticate({
    String reason = 'Please verify your identity to continue',
  }) async {
    if (kIsWeb) {
      // Web doesn't support local_auth; treat as passed for demo.
      return BiometricResult.success;
    }

    try {
      final available = await isAvailable();
      if (!available) {
        return BiometricResult.notAvailable;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );

      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      debugPrint('Biometric auth LocalAuthException: ${e.code}');
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return BiometricResult.notAvailable;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricResult.lockedOut;
        default:
          return BiometricResult.failed;
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return BiometricResult.failed;
    }
  }

  /// Human-readable message for a [BiometricResult].
  static String resultMessage(BiometricResult result) {
    switch (result) {
      case BiometricResult.success:
        return 'Biometric verified successfully';
      case BiometricResult.failed:
        return 'Biometric verification failed. Please try again.';
      case BiometricResult.notAvailable:
        return 'Biometric authentication is not set up on this device. '
            'Please enroll a fingerprint/face in device Settings.';
      case BiometricResult.lockedOut:
        return 'Too many failed attempts. Please unlock your device and try again.';
    }
  }
}

enum BiometricResult { success, failed, notAvailable, lockedOut }
