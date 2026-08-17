import 'provider_configuration.dart';

/// Abstract base class for AI providers
abstract class AIProvider {
  String get name;
  String get baseUrl;
  String get apiKey;
  String get model;

  Future<bool> testConnection();
  Future<String> sendMessage(String message, {bool isAgentMode = false});
  Future<Stream<String>> streamMessage(
    String message, {
    bool isAgentMode = false,
  });
  Future<List<String>> fetchAvailableModels();
  bool supportsVision();
  bool supportsTools();
  bool supportsStructuredOutput();
  Future<Map<String, dynamic>> validateConfiguration();

  /// Providers that do not advertise image generation fail explicitly rather
  /// than silently pretending to support it.
  Future<ImageGenerationResult> generateImage(String prompt) async {
    throw UnsupportedError('Image generation is not supported by $name');
  }
}
