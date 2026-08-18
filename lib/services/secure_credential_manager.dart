import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages secure credential storage for API keys and sensitive data
class SecureCredentialManager {
  static final SecureCredentialManager _instance =
      SecureCredentialManager._internal();

  factory SecureCredentialManager() {
    return _instance;
  }

  SecureCredentialManager._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );
  late SharedPreferences _prefs;

  // Credential keys
  static const String _keyCustomBaseUrl = 'custom_base_url';
  static const String _keyCustomModel = 'custom_model';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save API key securely
  Future<void> saveApiKey(String key, String providerId) async {
    await _secureStorage.write(key: '${providerId}_api_key', value: key);
  }

  /// Retrieve API key securely
  Future<String?> getApiKey(String providerId) async {
    try {
      return await _secureStorage.read(key: '${providerId}_api_key');
    } catch (e) {
      return null;
    }
  }

  /// Delete API key
  Future<void> deleteApiKey(String providerId) async {
    await _secureStorage.delete(key: '${providerId}_api_key');
  }

  /// Save NVIDIA configuration
  Future<void> saveNvidiaConfig({
    required String apiKey,
    required String model,
  }) async {
    await saveApiKey(apiKey, 'nvidia');
    await _prefs.setString('nvidia_model', model);
  }

  /// Get NVIDIA API key
  Future<String?> getNvidiaApiKey() async {
    return await getApiKey('nvidia');
  }

  /// Get NVIDIA model
  String getNvidiaModel() {
    return _prefs.getString('nvidia_model') ?? 'z-ai/glm-5.2';
  }

  /// Save custom provider configuration
  Future<void> saveCustomProviderConfig({
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    await saveApiKey(apiKey, 'custom');
    await _prefs.setString(_keyCustomBaseUrl, baseUrl);
    await _prefs.setString(_keyCustomModel, model);
  }

  /// Get custom provider API key
  Future<String?> getCustomApiKey() async {
    return await getApiKey('custom');
  }

  /// Get custom provider base URL
  String getCustomBaseUrl() {
    return _prefs.getString(_keyCustomBaseUrl) ?? '';
  }

  /// Get custom provider model
  String getCustomModel() {
    return _prefs.getString(_keyCustomModel) ?? '';
  }

  /// Get all saved providers (without exposing keys)
  Map<String, Map<String, String>> getSavedProviders() {
    final providers = <String, Map<String, String>>{};

    // NVIDIA
    if (_prefs.getString('nvidia_model') != null) {
      providers['nvidia'] = {'name': 'NVIDIA', 'model': getNvidiaModel()};
    }

    // Custom
    if (getCustomBaseUrl().isNotEmpty && getCustomModel().isNotEmpty) {
      providers['custom'] = {
        'name': 'Custom',
        'baseUrl': getCustomBaseUrl(),
        'model': getCustomModel(),
      };
    }

    return providers;
  }

  /// Test if credential is valid (non-null and non-empty)
  Future<bool> hasValidCredential(String providerId) async {
    final key = await getApiKey(providerId);
    return key != null && key.isNotEmpty;
  }

  /// Clear all credentials for a provider
  Future<void> clearProviderCredentials(String providerId) async {
    await deleteApiKey(providerId);
    if (providerId == 'nvidia') {
      await _prefs.remove('nvidia_model');
    } else if (providerId == 'custom') {
      await _prefs.remove(_keyCustomBaseUrl);
      await _prefs.remove(_keyCustomModel);
    }
  }

  /// Clear ALL credentials (use with caution)
  Future<void> clearAllCredentials() async {
    await clearProviderCredentials('nvidia');
    await clearProviderCredentials('custom');
  }
}
