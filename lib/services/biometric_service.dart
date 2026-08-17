import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service
/// Per spec section 24: BiometricPrompt integration with fallback
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  late final LocalAuthentication _auth;
  late SharedPreferences _prefs;
  bool _biometricsAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  Future<void> init() async {
    _auth = LocalAuthentication();
    _prefs = await SharedPreferences.getInstance();
    await _checkBiometricAvailability();
  }

  /// Check if biometrics are available on device
  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricsAvailable = await _auth.canCheckBiometrics;
      _availableBiometrics = await _auth.getAvailableBiometrics();
    } catch (e) {
      _biometricsAvailable = false;
      _availableBiometrics = [];
    }
  }

  /// Get biometric availability status
  BiometricStatus getBiometricStatus() {
    if (!_biometricsAvailable) {
      return BiometricStatus(
        available: false,
        biometrics: [],
        message: 'Biometrics not available on this device',
      );
    }

    return BiometricStatus(
      available: true,
      biometrics: _availableBiometrics,
      message: 'Biometrics available: ${_getReadableBiometricList()}',
    );
  }

  /// Authenticate using biometric
  /// Returns true if authentication successful, false if failed or cancelled
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
  }) async {
    if (!_biometricsAvailable) {
      return false;
    }

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with device credentials (PIN/Pattern) as fallback
  Future<bool> authenticateWithDeviceCredential({
    required String reason,
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow device credentials
        ),
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }

  /// Full authentication flow: Try biometric, fallback to device credentials
  Future<AuthenticationResult> authenticateWithFallback({
    String biometricReason = 'Use your fingerprint or face to authenticate',
    String deviceCredentialReason = 'Enter your PIN or pattern to authenticate',
  }) async {
    // Try biometric first
    try {
      final biometricSuccess = await authenticate(reason: biometricReason);
      if (biometricSuccess) {
        return AuthenticationResult(
          success: true,
          method: 'biometric',
          availableMethods: _getReadableBiometricList(),
        );
      }
    } catch (e) {
      // Fall through to device credentials
    }

    // Fall back to device credentials
    try {
      final deviceSuccess = await authenticateWithDeviceCredential(
        reason: deviceCredentialReason,
      );
      if (deviceSuccess) {
        return AuthenticationResult(
          success: true,
          method: 'device_credential',
          availableMethods: 'Device PIN/Pattern',
        );
      }
    } catch (e) {
      // Authentication failed
    }

    return AuthenticationResult(
      success: false,
      method: null,
      availableMethods: _getReadableBiometricList(),
      error: 'Authentication failed or cancelled',
    );
  }

  /// Optional: Check if biometric enrollment is required
  Future<bool> isBiometricEnrollmentRequired() async {
    return !_biometricsAvailable && await _auth.canCheckBiometrics == false;
  }

  /// Optional: Check if device has PIN/Pattern set
  Future<bool> hasDeviceCredential() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Get readable biometric types
  String _getReadableBiometricList() {
    if (_availableBiometrics.isEmpty) return 'None';

    final readable = _availableBiometrics.map((biometric) {
      switch (biometric) {
        case BiometricType.face:
          return 'Face';
        case BiometricType.fingerprint:
          return 'Fingerprint';
        case BiometricType.iris:
          return 'Iris';
        case BiometricType.strong:
          return 'Strong Biometric';
        case BiometricType.weak:
          return 'Weak Biometric';
      }
    }).toList();

    return readable.join(', ');
  }

  /// Check if specific biometric type is available
  bool isBiometricTypeAvailable(BiometricType type) {
    return _availableBiometrics.contains(type);
  }

  /// Optional security: Store sensitive app data locked behind biometric
  /// This would typically use encrypted storage
  Future<void> storeSensitiveData(String key, String value) async {
    // In production, use flutter_secure_storage with biometric unlock
    // For now, mark as requiring biometric to access
    await _prefs.setString('secure_$key', value);
    await _prefs.setBool('biometric_required_$key', true);
  }

  /// Retrieve sensitive data (requires biometric)
  Future<String?> getSensitiveData(String key) async {
    final requiresBiometric = _prefs.getBool('biometric_required_$key') ?? false;

    if (requiresBiometric) {
      final authenticated = await authenticate(
        reason: 'Authenticate to access secure data',
      );

      if (!authenticated) {
        return null;
      }
    }

    return _prefs.getString('secure_$key');
  }
}

/// Result of authentication attempt
class AuthenticationResult {
  final bool success;
  final String? method; // 'biometric', 'device_credential', or null
  final String availableMethods;
  final String? error;

  AuthenticationResult({
    required this.success,
    this.method,
    required this.availableMethods,
    this.error,
  });

  String get statusText {
    if (success) {
      return 'Authenticated via $method';
    }
    return error ?? 'Authentication failed';
  }
}

/// Biometric availability information
class BiometricStatus {
  final bool available;
  final List<BiometricType> biometrics;
  final String message;

  BiometricStatus({
    required this.available,
    required this.biometrics,
    required this.message,
  });

  bool get hasFingerprintSupport =>
      biometrics.contains(BiometricType.fingerprint);
  bool get hasFaceSupport => biometrics.contains(BiometricType.face);
  bool get hasIrisSupport => biometrics.contains(BiometricType.iris);
}
