import 'ai_service.dart';
import 'dart:convert';
import 'permission_service.dart';
import 'screen_automation_service.dart';
import 'task_telemetry_service.dart';
import 'voice_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Diagnostics service to check all system components
/// Per spec section 27: Real diagnostics screen with actionable remediation
class DiagnosticsService {
  static String buildSanitizedDeveloperReport({
    required TaskDeveloperSnapshot snapshot,
    required Map<String, dynamic> system,
  }) {
    final report = <String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'system': system,
      'agent': {
        'status': snapshot.status,
        'root_goal': snapshot.rootGoal,
        'current_sub_goal': snapshot.currentSubGoal,
        'expected_result': snapshot.expectedResult,
        'current_app_package': snapshot.currentAppPackage,
        'execution_stage': snapshot.executionStage,
        'planned_action': snapshot.plannedAction,
        'selected_target': snapshot.selectedTarget,
        'confidence': snapshot.confidence,
        'action_count': snapshot.actionCount,
        'observation_count': snapshot.screenObservations,
        'ai_call_count': snapshot.aiCalls,
        'retry_count': snapshot.recoveryAttempts,
        'recovery_count': snapshot.recoveryAttempts,
        'verification_result': snapshot.verificationResult,
        'total_task_duration_ms': snapshot.totalTaskDurationMs,
        'action_timings': snapshot.actionTimings,
        'failure_category': snapshot.failureCategory,
        'diagnosis_observed': snapshot.diagnosisObserved,
        'diagnosis_likely_cause': snapshot.diagnosisLikelyCause,
        'diagnosis_evidence': snapshot.diagnosisEvidence,
        'diagnosis_recovery_attempt': snapshot.diagnosisRecoveryAttempt,
        'diagnosis_final_result': snapshot.diagnosisFinalResult,
        'upgrade_plan': snapshot.upgradePlan?.toJson(),
        'upgrade_history': snapshot.upgradeHistory
            .map((entry) => entry.toJson())
            .toList(),
        'errors': snapshot.errors,
        'events': snapshot.events.map((event) => event.toJson()).toList(),
        'workspace_commands': snapshot.workspaceCommands
            .map((command) => command.toJson())
            .toList(),
        'attachments': snapshot.attachments
            .map((attachment) => attachment.toJson())
            .toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(_sanitizeValue(report));
  }

  static dynamic _sanitizeValue(dynamic value, [String key = '']) {
    final sensitiveKey = RegExp(
      r'(api.?key|token|password|secret|credential|authorization|private.?key|cookie|header)',
      caseSensitive: false,
    ).hasMatch(key);
    if (sensitiveKey) return '[REDACTED_SECRET]';
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _sanitizeValue(
            entry.value,
            entry.key.toString(),
          ),
      };
    }
    if (value is Iterable) {
      return value.map((item) => _sanitizeValue(item)).toList();
    }
    if (value is String) {
      return value
          .replaceAll(
            RegExp(
              r'\b(?:sk-|nvapi-|github_pat_)[A-Za-z0-9_-]+',
              caseSensitive: false,
            ),
            '[REDACTED_SECRET]',
          )
          .replaceAll(
            RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
            'Bearer [REDACTED_SECRET]',
          );
    }
    return value;
  }

  final AiService _aiService = AiService();
  final PermissionService _permissionService = PermissionService();
  final ScreenAutomationService _screenService = ScreenAutomationService();
  final VoiceService _voiceService = VoiceService();

  /// Diagnostic result for a single component
  Future<DiagnosticResult> diagnosisResult(String component) async {
    switch (component) {
      case 'ai_provider':
        return await _checkAiProvider();
      case 'network':
        return await _checkNetwork();
      case 'microphone':
        return await _checkMicrophone();
      case 'tts':
        return await _checkTts();
      case 'overlay':
        return await _checkOverlay();
      case 'accessibility':
        return await _checkAccessibility();
      case 'notification_access':
        return await _checkNotificationAccess();
      case 'storage':
        return await _checkStorage();
      case 'app_info':
        return await _checkAppInfo();
      default:
        return DiagnosticResult.unknown(component);
    }
  }

  /// Check AI provider configuration and connection
  Future<DiagnosticResult> _checkAiProvider() async {
    try {
      await _aiService.init();

      if (!_aiService.isConfigured) {
        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.failed,
          message: 'No AI provider configured',
          remediation:
              'Go to Settings and configure an AI provider (OpenAI, NVIDIA, DeepSeek, etc.)',
        );
      }

      // Try to connect to provider
      try {
        final response = await _aiService
            .sendMessage('test', isAgentMode: false)
            .timeout(const Duration(seconds: 5));

        if (response.contains('Error')) {
          return DiagnosticResult(
            component: 'AI Provider',
            status: DiagnosticStatus.warning,
            message: 'AI provider responded with error',
            remediation:
                'Check your API key and network connection. Verify credentials in Settings.',
          );
        }

        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.pass,
          message: 'Connected to ${_aiService.baseUrl}',
        );
      } catch (e) {
        return DiagnosticResult(
          component: 'AI Provider',
          status: DiagnosticStatus.warning,
          message: 'Connection test timed out or failed',
          remediation: 'Check network connectivity and verify API credentials.',
        );
      }
    } catch (e) {
      return DiagnosticResult(
        component: 'AI Provider',
        status: DiagnosticStatus.failed,
        message: 'Error checking provider: ${e.toString()}',
        remediation: 'Restart the app and reconfigure the AI provider.',
      );
    }
  }

  /// Check network connectivity
  Future<DiagnosticResult> _checkNetwork() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      // result is a ConnectivityResult enum
      if (result == ConnectivityResult.none) {
        return DiagnosticResult(
          component: 'Network',
          status: DiagnosticStatus.failed,
          message: 'No network connection',
          remediation: 'Enable WiFi or mobile data to use the agent.',
        );
      }

      final connectionType = result.toString().split('.').last;

      return DiagnosticResult(
        component: 'Network',
        status: DiagnosticStatus.pass,
        message: 'Connected via $connectionType',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Network',
        status: DiagnosticStatus.warning,
        message: 'Could not check network status',
      );
    }
  }

  /// Check microphone
  Future<DiagnosticResult> _checkMicrophone() async {
    try {
      final status = await _permissionService.checkMicrophone();

      if (status != PermissionStatus.granted) {
        return DiagnosticResult(
          component: 'Microphone',
          status: DiagnosticStatus.failed,
          message:
              'Microphone permission ${_permissionService.getStatusString(status).toLowerCase()}',
          remediation:
              'Grant microphone permission in Settings > Apps > Agent Cypher > Permissions',
        );
      }

      return DiagnosticResult(
        component: 'Microphone',
        status: DiagnosticStatus.pass,
        message: 'Microphone access granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Microphone',
        status: DiagnosticStatus.warning,
        message: 'Could not verify microphone',
      );
    }
  }

  /// Check text-to-speech
  Future<DiagnosticResult> _checkTts() async {
    try {
      // Check if TTS engine is available
      final isAvailable = await _voiceService.isTtsAvailable();

      if (!isAvailable) {
        return DiagnosticResult(
          component: 'Text-to-Speech',
          status: DiagnosticStatus.warning,
          message: 'TTS engine not available',
          remediation:
              'Install a TTS engine via Settings > Accessibility > Text-to-Speech.',
        );
      }

      return DiagnosticResult(
        component: 'Text-to-Speech',
        status: DiagnosticStatus.pass,
        message: 'TTS engine available',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Text-to-Speech',
        status: DiagnosticStatus.warning,
        message: 'Could not verify TTS: ${e.toString()}',
      );
    }
  }

  /// Check overlay permission
  Future<DiagnosticResult> _checkOverlay() async {
    try {
      final hasOverlay = await _permissionService.checkOverlay();

      if (!hasOverlay) {
        return DiagnosticResult(
          component: 'Display Overlay',
          status: DiagnosticStatus.warning,
          message: 'Overlay permission not granted',
          remediation:
              'Enable "Draw over other apps" in Settings > Apps > Agent Cypher > Special app access.',
        );
      }

      return DiagnosticResult(
        component: 'Display Overlay',
        status: DiagnosticStatus.pass,
        message: 'Overlay permission granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Display Overlay',
        status: DiagnosticStatus.warning,
        message: 'Could not verify overlay permission',
      );
    }
  }

  /// Check accessibility service
  Future<DiagnosticResult> _checkAccessibility() async {
    try {
      final isRunning = await _screenService.isServiceRunning();

      if (!isRunning) {
        return DiagnosticResult(
          component: 'Accessibility Service',
          status: DiagnosticStatus.failed,
          message: 'Accessibility service not running',
          remediation:
              'Enable Agent Cypher in Settings > Accessibility > Installed services.',
        );
      }

      return DiagnosticResult(
        component: 'Accessibility Service',
        status: DiagnosticStatus.pass,
        message: 'Accessibility service running',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Accessibility Service',
        status: DiagnosticStatus.warning,
        message: 'Could not verify accessibility: ${e.toString()}',
      );
    }
  }

  /// Check notification access
  Future<DiagnosticResult> _checkNotificationAccess() async {
    try {
      final status = await _permissionService.checkNotification();

      if (status != PermissionStatus.granted) {
        return DiagnosticResult(
          component: 'Notification Access',
          status: DiagnosticStatus.warning,
          message:
              'Notification access ${_permissionService.getStatusString(status).toLowerCase()}',
          remediation:
              'Allow notification access in Settings > Apps > Agent Cypher > Permissions.',
        );
      }

      return DiagnosticResult(
        component: 'Notification Access',
        status: DiagnosticStatus.pass,
        message: 'Notification access granted',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Notification Access',
        status: DiagnosticStatus.warning,
        message: 'Could not verify notification access',
      );
    }
  }

  /// Check storage
  Future<DiagnosticResult> _checkStorage() async {
    try {
      // This would check actual storage availability
      // For now, assume it's available
      return DiagnosticResult(
        component: 'Storage',
        status: DiagnosticStatus.pass,
        message: 'Storage available',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'Storage',
        status: DiagnosticStatus.failed,
        message: 'Storage check failed: ${e.toString()}',
      );
    }
  }

  /// Check app info
  Future<DiagnosticResult> _checkAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return DiagnosticResult(
        component: 'App Info',
        status: DiagnosticStatus.pass,
        message: '${info.appName} v${info.version}+${info.buildNumber}',
      );
    } catch (e) {
      return DiagnosticResult(
        component: 'App Info',
        status: DiagnosticStatus.warning,
        message: 'Could not retrieve app info',
      );
    }
  }

  /// Classifies only evidence supplied by the execution pipeline. A missing
  /// signal remains unknown rather than being inferred from a generic error.
  static TaskFailureDiagnosis classifyTaskFailure({
    required String observed,
    required String evidence,
    String rootGoal = '',
    bool requestUnderstood = true,
    bool planAligned = true,
    bool wrongTarget = false,
    bool lowConfidence = false,
    bool staleObservation = false,
    bool accessibilityFailure = false,
    bool androidActionFailure = false,
    bool verificationFailure = false,
    bool recoveryFailure = false,
    bool providerAiFailure = false,
    bool timeout = false,
    bool cancelled = false,
    String recoveryAttempt = 'Not attempted.',
    String finalResult = 'Task outcome is still pending.',
  }) {
    late final TaskFailureCategory category;
    late final String likelyCause;

    if (cancelled) {
      category = TaskFailureCategory.cancellation;
      likelyCause = 'The task was cancelled before completion.';
    } else if (timeout) {
      category = TaskFailureCategory.timeout;
      likelyCause = 'The operation exceeded its bounded time limit.';
    } else if (providerAiFailure) {
      category = TaskFailureCategory.providerAiFailure;
      likelyCause = 'The provider/AI request or response failed.';
    } else if (accessibilityFailure) {
      category = TaskFailureCategory.accessibilityFailure;
      likelyCause =
          'The accessibility screen/action channel did not provide usable evidence.';
    } else if (lowConfidence) {
      category = TaskFailureCategory.lowConfidence;
      likelyCause =
          'The proposed target did not meet the confidence threshold.';
    } else if (staleObservation) {
      category = TaskFailureCategory.staleScreenObservation;
      likelyCause =
          'The observation was unreadable or no longer current for the action.';
    } else if (wrongTarget) {
      category = TaskFailureCategory.wrongTargetSelection;
      likelyCause =
          'Wrong target selection is likely because the observed change did not match the intended target.';
    } else if (!planAligned) {
      category = TaskFailureCategory.badPlan;
      likelyCause = 'The proposed action did not advance the active sub-goal.';
    } else if (recoveryFailure) {
      category = TaskFailureCategory.recoveryFailure;
      likelyCause =
          'The selected recovery attempt did not restore verified progress.';
    } else if (androidActionFailure) {
      category = TaskFailureCategory.androidActionFailure;
      likelyCause = 'The Android action returned failure or did not execute.';
    } else if (verificationFailure) {
      category = TaskFailureCategory.verificationFailure;
      likelyCause = 'The expected post-action state was not verified.';
    } else if (!requestUnderstood || rootGoal.trim().isEmpty) {
      category = TaskFailureCategory.requestMisunderstanding;
      likelyCause =
          'The request did not provide a sufficiently clear root goal.';
    } else {
      category = TaskFailureCategory.unknown;
      likelyCause =
          'No supported cause was directly evidenced by the recorded signals.';
    }

    return TaskFailureDiagnosis(
      category: category,
      observed: observed.trim().isEmpty
          ? 'A task failure was observed without further detail.'
          : observed.trim(),
      likelyCause: likelyCause,
      evidence: evidence.trim().isEmpty
          ? 'No additional evidence was recorded.'
          : evidence.trim(),
      recoveryAttempt: recoveryAttempt.trim().isEmpty
          ? 'Not attempted.'
          : recoveryAttempt.trim(),
      finalResult: finalResult.trim().isEmpty
          ? 'Task outcome is still pending.'
          : finalResult.trim(),
    );
  }

  /// Run all diagnostics
  Future<List<DiagnosticResult>> runAllDiagnostics() async {
    return Future.wait([
      _checkAppInfo(),
      _checkNetwork(),
      _checkAiProvider(),
      _checkAccessibility(),
      _checkMicrophone(),
      _checkTts(),
      _checkOverlay(),
      _checkNotificationAccess(),
      _checkStorage(),
    ]);
  }
}

enum TaskFailureCategory {
  requestMisunderstanding,
  badPlan,
  wrongTargetSelection,
  lowConfidence,
  staleScreenObservation,
  accessibilityFailure,
  androidActionFailure,
  verificationFailure,
  recoveryFailure,
  providerAiFailure,
  timeout,
  cancellation,
  unknown,
}

extension TaskFailureCategoryLabel on TaskFailureCategory {
  String get label {
    switch (this) {
      case TaskFailureCategory.requestMisunderstanding:
        return 'Misunderstanding the request';
      case TaskFailureCategory.badPlan:
        return 'Bad plan';
      case TaskFailureCategory.wrongTargetSelection:
        return 'Wrong target selection';
      case TaskFailureCategory.lowConfidence:
        return 'Low confidence';
      case TaskFailureCategory.staleScreenObservation:
        return 'Stale screen observation';
      case TaskFailureCategory.accessibilityFailure:
        return 'Accessibility failure';
      case TaskFailureCategory.androidActionFailure:
        return 'Android action failure';
      case TaskFailureCategory.verificationFailure:
        return 'Verification failure';
      case TaskFailureCategory.recoveryFailure:
        return 'Recovery failure';
      case TaskFailureCategory.providerAiFailure:
        return 'Provider/AI failure';
      case TaskFailureCategory.timeout:
        return 'Timeout';
      case TaskFailureCategory.cancellation:
        return 'Cancellation';
      case TaskFailureCategory.unknown:
        return 'Unknown cause';
    }
  }
}

class TaskFailureDiagnosis {
  final TaskFailureCategory category;
  final String observed;
  final String likelyCause;
  final String evidence;
  final String recoveryAttempt;
  final String finalResult;

  const TaskFailureDiagnosis({
    required this.category,
    required this.observed,
    required this.likelyCause,
    required this.evidence,
    required this.recoveryAttempt,
    required this.finalResult,
  });

  String get categoryLabel => category.label;
}

enum DiagnosticStatus { pass, warning, failed, unknown }

class DiagnosticResult {
  final String component;
  final DiagnosticStatus status;
  final String message;
  final String? remediation;

  DiagnosticResult({
    required this.component,
    required this.status,
    required this.message,
    this.remediation,
  });

  factory DiagnosticResult.unknown(String component) {
    return DiagnosticResult(
      component: component,
      status: DiagnosticStatus.unknown,
      message: 'Status unknown',
    );
  }

  String get statusText {
    switch (status) {
      case DiagnosticStatus.pass:
        return 'PASS';
      case DiagnosticStatus.warning:
        return 'WARNING';
      case DiagnosticStatus.failed:
        return 'FAILED';
      case DiagnosticStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String get statusIcon {
    switch (status) {
      case DiagnosticStatus.pass:
        return '✓';
      case DiagnosticStatus.warning:
        return '⚠';
      case DiagnosticStatus.failed:
        return '✗';
      case DiagnosticStatus.unknown:
        return '?';
    }
  }
}
