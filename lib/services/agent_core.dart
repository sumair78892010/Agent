import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_action.dart';
import 'provider/ai_provider.dart';
import 'provider/provider_manager.dart';

/// Core Agent system that orchestrates AI interaction, planning, and task execution
class AgentCore {
  final ProviderManager _providerManager = ProviderManager();
  late SharedPreferences _prefs;
  
  int taskCount = 0;
  final List<Map<String, dynamic>> _conversationHistory = [];
  
  static const String _systemPrompt = '''
You are Agent Cypher, a helpful personal AI assistant for Sumair. You understand how to control Android devices and execute tasks.

When the user wants you to perform a device action, respond with ONLY a JSON object (no markdown, no code fences) in this exact format:
{"action": "action_name", "params": {"key": "value"}, "response": "What you say to the user"}

Available actions:
- open_app: {"app_name": "YouTube"}
- search_web: {"query": "latest Android news"}
- read_notifications: {}
- set_brightness: {"level": 50}
- set_volume: {"level": 75}
- toggle_flashlight: {}
- make_call: {"phone_number": "123"}
- send_sms: {"phone_number": "123", "message": "hello"}
- take_screenshot: {}
- read_screen: {}
- execute_task: {"goal": "description of what to do"}

For normal conversations, just respond with plain text.
''';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _providerManager.init();
  }

  /// Send message to AI and get response
  Future<String> sendMessage(String userMessage, {bool isAgentMode = false}) async {
    final provider = _providerManager.getActiveProvider();
    if (provider == null) {
      return 'Error: No AI provider configured';
    }

    try {
      // Add to conversation history
      _conversationHistory.add({'role': 'user', 'content': userMessage});

      // Get response from provider
      final response = await provider.sendMessage(userMessage, isAgentMode: isAgentMode);

      // Add to history
      _conversationHistory.add({'role': 'assistant', 'content': response});

      return response;
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Stream message response
  Future<Stream<String>> streamMessage(String userMessage, {bool isAgentMode = false}) async {
    final provider = _providerManager.getActiveProvider();
    if (provider == null) {
      return Stream.value('Error: No AI provider configured');
    }

    return await provider.streamMessage(userMessage, isAgentMode: isAgentMode);
  }

  /// Parse user intent and determine required actions
  Future<AgentAction?> interpretIntent(String userInput) async {
    try {
      final response = await sendMessage(userInput);
      
      // Try to parse JSON action from response
      final action = _parseActionFromResponse(response);
      return action;
    } catch (e) {
      return null;
    }
  }

  /// Parse action JSON from AI response
  /// Supports both direct JSON and JSON within text
  AgentAction? _parseActionFromResponse(String response) {
    try {
      // First, try direct JSON parsing (most strict)
      try {
        final data = jsonDecode(response);
        if (data is Map<String, dynamic> && data.containsKey('action')) {
          return _buildActionFromJson(data);
        }
      } catch (_) {}

      // Then try to extract JSON from response text
      final jsonMatch = RegExp(r'\{[^{}]*"action"[^{}]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        try {
          final data = jsonDecode(jsonStr);
          if (data is Map<String, dynamic>) {
            return _buildActionFromJson(data);
          }
        } catch (_) {}
      }

      // No action found - return null to indicate this is just text response
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Build AgentAction from parsed JSON
  AgentAction _buildActionFromJson(Map<String, dynamic> data) {
    return AgentAction(
      action: data['action'] as String? ?? 'general_query',
      params: Map<String, dynamic>.from(data['params'] as Map? ?? {}),
      response: data['response'] as String? ?? '',
    );
  }

  /// Plan a multi-step task execution sequence
  Future<List<Map<String, dynamic>>> planTask(String goal) async {
    try {
      final planPrompt = '''
Plan the exact steps to accomplish this goal: $goal

Respond with a JSON array of steps:
[
  {"step": 1, "action": "action_name", "params": {"key": "value"}, "description": "what this does"},
  {"step": 2, "action": "action_name", "params": {"key": "value"}, "description": "what this does"}
]
''';

      final response = await sendMessage(planPrompt);
      
      // Parse the plan
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        try {
          final steps = jsonDecode(jsonMatch.group(0)!);
          return List<Map<String, dynamic>>.from(steps);
        } catch (_) {}
      }

      // Fallback to basic steps
      return [
        {'step': 1, 'action': 'understand', 'description': 'Understanding task goal'},
        {'step': 2, 'action': 'execute', 'description': 'Executing actions'},
        {'step': 3, 'action': 'verify', 'description': 'Verifying results'},
      ];
    } catch (e) {
      return [];
    }
  }

  /// Check permissions and safety constraints before execution
  Future<Map<String, dynamic>> checkSafety(AgentAction action) async {
    // Always allow safe, read-only actions
    final safeActions = [
      'read_screen',
      'read_notifications',
      'take_screenshot',
      'read_file',
      'search_contact',
      'general_query'
    ];
    if (safeActions.contains(action.action)) {
      return {
        'permitted': true,
        'requiresConfirmation': false,
        'riskLevel': 'low',
      };
    }

    // Require confirmation for sensitive actions that modify state
    final sensitiveActions = [
      'make_call',
      'send_sms',
      'delete_file',
      'execute_task',
      'send_email',
      'run_adb_command'
    ];
    if (sensitiveActions.contains(action.action)) {
      return {
        'permitted': true,
        'requiresConfirmation': true,
        'riskLevel': 'high',
      };
    }

    // Allow most other actions with medium risk
    return {
      'permitted': true,
      'requiresConfirmation': false,
      'riskLevel': 'medium',
    };
  }

  /// Verify task completion
  /// Returns true if the result indicates success
  Future<bool> verifyCompletion(AgentAction action, String result) async {
    // Simple heuristic: if result doesn't start with "Error", consider it successful
    // In a real system, this would involve re-reading device state to confirm
    final success = !result.startsWith('Error');
    return success;
  }

  /// Handle retry with exponential backoff
  Future<String> retryWithBackoff(
    AgentAction action,
    int attempt, {
    Duration baseDelay = const Duration(seconds: 1),
  }) async {
    final delayMs = baseDelay.inMilliseconds * (pow(2, (attempt - 1)).toInt());
    await Future.delayed(Duration(milliseconds: delayMs.toInt()));
    return 'Retry attempt $attempt';
  }

  /// Get active provider name
  String? getActiveProviderName() {
    return _providerManager.getActiveProvider()?.name;
  }

  /// Get conversation history
  List<Map<String, dynamic>> getConversationHistory() {
    return List.unmodifiable(_conversationHistory);
  }

  /// Clear conversation history
  void clearConversationHistory() {
    _conversationHistory.clear();
  }

  /// Test active provider connection
  Future<bool> testActiveProvider() async {
    final provider = _providerManager.getActiveProvider();
    if (provider == null) return false;
    return await provider.testConnection();
  }
}
