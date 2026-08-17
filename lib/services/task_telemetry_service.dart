import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'attachment_service.dart';

/// Records bounded timing data for the current task without persisting prompts,
/// screenshots, API keys, or accessibility content.
class TaskTelemetryService {
  static final TaskTelemetryService shared = TaskTelemetryService._();

  TaskTelemetryService._();

  DateTime? _startedAt;
  final Map<String, Stopwatch> _stages = <String, Stopwatch>{};
  final Map<String, int> _stageTotals = <String, int>{};
  final Map<String, int> _stageCounts = <String, int>{};
  final Map<String, int> _actionTimings = <String, int>{};
  final Map<String, int> _latencyMs = <String, int>{};
  int _retries = 0;
  int _actionCount = 0;
  DateTime? _lastEventAt;
  final List<TaskDeveloperEvent> _events = <TaskDeveloperEvent>[];
  final List<WorkspaceCommandEntry> _workspaceCommands =
      <WorkspaceCommandEntry>[];
  List<WorkspaceAttachmentEntry> _queuedAttachments =
      <WorkspaceAttachmentEntry>[];
  String? _fastPathName;
  int _fastPathActions = 0;
  int _aiCallsAvoided = 0;
  String? _lastStatus;
  TaskTelemetrySnapshot? _lastSnapshot;

  final ValueNotifier<TaskDeveloperSnapshot> developerState =
      ValueNotifier<TaskDeveloperSnapshot>(TaskDeveloperSnapshot.idle());

  TaskTelemetrySnapshot? get lastSnapshot => _lastSnapshot;
  String? get lastStatus => _lastStatus;

  void start({String rootGoal = ''}) {
    _startedAt = DateTime.now();
    _stages.clear();
    _stageTotals.clear();
    _stageCounts.clear();
    _actionTimings.clear();
    _latencyMs.clear();
    _retries = 0;
    _actionCount = 0;
    _lastEventAt = null;
    _events.clear();
    final attachments = List<WorkspaceAttachmentEntry>.unmodifiable(
      _queuedAttachments,
    );
    _queuedAttachments = <WorkspaceAttachmentEntry>[];
    _workspaceCommands.clear();
    _fastPathName = null;
    _fastPathActions = 0;
    _aiCallsAvoided = 0;
    _lastStatus = null;
    _publish(
      TaskDeveloperSnapshot.idle().copyWith(
        isRunning: true,
        status: 'running',
        rootGoal: _sanitize(rootGoal),
        executionStage: 'starting',
        actionCount: 0,
        lastEventAt: null,
        events: const [],
        totalTaskDurationMs: 0,
        attachments: attachments,
      ),
    );
    _recordEvent('starting', 'Task started');
  }

  void stageStart(String stage) {
    _stages[stage] = Stopwatch()..start();
    _stageCounts[stage] = (_stageCounts[stage] ?? 0) + 1;
    if (_sanitize(stage) == 'action') _actionCount++;
    _publish(
      developerState.value.copyWith(
        executionStage: _sanitize(stage),
        actionCount: _actionCount,
      ),
    );
    _recordEvent(_sanitize(stage), 'Stage started');
  }

  void stageEnd(String stage) {
    final stopwatch = _stages.remove(stage);
    if (stopwatch != null && stopwatch.isRunning) {
      stopwatch.stop();
      _stageTotals[stage] =
          (_stageTotals[stage] ?? 0) + stopwatch.elapsedMilliseconds;
    }
  }

  void retry() {
    _retries++;
    _publish(developerState.value.copyWith(recoveryAttempts: _retries));
    _recordEvent('retry', 'Retry attempted');
  }

  void recordDeterministicFastPath({
    required String name,
    required int actions,
    int aiCallsAvoided = 1,
  }) {
    _fastPathName = _sanitize(name);
    _fastPathActions = actions < 0 ? 0 : actions;
    _aiCallsAvoided = aiCallsAvoided < 0 ? 0 : aiCallsAvoided;
    _publish(
      developerState.value.copyWith(
        executionStage: 'fast_path',
        fastPathUsed: true,
        fastPathName: _fastPathName,
        fastPathActions: _fastPathActions,
        aiCallsAvoided: _aiCallsAvoided,
      ),
    );
  }

  /// Queues only sanitized attachment metadata for the next real task.
  /// Raw paths and file contents are never published to telemetry.
  void recordAttachments(List<AttachmentReference> attachments) {
    _queuedAttachments = attachments
        .take(AttachmentService.maxAttachments)
        .map(
          (attachment) => WorkspaceAttachmentEntry(
            name: _sanitize(attachment.name),
            mimeType: _sanitize(attachment.mimeType),
            size: attachment.size < 0 ? 0 : attachment.size,
            summary: 'Bounded attachment context available to this task.',
          ),
        )
        .toList(growable: false);
    _publish(
      developerState.value.copyWith(
        attachments: List<WorkspaceAttachmentEntry>.from(_queuedAttachments),
      ),
    );
  }

  void recordWorkspaceCommand({
    required String command,
    required String workingDirectory,
    required int exitCode,
    required int elapsedMs,
    String output = '',
  }) {
    final entry = WorkspaceCommandEntry(
      timestamp: DateTime.now(),
      command: _sanitize(command),
      workingDirectory: _sanitize(workingDirectory),
      exitCode: exitCode,
      elapsedMs: elapsedMs < 0 ? 0 : elapsedMs,
      output: _sanitize(output),
    );
    _workspaceCommands.add(entry);
    if (_workspaceCommands.length > 20) {
      _workspaceCommands.removeAt(0);
    }
    _publish(
      developerState.value.copyWith(
        workspaceCommands: List<WorkspaceCommandEntry>.from(_workspaceCommands),
      ),
    );
    _recordEvent(
      'workspace_command',
      '${entry.command} • exit ${entry.exitCode}',
    );
  }

  void recordAiCall() {
    _recordEvent('ai_request', 'Provider request started');
    _publish(
      developerState.value.copyWith(
        aiCalls: developerState.value.aiCalls + 1,
        executionStage: 'ai_request',
      ),
    );
  }

  void recordScreenObservation({String? packageName}) {
    _recordEvent('screen_observation', 'Screen observation recorded');
    _publish(
      developerState.value.copyWith(
        screenObservations: developerState.value.screenObservations + 1,
        currentAppPackage: packageName == null
            ? developerState.value.currentAppPackage
            : _sanitize(packageName),
        executionStage: 'screen_observation',
      ),
    );
  }

  void recordPlannedAction({
    required String action,
    String? selectedTarget,
    double? confidence,
    String? subGoal,
    String? expectedResult,
  }) {
    final safeConfidence = confidence?.clamp(0.0, 1.0).toDouble();
    _recordEvent('target_selection', 'Target selection recorded');
    _publish(
      developerState.value.copyWith(
        executionStage: 'target_selection',
        plannedAction: _sanitize(action),
        selectedTarget: _sanitize(selectedTarget ?? ''),
        confidence: safeConfidence,
        currentSubGoal: subGoal == null
            ? developerState.value.currentSubGoal
            : _sanitize(subGoal),
        expectedResult: expectedResult == null
            ? developerState.value.expectedResult
            : _sanitize(expectedResult),
      ),
    );
  }

  void recordActionTiming(String action, int elapsedMs) {
    final safeAction = _sanitize(action);
    final safeElapsed = elapsedMs < 0 ? 0 : elapsedMs;
    _actionTimings[safeAction] =
        (_actionTimings[safeAction] ?? 0) + safeElapsed;
    _publish(
      developerState.value.copyWith(
        actionTimings: Map<String, int>.from(_actionTimings),
      ),
    );
  }

  /// Records elapsed time for a named subsystem without replacing an active
  /// stage stopwatch. This is used for nested native calls such as accessibility.
  void recordLatency(String stage, int elapsedMs) {
    final safeStage = _sanitize(stage);
    final safeElapsed = elapsedMs < 0 ? 0 : elapsedMs;
    _latencyMs[safeStage] = (_latencyMs[safeStage] ?? 0) + safeElapsed;
    _publish(
      developerState.value.copyWith(
        actionTimings: <String, int>{
          ..._actionTimings,
          'latency:$safeStage': _latencyMs[safeStage]!,
        },
      ),
    );
  }

  void recordVerification({
    required String diagnostic,
    required bool progressed,
  }) {
    _recordEvent('verification', _sanitize(diagnostic));
    _publish(
      developerState.value.copyWith(
        executionStage: 'verification',
        verificationResult: _sanitize(diagnostic),
        verificationPassed: progressed,
      ),
    );
  }

  void recordRecovery({required String description, required bool succeeded}) {
    _retries++;
    _recordEvent(
      'recovery',
      succeeded ? 'Recovery succeeded' : 'Recovery attempted',
    );
    _publish(
      developerState.value.copyWith(
        executionStage: 'recovery',
        recoveryAttempts: _retries,
        verificationResult: _sanitize(
          succeeded
              ? 'Recovery succeeded: $description'
              : 'Recovery failed: $description',
        ),
      ),
    );
  }

  void recordFailureDiagnosis({
    required String category,
    required String observed,
    required String likelyCause,
    required String evidence,
    required String recoveryAttempt,
    required String finalResult,
  }) {
    _publish(
      developerState.value.copyWith(
        failureCategory: _sanitize(category),
        diagnosisObserved: _sanitize(observed),
        diagnosisLikelyCause: _sanitize(likelyCause),
        diagnosisEvidence: _sanitize(evidence),
        diagnosisRecoveryAttempt: _sanitize(recoveryAttempt),
        diagnosisFinalResult: _sanitize(finalResult),
      ),
    );
  }

  void recordUpgradeState({
    required String stage,
    String? problem,
    List<String>? files,
    String? reason,
    String? evidence,
    String? finalResult,
    bool? canApply,
  }) {
    _publish(
      developerState.value.copyWith(
        upgradeStage: _sanitize(stage),
        upgradeProblem: problem == null
            ? developerState.value.upgradeProblem
            : _sanitize(problem),
        upgradeFiles: files == null
            ? developerState.value.upgradeFiles
            : _sanitize(files.join(', ')),
        upgradeReason: reason == null
            ? developerState.value.upgradeReason
            : _sanitize(reason),
        upgradeEvidence: evidence == null
            ? developerState.value.upgradeEvidence
            : _sanitize(evidence),
        upgradeFinalResult: finalResult == null
            ? developerState.value.upgradeFinalResult
            : _sanitize(finalResult),
        upgradeCanApply: canApply ?? developerState.value.upgradeCanApply,
      ),
    );
  }

  void recordUpgradeHistory(List<UpgradeHistoryEntry> history) {
    _publish(
      developerState.value.copyWith(
        upgradeHistory: List<UpgradeHistoryEntry>.from(history),
      ),
    );
  }

  void recordUpgradePlan(UpgradeExecutionPlan? plan) {
    _publish(developerState.value.copyWith(upgradePlan: plan));
  }

  void recordError(String error) {
    final safeError = _sanitize(error);
    _recordEvent('error', safeError);
    final errors = <String>[...developerState.value.errors, safeError];
    _publish(
      developerState.value.copyWith(
        executionStage: 'error',
        errors: errors.length > 20
            ? errors.sublist(errors.length - 20)
            : errors,
      ),
    );
  }

  void recordFinalResult(String result, {String status = 'complete'}) {
    _recordEvent('complete', _sanitize(result));
    _publish(
      developerState.value.copyWith(
        isRunning: false,
        status: _sanitize(status),
        executionStage: 'complete',
        finalResult: _sanitize(result),
      ),
    );
  }

  TaskTelemetrySnapshot finish({required String status, String? finalResult}) {
    for (final entry in _stages.entries.toList()) {
      stageEnd(entry.key);
    }
    final stageMs = <String, int>{
      ..._stageTotals,
      ..._latencyMs.map((key, value) => MapEntry('latency:$key', value)),
    };
    final snapshot = TaskTelemetrySnapshot(
      totalMs: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inMilliseconds,
      stageMs: stageMs,
      retries: _retries,
      aiCalls: developerState.value.aiCalls,
      observations: developerState.value.screenObservations,
      status: status,
    );
    _lastStatus = status;
    _lastSnapshot = snapshot;
    _publish(
      developerState.value.copyWith(totalTaskDurationMs: snapshot.totalMs),
    );
    recordFinalResult(finalResult ?? status, status: status);
    developer.log(snapshot.toSafeLogString(), name: 'AgentCypher.Telemetry');
    return snapshot;
  }

  void _publish(TaskDeveloperSnapshot next) {
    developerState.value = next;
  }

  void _recordEvent(String stage, String detail) {
    final safeStage = _sanitize(stage);
    final safeDetail = _sanitize(detail);
    _lastEventAt = DateTime.now();
    _events.add(
      TaskDeveloperEvent(
        timestamp: _lastEventAt!,
        stage: safeStage,
        detail: safeDetail,
      ),
    );
    if (_events.length > 50) {
      _events.removeRange(0, _events.length - 50);
    }
    _publish(
      developerState.value.copyWith(
        actionCount: _actionCount,
        lastEventAt: _lastEventAt,
        events: List<TaskDeveloperEvent>.from(_events),
      ),
    );
  }

  static String _sanitize(String value) {
    var safe = value.trim();
    if (safe.isEmpty) return '';
    safe = safe.replaceAll(
      RegExp(
        r'\b(?:sk-|nvapi-|github_pat_)[A-Za-z0-9_-]+',
        caseSensitive: false,
      ),
      '[REDACTED_SECRET]',
    );
    safe = safe.replaceAll(
      RegExp(
        r'\b(?:api[_ -]?key|access[_ -]?token|token|password|secret|credential)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      '[REDACTED_SECRET]',
    );
    safe = safe.replaceAllMapped(
      RegExp(
        r'([?&](?:api[_-]?key|access[_-]?token|token|key)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED_SECRET]',
    );
    safe = safe.replaceAll(
      RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
      'Bearer [REDACTED_SECRET]',
    );
    return safe.length > 500 ? '${safe.substring(0, 500)}…' : safe;
  }
}

class UpgradeHistoryEntry {
  final String id;
  final DateTime createdAt;
  final String status;
  final List<String> files;
  final String changeSummary;
  final String validationEvidence;
  final String finalResult;

  const UpgradeHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.files,
    required this.changeSummary,
    required this.validationEvidence,
    required this.finalResult,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'status': status,
    'files': files,
    'change_summary': changeSummary,
    'validation_evidence': validationEvidence,
    'final_result': finalResult,
  };
}

class UpgradePlanStage {
  final String id;
  final String title;
  final String status;
  final bool requiresPatch;
  final List<String> files;
  final List<String> dependencies;
  final List<String> selectedTests;
  final String expectedResult;
  final int attempts;
  final String error;

  const UpgradePlanStage({
    required this.id,
    required this.title,
    required this.status,
    required this.requiresPatch,
    required this.files,
    required this.dependencies,
    required this.selectedTests,
    required this.expectedResult,
    this.attempts = 0,
    this.error = '',
  });

  UpgradePlanStage copyWith({
    String? status,
    List<String>? files,
    List<String>? dependencies,
    List<String>? selectedTests,
    String? expectedResult,
    int? attempts,
    String? error,
  }) => UpgradePlanStage(
    id: id,
    title: title,
    status: status ?? this.status,
    requiresPatch: requiresPatch,
    files: files ?? this.files,
    dependencies: dependencies ?? this.dependencies,
    selectedTests: selectedTests ?? this.selectedTests,
    expectedResult: expectedResult ?? this.expectedResult,
    attempts: attempts ?? this.attempts,
    error: error ?? this.error,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'requires_patch': requiresPatch,
    'files': files,
    'dependencies': dependencies,
    'selected_tests': selectedTests,
    'expected_result': expectedResult,
    'attempts': attempts,
    'error': error,
  };
}

class UpgradeExecutionPlan {
  final String id;
  final DateTime createdAt;
  final String request;
  final String status;
  final int currentStageIndex;
  final List<String> impactedFiles;
  final Map<String, List<String>> dependencies;
  final List<String> selectedTests;
  final List<UpgradePlanStage> stages;
  final String lastError;

  const UpgradeExecutionPlan({
    required this.id,
    required this.createdAt,
    required this.request,
    required this.status,
    required this.currentStageIndex,
    required this.impactedFiles,
    required this.dependencies,
    required this.selectedTests,
    required this.stages,
    this.lastError = '',
  });

  UpgradeExecutionPlan copyWith({
    String? status,
    int? currentStageIndex,
    List<String>? impactedFiles,
    Map<String, List<String>>? dependencies,
    List<String>? selectedTests,
    List<UpgradePlanStage>? stages,
    String? lastError,
  }) => UpgradeExecutionPlan(
    id: id,
    createdAt: createdAt,
    request: request,
    status: status ?? this.status,
    currentStageIndex: currentStageIndex ?? this.currentStageIndex,
    impactedFiles: impactedFiles ?? this.impactedFiles,
    dependencies: dependencies ?? this.dependencies,
    selectedTests: selectedTests ?? this.selectedTests,
    stages: stages ?? this.stages,
    lastError: lastError ?? this.lastError,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'request': request,
    'status': status,
    'current_stage_index': currentStageIndex,
    'impacted_files': impactedFiles,
    'dependencies': dependencies,
    'selected_tests': selectedTests,
    'stages': stages.map((stage) => stage.toJson()).toList(),
    'last_error': lastError,
  };
}

class WorkspaceAttachmentEntry {
  final String name;
  final String mimeType;
  final int size;
  final String summary;

  const WorkspaceAttachmentEntry({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mime_type': mimeType,
    'size': size,
    'summary': summary,
  };
}

class WorkspaceCommandEntry {
  final DateTime timestamp;
  final String command;
  final String workingDirectory;
  final int exitCode;
  final int elapsedMs;
  final String output;

  const WorkspaceCommandEntry({
    required this.timestamp,
    required this.command,
    required this.workingDirectory,
    required this.exitCode,
    required this.elapsedMs,
    required this.output,
  });

  bool get succeeded => exitCode == 0;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'command': command,
    'working_directory': workingDirectory,
    'exit_code': exitCode,
    'elapsed_ms': elapsedMs,
    'output': output,
  };
}

class TaskDeveloperEvent {
  final DateTime timestamp;
  final String stage;
  final String detail;

  const TaskDeveloperEvent({
    required this.timestamp,
    required this.stage,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'stage': stage,
    'detail': detail,
  };
}

class TaskDeveloperSnapshot {
  final bool isRunning;
  final String status;
  final String rootGoal;
  final String currentSubGoal;
  final String expectedResult;
  final String currentAppPackage;
  final String executionStage;
  final String plannedAction;
  final String selectedTarget;
  final double? confidence;
  final String verificationResult;
  final bool? verificationPassed;
  final int recoveryAttempts;
  final int aiCalls;
  final int screenObservations;
  final int actionCount;
  final DateTime? lastEventAt;
  final List<TaskDeveloperEvent> events;
  final int totalTaskDurationMs;
  final Map<String, int> actionTimings;
  final List<String> errors;
  final String finalResult;
  final String failureCategory;
  final String diagnosisObserved;
  final String diagnosisLikelyCause;
  final String diagnosisEvidence;
  final String diagnosisRecoveryAttempt;
  final String diagnosisFinalResult;
  final bool fastPathUsed;
  final String fastPathName;
  final int fastPathActions;
  final int aiCallsAvoided;
  final String upgradeStage;
  final String upgradeProblem;
  final String upgradeFiles;
  final String upgradeReason;
  final String upgradeEvidence;
  final String upgradeFinalResult;
  final bool upgradeCanApply;
  final List<UpgradeHistoryEntry> upgradeHistory;
  final UpgradeExecutionPlan? upgradePlan;
  final List<WorkspaceCommandEntry> workspaceCommands;
  final List<WorkspaceAttachmentEntry> attachments;

  TaskDeveloperSnapshot({
    required this.isRunning,
    required this.status,
    required this.rootGoal,
    required this.currentSubGoal,
    required this.expectedResult,
    required this.currentAppPackage,
    required this.executionStage,
    required this.plannedAction,
    required this.selectedTarget,
    required this.confidence,
    required this.verificationResult,
    required this.verificationPassed,
    required this.recoveryAttempts,
    required this.aiCalls,
    required this.screenObservations,
    required this.actionCount,
    required this.lastEventAt,
    required List<TaskDeveloperEvent> events,
    required this.totalTaskDurationMs,
    required Map<String, int> actionTimings,
    required List<String> errors,
    required this.finalResult,
    required this.failureCategory,
    required this.diagnosisObserved,
    required this.diagnosisLikelyCause,
    required this.diagnosisEvidence,
    required this.diagnosisRecoveryAttempt,
    required this.diagnosisFinalResult,
    required this.fastPathUsed,
    required this.fastPathName,
    required this.fastPathActions,
    required this.aiCallsAvoided,
    required this.upgradeStage,
    required this.upgradeProblem,
    required this.upgradeFiles,
    required this.upgradeReason,
    required this.upgradeEvidence,
    required this.upgradeFinalResult,
    required this.upgradeCanApply,
    List<UpgradeHistoryEntry> upgradeHistory = const [],
    this.upgradePlan,
    List<WorkspaceCommandEntry> workspaceCommands = const [],
    List<WorkspaceAttachmentEntry> attachments = const [],
  }) : events = List.unmodifiable(events),
       actionTimings = Map.unmodifiable(actionTimings),
       errors = List.unmodifiable(errors),
       upgradeHistory = List.unmodifiable(upgradeHistory),
       workspaceCommands = List.unmodifiable(workspaceCommands),
       attachments = List.unmodifiable(attachments);

  factory TaskDeveloperSnapshot.idle() => TaskDeveloperSnapshot(
    isRunning: false,
    status: 'idle',
    rootGoal: '',
    currentSubGoal: '',
    expectedResult: '',
    currentAppPackage: '',
    executionStage: 'idle',
    plannedAction: '',
    selectedTarget: '',
    confidence: null,
    verificationResult: '',
    verificationPassed: null,
    recoveryAttempts: 0,
    aiCalls: 0,
    screenObservations: 0,
    actionCount: 0,
    lastEventAt: null,
    events: const [],
    totalTaskDurationMs: 0,
    actionTimings: const {},
    errors: const [],
    finalResult: '',
    failureCategory: '',
    diagnosisObserved: '',
    diagnosisLikelyCause: '',
    diagnosisEvidence: '',
    diagnosisRecoveryAttempt: '',
    diagnosisFinalResult: '',
    fastPathUsed: false,
    fastPathName: '',
    fastPathActions: 0,
    aiCallsAvoided: 0,
    upgradeStage: 'idle',
    upgradeProblem: '',
    upgradeFiles: '',
    upgradeReason: '',
    upgradeEvidence: '',
    upgradeFinalResult: '',
    upgradeCanApply: false,
    upgradePlan: null,
    workspaceCommands: const [],
    attachments: const [],
  );

  TaskDeveloperSnapshot copyWith({
    bool? isRunning,
    String? status,
    String? rootGoal,
    String? currentSubGoal,
    String? expectedResult,
    String? currentAppPackage,
    String? executionStage,
    String? plannedAction,
    String? selectedTarget,
    double? confidence,
    String? verificationResult,
    bool? verificationPassed,
    int? recoveryAttempts,
    int? aiCalls,
    int? screenObservations,
    int? actionCount,
    DateTime? lastEventAt,
    List<TaskDeveloperEvent>? events,
    int? totalTaskDurationMs,
    Map<String, int>? actionTimings,
    List<String>? errors,
    String? finalResult,
    String? failureCategory,
    String? diagnosisObserved,
    String? diagnosisLikelyCause,
    String? diagnosisEvidence,
    String? diagnosisRecoveryAttempt,
    String? diagnosisFinalResult,
    bool? fastPathUsed,
    String? fastPathName,
    int? fastPathActions,
    int? aiCallsAvoided,
    String? upgradeStage,
    String? upgradeProblem,
    String? upgradeFiles,
    String? upgradeReason,
    String? upgradeEvidence,
    String? upgradeFinalResult,
    bool? upgradeCanApply,
    List<UpgradeHistoryEntry>? upgradeHistory,
    UpgradeExecutionPlan? upgradePlan,
    List<WorkspaceCommandEntry>? workspaceCommands,
    List<WorkspaceAttachmentEntry>? attachments,
  }) => TaskDeveloperSnapshot(
    isRunning: isRunning ?? this.isRunning,
    status: status ?? this.status,
    rootGoal: rootGoal ?? this.rootGoal,
    currentSubGoal: currentSubGoal ?? this.currentSubGoal,
    expectedResult: expectedResult ?? this.expectedResult,
    currentAppPackage: currentAppPackage ?? this.currentAppPackage,
    executionStage: executionStage ?? this.executionStage,
    plannedAction: plannedAction ?? this.plannedAction,
    selectedTarget: selectedTarget ?? this.selectedTarget,
    confidence: confidence ?? this.confidence,
    verificationResult: verificationResult ?? this.verificationResult,
    verificationPassed: verificationPassed ?? this.verificationPassed,
    recoveryAttempts: recoveryAttempts ?? this.recoveryAttempts,
    aiCalls: aiCalls ?? this.aiCalls,
    screenObservations: screenObservations ?? this.screenObservations,
    actionCount: actionCount ?? this.actionCount,
    lastEventAt: lastEventAt ?? this.lastEventAt,
    events: events ?? this.events,
    totalTaskDurationMs: totalTaskDurationMs ?? this.totalTaskDurationMs,
    actionTimings: actionTimings ?? this.actionTimings,
    errors: errors ?? this.errors,
    finalResult: finalResult ?? this.finalResult,
    failureCategory: failureCategory ?? this.failureCategory,
    diagnosisObserved: diagnosisObserved ?? this.diagnosisObserved,
    diagnosisLikelyCause: diagnosisLikelyCause ?? this.diagnosisLikelyCause,
    diagnosisEvidence: diagnosisEvidence ?? this.diagnosisEvidence,
    diagnosisRecoveryAttempt:
        diagnosisRecoveryAttempt ?? this.diagnosisRecoveryAttempt,
    diagnosisFinalResult: diagnosisFinalResult ?? this.diagnosisFinalResult,
    fastPathUsed: fastPathUsed ?? this.fastPathUsed,
    fastPathName: fastPathName ?? this.fastPathName,
    fastPathActions: fastPathActions ?? this.fastPathActions,
    aiCallsAvoided: aiCallsAvoided ?? this.aiCallsAvoided,
    upgradeStage: upgradeStage ?? this.upgradeStage,
    upgradeProblem: upgradeProblem ?? this.upgradeProblem,
    upgradeFiles: upgradeFiles ?? this.upgradeFiles,
    upgradeReason: upgradeReason ?? this.upgradeReason,
    upgradeEvidence: upgradeEvidence ?? this.upgradeEvidence,
    upgradeFinalResult: upgradeFinalResult ?? this.upgradeFinalResult,
    upgradeCanApply: upgradeCanApply ?? this.upgradeCanApply,
    upgradeHistory: upgradeHistory ?? this.upgradeHistory,
    upgradePlan: upgradePlan ?? this.upgradePlan,
    workspaceCommands: workspaceCommands ?? this.workspaceCommands,
    attachments: attachments ?? this.attachments,
  );
}

class TaskTelemetrySnapshot {
  final int totalMs;
  final Map<String, int> stageMs;
  final int retries;
  final int aiCalls;
  final int observations;
  final String status;

  const TaskTelemetrySnapshot({
    required this.totalMs,
    required this.stageMs,
    required this.retries,
    required this.aiCalls,
    required this.observations,
    required this.status,
  });

  int get aiMs => stageMs['ai_request'] ?? 0;
  int get observationMs => stageMs['screen_observation'] ?? 0;
  int get accessibilityMs => stageMs['latency:accessibility'] ?? 0;
  int get actionMs => stageMs['action'] ?? 0;
  int get verificationMs => stageMs['verification'] ?? 0;
  int get recoveryMs => stageMs['recovery'] ?? 0;

  String toSafeLogString() =>
      'status=$status totalMs=$totalMs aiMs=$aiMs '
      'observationMs=$observationMs accessibilityMs=$accessibilityMs '
      'actionMs=$actionMs verificationMs=$verificationMs '
      'recoveryMs=$recoveryMs aiCalls=$aiCalls observations=$observations '
      'retries=$retries';
}
