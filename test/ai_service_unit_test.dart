import 'package:flutter_test/flutter_test.dart';
import '../lib/services/ai_service.dart';
import '../lib/models/agent_action.dart';

void main() {
  late AiService aiService;

  setUp(() {
    aiService = AiService();
  });

  group('isImageGenerationRequest', () {
    test('detects generate + image keywords', () {
      expect(aiService.isImageGenerationRequest('Generate an image of a sunset'), isTrue);
      expect(aiService.isImageGenerationRequest('Create a picture of a cat'), isTrue);
      expect(aiService.isImageGenerationRequest('Draw an illustration of mountains'), isTrue);
      expect(aiService.isImageGenerationRequest('Make a photo of a dog'), isTrue);
      expect(aiService.isImageGenerationRequest('Produce an artwork of a city'), isTrue);
      expect(aiService.isImageGenerationRequest('Render an image of a tree'), isTrue);
    });

    test('rejects missing image keyword', () {
      expect(aiService.isImageGenerationRequest('Generate a poem about cats'), isFalse);
      expect(aiService.isImageGenerationRequest('Create a new todo list'), isFalse);
      expect(aiService.isImageGenerationRequest('Draw a conclusion from this data'), isFalse);
    });

    test('rejects missing create keyword', () {
      expect(aiService.isImageGenerationRequest('Show me an image of my screen'), isFalse);
      expect(aiService.isImageGenerationRequest('Find pictures of cats online'), isFalse);
    });

    test('handles case insensitivity', () {
      expect(aiService.isImageGenerationRequest('GENERATE AN IMAGE'), isTrue);
      expect(aiService.isImageGenerationRequest('Generate An Image'), isTrue);
      expect(aiService.isImageGenerationRequest('generate an image'), isTrue);
    });

    test('handles empty string', () {
      expect(aiService.isImageGenerationRequest(''), isFalse);
      expect(aiService.isImageGenerationRequest('   '), isFalse);
    });
  });

  group('isWebResearchRequest', () {
    test('detects explicit web research keywords', () {
      expect(aiService.isWebResearchRequest('Search online for Flutter best practices'), isTrue);
      expect(aiService.isWebResearchRequest('Search the web for latest AI news'), isTrue);
      expect(aiService.isWebResearchRequest('Do web research on quantum computing'), isTrue);
      expect(aiService.isWebResearchRequest('Find online sources about climate change'), isTrue);
      expect(aiService.isWebResearchRequest('Look up online reviews of this phone'), isTrue);
      expect(aiService.isWebResearchRequest('What is the latest news about SpaceX?'), isTrue);
      expect(aiService.isWebResearchRequest('Compare online prices for this product'), isTrue);
      expect(aiService.isWebResearchRequest('Browse the web for tutorials'), isTrue);
    });

    test('rejects device-context requests', () {
      expect(aiService.isWebResearchRequest('Search online for settings on my phone'), isFalse);
      expect(aiService.isWebResearchRequest('Search the web in the app'), isFalse);
      expect(aiService.isWebResearchRequest('Research this on my screen'), isFalse);
      expect(aiService.isWebResearchRequest('Find online info in the Play Store'), isFalse);
      expect(aiService.isWebResearchRequest('Look up this in my browser'), isFalse);
    });

    test('rejects non-research requests', () {
      expect(aiService.isWebResearchRequest('Open YouTube and search for cats'), isFalse);
      expect(aiService.isWebResearchRequest('Set volume to 80%'), isFalse);
      expect(aiService.isWebResearchRequest('What time is it?'), isFalse);
    });

    test('handles empty string', () {
      expect(aiService.isWebResearchRequest(''), isFalse);
    });
  });

  group('parseAction', () {
    test('parses valid JSON action', () {
      const json = '{"action": "open_app", "params": {"package": "com.youtube"}, "response": "Opening YouTube"}';
      final action = aiService.parseAction(json);
      expect(action, isNotNull);
      expect(action!.action, 'open_app');
      expect(action.params, {'package': 'com.youtube'});
      expect(action.response, 'Opening YouTube');
    });

    test('parses action from code fence', () {
      const response = '```json\n{"action": "set_volume", "params": {"level": 50}}\n```';
      final action = aiService.parseAction(response);
      expect(action, isNotNull);
      expect(action!.action, 'set_volume');
    });

    test('returns null for plain text', () {
      expect(aiService.parseAction('Sure, I can help with that!'), isNull);
      expect(aiService.parseAction('The weather today is sunny.'), isNull);
      expect(aiService.parseAction('I think the answer is 42.'), isNull);
    });

    test('returns null for empty string', () {
      expect(aiService.parseAction(''), isNull);
      expect(aiService.parseAction('   '), isNull);
    });

    test('handles truncated JSON with missing closing brace', () {
      const truncated = '{"action": "click_element", "params": {"text": "Hello"}';
      final action = aiService.parseAction(truncated);
      expect(action, isNotNull);
      expect(action!.action, 'click_element');
    });

    test('returns null when JSON lacks action key', () {
      const json = '{"params": {"text": "Hello"}, "response": "Done"}';
      final action = aiService.parseAction(json);
      expect(action, isNull);
    });
  });

  group('AgentAction model', () {
    test('fromJson parses all fields', () {
      final action = AgentAction.fromJson({
        'id': 'test_123',
        'action': 'send_sms',
        'params': {'to': '12345', 'message': 'Hello'},
        'response': 'SMS sent',
      });
      expect(action.id, 'test_123');
      expect(action.action, 'send_sms');
      expect(action.params, {'to': '12345', 'message': 'Hello'});
      expect(action.response, 'SMS sent');
    });

    test('fromJson provides defaults for missing fields', () {
      final action = AgentAction.fromJson({
        'params': {'key': 'value'},
        'response': 'ok',
      });
      expect(action.id, isNotNull);
      expect(action.id, startsWith('action_'));
      expect(action.action, 'general_query');
    });

    test('availableActions contains expected core actions', () {
      expect(AgentAction.availableActions.length, greaterThanOrEqualTo(28));
      expect(AgentAction.availableActions, contains('open_app'));
      expect(AgentAction.availableActions, contains('read_screen'));
      expect(AgentAction.availableActions, contains('execute_task'));
      expect(AgentAction.availableActions, contains('general_query'));
    });
  });
}
