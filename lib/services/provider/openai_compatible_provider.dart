import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import 'provider_configuration.dart';

/// Generic OpenAI-compatible provider (covers most OpenAI-like APIs)
class OpenAICompatibleProvider implements AIProvider {
  @override
  final String name;
  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  String model;

  OpenAICompatibleProvider({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'User-Agent': 'Agent-Cypher/1.0',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'test'},
              ],
              'max_tokens': 5,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data['choices'] != null &&
              (data['choices'] as List).isNotEmpty;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> sendMessage(String message, {bool isAgentMode = false}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'User-Agent': 'Agent-Cypher/1.0',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': message},
              ],
              'max_tokens': 2048,
              'temperature': 0.7,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']['content'] ?? 'No response';
          }
        } catch (_) {}
      }

      return 'Error: HTTP ${response.statusCode}';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  @override
  Future<Stream<String>> streamMessage(
    String message, {
    bool isAgentMode = false,
  }) async {
    return Stream.fromFuture(_streamMessageImpl(message));
  }

  Future<String> _streamMessageImpl(String message) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/completions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'User-Agent': 'Agent-Cypher/1.0',
      });

      request.body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': message},
        ],
        'max_tokens': 2048,
        'temperature': 0.7,
        'stream': true,
      });

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );

      if (streamedResponse.statusCode != 200) {
        return 'Error: HTTP ${streamedResponse.statusCode}';
      }

      final buffer = StringBuffer();
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr == '[DONE]') break;
            try {
              final data = jsonDecode(jsonStr);
              final delta = data['choices'][0]['delta']['content'];
              if (delta != null) {
                buffer.write(delta);
              }
            } catch (_) {
              // Ignore parse errors
            }
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/models'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['data'] is List) {
            return (data['data'] as List)
                .map((m) => m['id'].toString())
                .toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  bool supportsVision() => name.toLowerCase().contains('gpt-4');

  @override
  bool supportsTools() => true;

  @override
  bool supportsStructuredOutput() =>
      name.toLowerCase().contains('gpt') ||
      name.toLowerCase().contains('claude');

  @override
  Future<ImageGenerationResult> generateImage(String prompt) async {
    throw UnsupportedError('Image generation is not supported by $name');
  }

  @override
  Future<Map<String, dynamic>> validateConfiguration() async {
    final connected = await testConnection();
    return {
      'valid': connected,
      'provider': name,
      'model': model,
      'baseUrl': baseUrl,
      'error': !connected ? 'Connection failed' : null,
    };
  }
}
