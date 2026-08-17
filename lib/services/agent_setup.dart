import 'dart:developer' as developer;
import 'agent_core.dart';
import 'execution_pipeline.dart';
import 'action_handler.dart';
import 'ai_service.dart';
import 'voice_service.dart';
import 'user_memory_service.dart';
import 'permission_service.dart';
import 'diagnostics_service.dart';
import 'screen_automation_service.dart';
import 'file_operation_service.dart';
import 'web_operation_service.dart';
import 'task_scheduling_service.dart';
import 'biometric_service.dart';
import 'settings_service.dart';

/// Agent initialization and setup
/// Centralizes initialization of all agent services in the correct order
class AgentSetup {
  static final AgentSetup _instance = AgentSetup._internal();
  
  factory AgentSetup() {
    return _instance;
  }
  
  AgentSetup._internal();

  bool _isInitialized = false;
  
  late AgentCore _agentCore;
  late ExecutionPipeline _executionPipeline;
  late ActionHandler _actionHandler;
  late AiService _aiService;
  late VoiceService _voiceService;
  late UserMemoryService _userMemory;
  late PermissionService _permissionService;
  late DiagnosticsService _diagnosticsService;
  late ScreenAutomationService _screenService;
  late FileOperationService _fileOps;
  late WebOperationService _webOps;
  late TaskSchedulingService _taskScheduling;
  late BiometricService _biometric;
  late SettingsService _settings;

  // Getters for services
  AgentCore get agentCore => _agentCore;
  ExecutionPipeline get executionPipeline => _executionPipeline;
  ActionHandler get actionHandler => _actionHandler;
  AiService get aiService => _aiService;
  VoiceService get voiceService => _voiceService;
  UserMemoryService get userMemory => _userMemory;
  PermissionService get permissionService => _permissionService;
  DiagnosticsService get diagnosticsService => _diagnosticsService;
  ScreenAutomationService get screenService => _screenService;
  FileOperationService get fileOps => _fileOps;
  WebOperationService get webOps => _webOps;
  TaskSchedulingService get taskScheduling => _taskScheduling;
  BiometricService get biometric => _biometric;
  SettingsService get settings => _settings;

  bool get isInitialized => _isInitialized;

  /// Initialize all agent services in correct order
  /// Should be called early in app lifecycle
  Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('Agent already initialized, skipping', name: 'AgentSetup');
      return;
    }

    try {
      developer.log('Starting Agent Cypher initialization', name: 'AgentSetup');

      // Step 1: Initialize core services first (no dependencies)
      developer.log('Initializing core services...', name: 'AgentSetup');
      _voiceService = VoiceService();
      await _voiceService.init();
      developer.log('✓ VoiceService initialized', name: 'AgentSetup');

      _userMemory = UserMemoryService();
      await _userMemory.load();
      developer.log('✓ UserMemoryService initialized', name: 'AgentSetup');

      _permissionService = PermissionService();
      developer.log('✓ PermissionService initialized', name: 'AgentSetup');

      _screenService = ScreenAutomationService();
      developer.log('✓ ScreenAutomationService initialized', name: 'AgentSetup');

      // Step 2: Initialize AI service
      developer.log('Initializing AI service...', name: 'AgentSetup');
      _aiService = AiService();
      await _aiService.init();
      developer.log('✓ AiService initialized', name: 'AgentSetup');

      // Step 3: Initialize agent core (depends on AI service)
      developer.log('Initializing Agent Core...', name: 'AgentSetup');
      _agentCore = AgentCore();
      await _agentCore.init();
      developer.log('✓ AgentCore initialized', name: 'AgentSetup');

      // Step 4: Initialize execution pipeline
      developer.log('Initializing Execution Pipeline...', name: 'AgentSetup');
      _executionPipeline = ExecutionPipeline();
      await _executionPipeline.init();
      developer.log('✓ ExecutionPipeline initialized', name: 'AgentSetup');

      // Step 5: Initialize action handler (depends on other services)
      developer.log('Initializing Action Handler...', name: 'AgentSetup');
      _actionHandler = ActionHandler();
      developer.log('✓ ActionHandler initialized', name: 'AgentSetup');

      // Step 6: Initialize diagnostics (depends on all other services)
      developer.log('Initializing Diagnostics...', name: 'AgentSetup');
      _diagnosticsService = DiagnosticsService();
      developer.log('✓ DiagnosticsService initialized', name: 'AgentSetup');

      // Step 7: Initialize file operations
      developer.log('Initializing File Operations...', name: 'AgentSetup');
      _fileOps = FileOperationService();
      developer.log('✓ FileOperationService initialized', name: 'AgentSetup');

      // Step 8: Initialize web operations
      developer.log('Initializing Web Operations...', name: 'AgentSetup');
      _webOps = WebOperationService();
      developer.log('✓ WebOperationService initialized', name: 'AgentSetup');

      // Step 9: Initialize task scheduling
      developer.log('Initializing Task Scheduling...', name: 'AgentSetup');
      _taskScheduling = TaskSchedulingService();
      await _taskScheduling.init();
      developer.log('✓ TaskSchedulingService initialized', name: 'AgentSetup');

      // Step 10: Initialize biometric authentication
      developer.log('Initializing Biometric Service...', name: 'AgentSetup');
      _biometric = BiometricService();
      await _biometric.init();
      developer.log('✓ BiometricService initialized', name: 'AgentSetup');

      // Step 11: Initialize settings management
      developer.log('Initializing Settings Service...', name: 'AgentSetup');
      _settings = SettingsService();
      await _settings.init();
      developer.log('✓ SettingsService initialized', name: 'AgentSetup');

      _isInitialized = true;
      developer.log('Agent Cypher initialization complete!', name: 'AgentSetup');
    } catch (e) {
      developer.log('Agent initialization error: $e', name: 'AgentSetup', level: 2000);
      rethrow;
    }
  }

  /// Verify that critical permissions are granted
  Future<bool> verifyRequiredPermissions() async {
    final statuses = await _permissionService.getAllPermissionsStatus();
    
    for (final entry in statuses.entries) {
      if (entry.value.required) {
        developer.log(
          'Permission check - ${entry.key}: ${entry.value.statusText}',
          name: 'AgentSetup',
        );
      }
    }
    
    return await _permissionService.allCriticalPermissionsGranted();
  }

  /// Run diagnostics to check system readiness
  Future<List<DiagnosticResult>> runDiagnostics() async {
    developer.log('Running system diagnostics...', name: 'AgentSetup');
    return await _diagnosticsService.runAllDiagnostics();
  }

  /// Clean up resources
  void dispose() {
    developer.log('Disposing Agent resources...', name: 'AgentSetup');
    _voiceService.dispose();
    _executionPipeline.dispose();
    developer.log('Agent resources disposed', name: 'AgentSetup');
  }
}
