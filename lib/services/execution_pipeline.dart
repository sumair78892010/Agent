import 'agent_core.dart';
import 'action_handler.dart';
import 'ai_service.dart';
import 'provider/provider_manager.dart';
import '../models/agent_action.dart';
import '../models/chat_message.dart';
import 'dart:async';

/// Execution Pipeline Manager
/// Orchestrates the flow from user input through Agent Core to device execution
class ExecutionPipeline {
  static final ExecutionPipeline _instance = ExecutionPipeline._internal();
  
  factory ExecutionPipeline() {
    return _instance;
  }
  
  ExecutionPipeline._internal();

  late AgentCore _agentCore;
  late ActionHandler _actionHandler;
  late AiService _aiService;
  late ProviderManager _providerManager;
  
  final List<ExecutionEvent> _eventLog = [];
  final StreamController<ExecutionEvent> _eventStream = StreamController.broadcast();
  
  bool _disposed = false;

  Future<void> init() async {
    _agentCore = AgentCore();
    await _agentCore.init();
    
    _actionHandler = ActionHandler();
    
    _aiService = AiService();
    await _aiService.init();
    
    _providerManager = ProviderManager();
    await _providerManager.init();
  }

  /// Execute a user command through the complete pipeline
  /// This is the REAL execution flow with verification
  Future<ExecutionResult> executeCommand(
    String userInput, {
    void Function(ExecutionEvent)? onEvent,
    int maxRetries = 2,
  }) async {
    try {
      _logEvent(
        'STARTED',
        'Beginning execution pipeline',
        userInput,
        onEvent,
      );

      // Step 1: Interpret user intent
      _logEvent(
        'UNDERSTANDING',
        'Analyzing user input',
        userInput,
        onEvent,
      );
      final action = await _agentCore.interpretIntent(userInput);
      if (action == null) {
        _logEvent('ERROR', 'Failed to understand request', userInput, onEvent);
        return ExecutionResult(
          success: false,
          errorMessage: 'Could not understand the request',
          timestamp: DateTime.now(),
        );
      }

      _logEvent('UNDERSTOOD', 'Request interpreted as: ${action.action}', 
        action.action, onEvent);

      // Step 2: Check safety and permissions
      _logEvent('PERMISSION_CHECK', 'Verifying permissions and constraints', 
        action.action, onEvent);
      final safetyCheck = await _agentCore.checkSafety(action);
      if (safetyCheck['permitted'] == false) {
        _logEvent('PERMISSION_DENIED', 'Action not permitted', 
          action.action, onEvent);
        return ExecutionResult(
          success: false,
          errorMessage: 'Action not permitted for security reasons',
          timestamp: DateTime.now(),
        );
      }

      if (safetyCheck['requiresConfirmation'] == true) {
        _logEvent('REQUIRES_CONFIRMATION', 
          'This action requires user confirmation', action.action, onEvent);
      }

      // Step 3: EXECUTE through ActionHandler (real execution)
      _logEvent('EXECUTING', 'Executing action: ${action.action}', 
        action.action, onEvent);
      
      int attempt = 0;
      AgentActionResult? actionResult;
      String? lastError;
      
      while (attempt <= maxRetries) {
        try {
          actionResult = await _actionHandler.execute(
            action,
            aiService: _aiService,
            onProgress: (progress) {
              _logEvent('PROGRESS', progress, action.action, onEvent);
            },
          );
          
          if (actionResult.success) {
            break; // Success on this attempt
          } else {
            lastError = actionResult.details;
            attempt++;
            if (attempt <= maxRetries) {
              _logEvent('RETRY', 'Retrying action (attempt $attempt/$maxRetries)',
                action.action, onEvent);
              await Future.delayed(
                Duration(milliseconds: 500 * (attempt + 1)),
              );
            }
          }
        } catch (e) {
          lastError = e.toString();
          attempt++;
          if (attempt <= maxRetries) {
            _logEvent('RETRY_AFTER_ERROR', 
              'Retrying after error (attempt $attempt/$maxRetries)',
              e.toString(), onEvent);
            await Future.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
          }
        }
      }

      if (actionResult == null) {
        _logEvent('EXECUTION_FAILED', 'Action execution failed', 
          lastError ?? 'Unknown error', onEvent);
        return ExecutionResult(
          success: false,
          errorMessage: 'Action execution failed: ${lastError ?? "No result"}',
          timestamp: DateTime.now(),
        );
      }

      // Step 4: Verify completion
      _logEvent('VERIFYING', 'Verifying action completion', 
        action.action, onEvent);
      
      if (actionResult.success) {
        _logEvent('VERIFIED', 'Action verified successful', 
          actionResult.details ?? '', onEvent);
        _logEvent('COMPLETED', 'Execution pipeline complete', 
          actionResult.details ?? '', onEvent);
        
        return ExecutionResult(
          success: true,
          actionId: action.id,
          result: actionResult.details,
          timestamp: DateTime.now(),
        );
      } else {
        _logEvent('VERIFICATION_FAILED', 'Action verification failed', 
          actionResult.details ?? '', onEvent);
        return ExecutionResult(
          success: false,
          actionId: action.id,
          errorMessage: 'Action failed verification: ${actionResult.details}',
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      _logEvent('ERROR', 'Execution pipeline error', e.toString(), onEvent);
      return ExecutionResult(
        success: false,
        errorMessage: 'Execution error: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get the active AI provider
  String getActiveProviderName() {
    final provider = _providerManager.getActiveProvider();
    return provider?.name ?? 'Not configured';
  }

  /// Switch to a different provider
  Future<void> switchProvider(String providerId) async {
    await _providerManager.setActiveProvider(providerId);
    _logEvent('PROVIDER_SWITCH', 'Switched to provider', providerId, null);
  }

  /// Get all available providers
  Map<String, String> getAvailableProviders() {
    return _providerManager
        .getAllProviders()
        .map((key, provider) => MapEntry(key, provider.name));
  }

  void _logEvent(String type, String message, String details, 
      void Function(ExecutionEvent)? onEvent) {
    if (_disposed) return;
    
    final event = ExecutionEvent(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      details: details,
    );
    _eventLog.add(event);
    if (!_disposed) {
      _eventStream.add(event);
    }
    if (onEvent != null) {
      onEvent(event);
    }
  }

  Stream<ExecutionEvent> get eventStream => _eventStream.stream;

  List<ExecutionEvent> getEventLog() => List.unmodifiable(_eventLog);

  void clearEventLog() => _eventLog.clear();

  void dispose() {
    _disposed = true;
    _eventStream.close();
  }
}

/// Represents a single event in the execution pipeline
class ExecutionEvent {
  final DateTime timestamp;
  final String type; // UNDERSTAND, EXECUTE, VERIFY, RECOVER, ERROR, etc.
  final String message;
  final String details;

  ExecutionEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.details,
  });

  @override
  String toString() => '$type: $message ($details)';
}

/// Result of a complete execution
class ExecutionResult {
  final bool success;
  final String? actionId;
  final String? result;
  final String? errorMessage;
  final DateTime timestamp;
  final int? tokensUsed;

  ExecutionResult({
    required this.success,
    this.actionId,
    this.result,
    this.errorMessage,
    DateTime? timestamp,
    this.tokensUsed,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => success
      ? 'SUCCESS: $result'
      : 'FAILED: $errorMessage';
}
