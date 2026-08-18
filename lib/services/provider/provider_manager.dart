import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../secure_credential_manager.dart';
import 'ai_provider.dart';
import 'provider_configuration.dart';
import 'openai_compatible_provider.dart';

/// Manages multiple AI providers and handles provider switching
class ProviderManager {
  static final ProviderManager _instance = ProviderManager._internal();

  factory ProviderManager() {
    return _instance;
  }

  ProviderManager._internal();

  late SharedPreferences _prefs;
  late SecureCredentialManager _credentialManager;
  final Map<String, AIProvider> _providers = {};
  final Map<String, ProviderConfiguration> _configurations = {};
  String _activeProvider = 'custom';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _credentialManager = SecureCredentialManager();
    await _credentialManager.init();
    _activeProvider = _prefs.getString('active_provider') ?? 'custom';
    await _loadProviders();
  }

  Future<void> _loadProviders() async {
    _providers.clear();
    _configurations.clear();
    _loadStoredConfigurations();

    // Load custom provider
    final customApiKey = await _credentialManager.getCustomApiKey();
    final customBaseUrl = _credentialManager.getCustomBaseUrl();
    final customModel = _credentialManager.getCustomModel();

    if (customApiKey != null &&
        customApiKey.isNotEmpty &&
        customBaseUrl.isNotEmpty) {
      _providers['custom'] = OpenAICompatibleProvider(
        name: 'Custom',
        baseUrl: customBaseUrl,
        apiKey: customApiKey,
        model: customModel,
      );
      _configurations['custom'] =
          _configurations['custom'] ??
          ProviderConfiguration(
            id: 'custom',
            name: 'Custom',
            baseUrl: customBaseUrl,
            model: customModel,
            capabilities: const [
              ProviderCapabilities.chat,
              ProviderCapabilities.agentReasoning,
              ProviderCapabilities.coding,
              ProviderCapabilities.toolUse,
            ],
          );
    }

    // Load NVIDIA if configured
    final nvidiaKey = await _credentialManager.getNvidiaApiKey();
    if (nvidiaKey != null && nvidiaKey.isNotEmpty) {
      _providers['nvidia'] = OpenAICompatibleProvider(
        name: 'NVIDIA',
        baseUrl: 'https://integrate.api.nvidia.com/v1',
        apiKey: nvidiaKey,
        model: _credentialManager.getNvidiaModel(),
      );
      _configurations['nvidia'] =
          _configurations['nvidia'] ??
          ProviderConfiguration(
            id: 'nvidia',
            name: 'NVIDIA',
            baseUrl: 'https://integrate.api.nvidia.com/v1',
            model: _credentialManager.getNvidiaModel(),
            capabilities: const [
              ProviderCapabilities.chat,
              ProviderCapabilities.agentReasoning,
              ProviderCapabilities.coding,
              ProviderCapabilities.toolUse,
            ],
          );
    }

    for (final configuration in _configurations.values) {
      if (_providers.containsKey(configuration.id)) continue;
      final key = await _credentialManager.getApiKey(configuration.id);
      if (key == null || key.isEmpty || configuration.baseUrl.isEmpty) continue;
      _providers[configuration.id] = OpenAICompatibleProvider(
        name: configuration.name,
        baseUrl: configuration.baseUrl,
        apiKey: key,
        model: configuration.model,
      );
    }
  }

  void _loadStoredConfigurations() {
    final encoded = _prefs.getString('provider_configurations');
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;
      for (final value in decoded) {
        if (value is! Map) continue;
        final configuration = ProviderConfiguration.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (configuration.id.isNotEmpty) {
          _configurations[configuration.id] = configuration;
        }
      }
    } catch (_) {
      // Ignore malformed optional metadata and retain credential-backed defaults.
    }
  }

  Future<void> _persistConfigurations() async {
    await _prefs.setString(
      'provider_configurations',
      jsonEncode(
        _configurations.values.map((value) => value.toJson()).toList(),
      ),
    );
  }

  List<ProviderConfiguration> get configurations =>
      List.unmodifiable(_configurations.values.toList());

  String get activeProviderId => _activeProvider;

  ProviderConfiguration? getConfiguration(String providerId) =>
      _configurations[providerId];

  Future<String?> getProviderApiKey(String providerId) async {
    return _credentialManager.getApiKey(providerId);
  }

  Future<void> addOrUpdateProviderConfiguration({
    required ProviderConfiguration configuration,
    required String apiKey,
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw ArgumentError(
        'An API key is required for a provider configuration.',
      );
    }
    await _credentialManager.saveApiKey(trimmedKey, configuration.id);
    if (configuration.id == 'custom') {
      await _credentialManager.saveCustomProviderConfig(
        apiKey: trimmedKey,
        baseUrl: configuration.baseUrl,
        model: configuration.model,
      );
    } else if (configuration.id == 'nvidia') {
      await _credentialManager.saveNvidiaConfig(
        apiKey: trimmedKey,
        model: configuration.model,
      );
    } else {
      await _prefs.setString(
        'provider_${configuration.id}_base_url',
        configuration.baseUrl,
      );
      await _prefs.setString(
        'provider_${configuration.id}_model',
        configuration.model,
      );
    }
    _configurations[configuration.id] = configuration;
    await _persistConfigurations();
    await _loadProviders();
  }

  AIProvider? getProviderForCapability(String capability) {
    final active = _providers[_activeProvider];
    final activeConfiguration = _configurations[_activeProvider];
    if (active != null && activeConfiguration?.supports(capability) == true) {
      return active;
    }
    for (final entry in _providers.entries) {
      if (_configurations[entry.key]?.supports(capability) == true) {
        return entry.value;
      }
    }
    return null;
  }

  AIProvider? getActiveProvider() {
    return _providers[_activeProvider];
  }

  Future<void> setActiveProvider(String providerId) async {
    if (_providers.containsKey(providerId)) {
      _activeProvider = providerId;
      await _prefs.setString('active_provider', providerId);
    }
  }

  /// Add or update a provider
  Future<void> addOrUpdateProvider(
    String providerId,
    String name,
    String baseUrl,
    String apiKey,
    String model,
  ) async {
    if (providerId == 'nvidia') {
      await _credentialManager.saveNvidiaConfig(apiKey: apiKey, model: model);
    } else if (providerId == 'custom') {
      await _credentialManager.saveCustomProviderConfig(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
      );
    }
    await _loadProviders();
  }

  /// Test a provider connection
  Future<bool> testProvider(String providerId) async {
    final provider = _providers[providerId];
    if (provider == null) return false;
    return await provider.testConnection();
  }

  /// Get all configured providers
  Map<String, AIProvider> getAllProviders() {
    return Map.unmodifiable(_providers);
  }

  /// Get provider details (without API keys)
  Map<String, Map<String, String>> getProviderDetails() {
    return _credentialManager.getSavedProviders();
  }

  /// Delete a provider
  Future<void> deleteProvider(String providerId) async {
    await _credentialManager.clearProviderCredentials(providerId);
    _providers.remove(providerId);

    // If deleted provider was active, switch to another
    if (_activeProvider == providerId && _providers.isNotEmpty) {
      _activeProvider = _providers.keys.first;
      await _prefs.setString('active_provider', _activeProvider);
    }
  }

  /// Get list of model names for a provider
  Future<List<String>> fetchModelsForProvider(String providerId) async {
    final provider = _providers[providerId];
    if (provider == null) return [];
    return await provider.fetchAvailableModels();
  }
}
