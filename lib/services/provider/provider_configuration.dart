/// Capability names understood by provider routing.
class ProviderCapabilities {
  static const chat = 'chat';
  static const agentReasoning = 'agent_reasoning';
  static const vision = 'vision';
  static const imageGeneration = 'image_generation';
  static const videoGeneration = 'video_generation';
  static const audioMusic = 'audio_music';
  static const speech = 'speech';
  static const embeddings = 'embeddings';
  static const coding = 'coding';
  static const toolUse = 'tool_use';

  static const all = <String>[
    chat,
    agentReasoning,
    vision,
    imageGeneration,
    videoGeneration,
    audioMusic,
    speech,
    embeddings,
    coding,
    toolUse,
  ];

  static String label(String capability) {
    switch (capability) {
      case chat:
        return 'Chat';
      case agentReasoning:
        return 'Agent reasoning';
      case vision:
        return 'Vision';
      case imageGeneration:
        return 'Image generation';
      case videoGeneration:
        return 'Video generation';
      case audioMusic:
        return 'Audio / music';
      case speech:
        return 'Speech';
      case embeddings:
        return 'Embeddings';
      case coding:
        return 'Coding';
      case toolUse:
        return 'Tool use';
      default:
        return capability;
    }
  }
}

class ProviderConfiguration {
  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final List<String> capabilities;

  const ProviderConfiguration({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.capabilities,
  });

  bool supports(String capability) => capabilities.contains(capability);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'model': model,
    'capabilities': capabilities,
  };

  factory ProviderConfiguration.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    final capabilities = rawCapabilities is List
        ? rawCapabilities.map((value) => value.toString()).toSet().toList()
        : <String>[];
    return ProviderConfiguration(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Provider',
      baseUrl: json['baseUrl']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      capabilities: capabilities,
    );
  }
}

class ImageGenerationResult {
  final String imageUrl;
  final String? revisedPrompt;

  const ImageGenerationResult({required this.imageUrl, this.revisedPrompt});
}
