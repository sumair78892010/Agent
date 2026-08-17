import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'ai_service.dart';
import 'screen_automation_service.dart';
import 'app_launcher_service.dart';
import 'notification_service.dart';
import 'task_history_logger.dart';
import 'shizuku_service.dart';
import 'skill_memory_service.dart';
import 'recovery_engine.dart';
import 'task_telemetry_service.dart';
import '../models/saved_skill.dart';

/// Executes multi-step UI automation tasks using LLM-guided screen reading.
///
/// Flow: User gives high-level goal → LLM reads screen → decides next action →
/// executes → reads screen again → repeats until goal is complete.
bool hasSufficientTargetConfidence(String action, double? confidence) {
  if (action != 'click_text' && action != 'click_at') return true;
  return confidence != null &&
      confidence.isFinite &&
      confidence >= 0.65 &&
      confidence <= 1.0;
}

class TaskExecutor {
  final AiService _aiService;
  final ScreenAutomationService _screenService;
  final AppLauncherService _appLauncher;
  final ShizukuService _shizukuService;
  final NotificationService _notificationService = NotificationService();
  final SkillMemoryService _skillMemory = SkillMemoryService();
  final RecoveryEngine _recoveryEngine = RecoveryEngine();

  /// Callback to report progress messages to the UI
  final void Function(String message)? onProgress;

  /// Set to true to cancel the running task
  bool _cancelled = false;
  Completer<void>? _cancelCompleter;

  TaskExecutor({
    required AiService aiService,
    required ScreenAutomationService screenService,
    required AppLauncherService appLauncher,
    required ShizukuService shizukuService,
    this.onProgress,
  }) : _aiService = aiService,
       _screenService = screenService,
       _appLauncher = appLauncher,
       _shizukuService = shizukuService;

  /// Cancel the currently running task — takes effect immediately
  void cancel() {
    _cancelled = true;
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
  }

  static const String _taskSystemPrompt = '''
You are a phone automation agent. You are given a TASK and the current SCREEN content.
You must decide what single action to take next to accomplish the task.

Respond with ONLY a JSON object (no markdown, no code fences):
{
  "action": "action_name",
  "params": {"key": "value", "confidence": 0.0},
  "reasoning": "why you chose this action",
  "is_complete": false
}

Available actions:
- click_text: {"text": "exact text to click"} - Click an element by its visible text
- click_at: {"x": 540, "y": 960} - Click at screen coordinates (use bounds from screen dump)
- type_text: {"text": "hello", "field_hint": "optional hint"} - Type into the focused/first edit field
- press_enter: {} - Press the Enter/Search key on the keyboard to submit a search/form
- scroll: {"direction": "down"} - Scroll down/up on the current view
- swipe: {"startX": 540, "startY": 2000, "endX": 540, "endY": 500} - Swipe from start to end coordinates (e.g. open app drawer, navigate carousels)
- press_back: {} - Press the back button
- press_home: {} - Press the home button
- open_app: {"app_name": "WhatsApp"} - Open an app
- wait: {} - Wait a moment for content to load
- done: {} - Task is complete

Rules:
- You will receive a TEXT DUMP of the accessibility tree containing exact text strings and center coordinates.
- ALWAYS use the text dump to decide your next action.
- If you need to click something, prefer using `click_text`. If the element does not have text, use `click_at` with the coordinates provided in the text dump.
- For click_text and click_at, include confidence from 0.0 to 1.0. Never guess a target without meaningful confidence.
- When typing in a search box, you MUST click it first, wait a step, and THEN type.
- After typing a search query, use `press_enter` once. If the screen does not change, click the exact visible suggestion text. Do not repeat the same submit action more than twice.
- Never scroll or swipe more than three times in a row. After three scrolls, choose the best visible result or take a different action instead of continuing to browse indefinitely.
- Set is_complete=true ONLY when the task is fully done.
- Do not mark a task complete merely because an action returned successfully; use observable screen evidence and the root goal.
- If you need to find something by scrolling, scroll and then check the screen again.
- If you need to open an app (like Wikipedia, Spotify, etc.) and you cannot find it after a couple of scrolls, ASSUME it is not installed. Immediately open Chrome or Google to search for the info on the web instead.
- If stuck after 3 attempts, set is_complete=true and explain in reasoning.
- Keep reasoning very brief (1 sentence)
''';

  /// Extract JSON safely even if wrapped in markdown or conversational text
  String _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }
    throw const FormatException(
      'AI response must be a JSON object without surrounding prose.',
    );
  }

  /// Execute a multi-step task with LLM guidance
  Future<String> executeTask(String userGoal) async {
    await ScreenAutomationService.logToNative(
      "[TaskExecutor] executeTask() CALLED with goal: $userGoal",
    );
    _cancelled = false;
    final telemetry = TaskTelemetryService.shared;
    telemetry.start(rootGoal: userGoal);
    telemetry.stageStart('understanding');
    telemetry.stageEnd('understanding');

    await ScreenAutomationService.logToNative(
      "[TaskExecutor] Checking if accessibility service is running...",
    );
    final isRunning = await _screenService.isServiceRunning();
    await ScreenAutomationService.logToNative(
      "[TaskExecutor] Accessibility service isRunning = $isRunning",
    );
    if (!isRunning) {
      await ScreenAutomationService.logToNative(
        "[TaskExecutor] Accessibility service not running, returning early.",
      );
      const message =
          'Accessibility service is not enabled. Go to Settings → Accessibility → Agent Cypher Screen Control and enable it.';
      telemetry.recordError(message);
      telemetry.finish(status: 'failed', finalResult: message);
      return message;
    }

    final results = <String>[];
    results.add('Starting task: $userGoal');
    _report('Starting task: $userGoal');

    // Check skill memory first
    final savedSkill = await _skillMemory.findSkill(userGoal);
    if (savedSkill != null && savedSkill.isReliable) {
      _report(
        'Found saved skill! Replaying ${savedSkill.steps.length} steps...',
      );
      final replaySuccess = await _replaySkill(savedSkill, results);
      if (replaySuccess) {
        results.add('Task complete via skill memory.');
        _report('Task complete (via skill memory).');
        await _notificationService.showTaskCompleteNotification(
          'Task Completed',
          'Agent finished its goal using memory.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Success',
          0,
          savedSkill.steps.length,
          results,
        );
        await _screenService.showToast('Task Complete! (Memory)');
        return 'Done.';
      } else {
        _report('Replay failed, falling back to AI...');
        await _skillMemory.recordFailure(savedSkill.id);
      }
    }

    // Smart pre-launch shortcuts: execute common sequences without LLM
    final shortcut = _getNavigationShortcut(userGoal);
    String lastAction = '';
    int sameActionCount = 0;
    int consecutiveFailures = 0;
    String lastFailedAction = '';
    int totalTokens = 0;
    final List<ActionStep> executedSteps = [];

    if (shortcut != null && shortcut.isNotEmpty) {
      results.add('Using navigation shortcut: ${shortcut.length} steps');
      _report('Using navigation shortcut...');
      for (final step in shortcut) {
        if (_cancelled) break;

        bool success = false;
        if (step.action == 'open_app') {
          final appName = step.params['app_name'] as String? ?? '';
          final res = await _appLauncher.openApp(appName);
          success = res.startsWith('Opened');
          await Future.delayed(const Duration(milliseconds: 650));
        } else if (step.action == 'click_text') {
          final text = step.params['text'] as String? ?? '';
          success = await _screenService.clickByText(text);
          await Future.delayed(const Duration(milliseconds: 650));
        }

        if (success) {
          executedSteps.add(step);
          lastAction = step.action;
        } else {
          break; // Fall back to AI if shortcut step fails
        }
      }
    } else {
      // If no shortcut is used, and we are currently inside the Agent Cypher app,
      // press Home so the AI doesn't see its own chat bubbles and get confused by the task text.
      final currentPkg = await _screenService.getCurrentPackage();
      if (currentPkg == 'com.cypherghost.agentcypher') {
        _report('Moving to background...');
        await _screenService.pressHome();
        await Future.delayed(const Duration(milliseconds: 650));
      }
    }

    for (int step = 0; step < _aiService.maxSteps; step++) {
      // Check for cancellation
      if (_cancelled) {
        results.add('Task cancelled by user.');
        _report('Task cancelled.');
        await _notificationService.showTaskCompleteNotification(
          'Task Cancelled',
          'Task was stopped by the user.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Cancelled',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('Task Cancelled');
        return 'Task cancelled.';
      }

      // Adaptive delay: give Android apps time to transition screens, load data, or open keyboards
      int delay =
          450; // Allow a brief UI settle without adding avoidable latency.
      if (lastAction == 'open_app') {
        delay =
            1400; // Cold starts get a bounded settle window; observation verifies readiness.
      } else if (lastAction == 'type_text') {
        delay =
            900; // Keep a short keyboard/network settle window; observation verifies results.
      } else if (lastAction == 'click_text' || lastAction == 'click_at') {
        delay =
            650; // A short transition window; the next observation is authoritative.
      } else if (lastAction == 'scroll') {
        delay =
            450; // Scrolling is fast; avoid an unnecessary full-second pause.
      }
      await Future.delayed(Duration(milliseconds: delay));

      // 1. Read the current screen text using the compact, structured screen state
      telemetry.stageStart('screen_observation');
      final screenState = await _screenService.getCompactScreenState(
        task: userGoal,
      );
      final screenContent =
          screenState['summary'] as String? ??
          (_aiService.useScreenCompression
              ? await _screenService.getCompressedScreenDescription(userGoal)
              : await _screenService.getScreenDescription());
      developer.log(
        '=== SCREEN STATE (Step ${step + 1}) ===\n$screenContent',
        name: 'AgentCypher',
      );
      _report('Observing screen state (${screenState['package']})...');
      telemetry.stageEnd('screen_observation');
      telemetry.recordScreenObservation(
        packageName: screenState['package'] as String?,
      );

      // Determine previous result string
      final prevResultStr = step > 0 && results.isNotEmpty
          ? '\nPREVIOUS ACTION RESULT: ${results.last}\n'
          : '';

      // Build failure hint if agent is stuck in a loop
      String failureHint = '';
      if (consecutiveFailures >= 3) {
        failureHint =
            '\n\nWARNING: You have failed $consecutiveFailures times in a row with the same approach. You MUST try a completely different action. If open_app failed, try press_home and look for the app icon on the home screen instead. If click_text failed, use click_at with coordinates. Do NOT repeat the same failed action.';
      }

      // 2. Build the prompt (system prompt is sent separately via sendTaskMessage)
      final prompt =
          '''TASK: $userGoal

CURRENT SCREEN TEXT DUMP:
$screenContent$prevResultStr$failureHint
Step ${step + 1}/${_aiService.maxSteps}. Look at the text dump and coordinates. What is the next action?''';

      developer.log('=== AI PROMPT ===\n$prompt', name: 'AgentCypher');

      // 3. Get AI response — races against cancel signal so Stop works immediately
      String response;
      try {
        _cancelCompleter = Completer<void>();
        telemetry.stageStart('ai_request');
        telemetry.recordAiCall();
        final aiFuture = _aiService.sendTaskMessage(_taskSystemPrompt, prompt);

        // Race: whichever finishes first wins
        final result = await Future.any([
          aiFuture.then((r) => r),
          _cancelCompleter!.future.then((_) => null),
        ]);

        if (result == null || _cancelled) {
          results.add('Task cancelled by user.');
          _report('Task cancelled.');
          await _notificationService.showTaskCompleteNotification(
            'Task Cancelled',
            'Task was stopped by the user.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Cancelled',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Task Cancelled');
          return 'Task cancelled.';
        }

        final aiResponse = result as AiResponse;
        response = aiResponse.content;
        totalTokens += aiResponse.totalTokens;
        telemetry.stageEnd('ai_request');

        developer.log(
          '=== RAW AI RESPONSE ===\n$response',
          name: 'AgentCypher',
        );
      } catch (e) {
        if (_cancelled) {
          results.add('Task cancelled by user.');
          _report('Task cancelled.');
          await _notificationService.showTaskCompleteNotification(
            'Task Cancelled',
            'Task was stopped by the user.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Cancelled',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Task Cancelled');
          await Future.delayed(const Duration(milliseconds: 500));
          return 'Task cancelled.';
        }
        results.add('AI error: $e');
        _report('Error: $e');
        await _notificationService.showTaskCompleteNotification(
          'Task Error',
          'AI encountered an error.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Failed',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('AI Error: $e');
        await Future.delayed(const Duration(milliseconds: 700));
        return 'I could not complete the task because the AI service failed.';
      }

      // Check for cancellation after AI response
      if (_cancelled) {
        results.add('Task cancelled by user.');
        _report('Task cancelled.');
        await _notificationService.showTaskCompleteNotification(
          'Task Cancelled',
          'Task was stopped by the user.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Cancelled',
          totalTokens,
          step,
          results,
        );
        await _screenService.showToast('Task Cancelled');
        await Future.delayed(const Duration(milliseconds: 500));
        return 'Task cancelled.';
      }

      // 4. Parse the action (with one retry on failure)
      Map<String, dynamic>? actionJson;
      String? parsedJsonStr;
      try {
        String jsonStr = _extractJson(response);

        actionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
        parsedJsonStr = jsonStr;
      } catch (firstError) {
        // First attempt failed — retry once
        developer.log(
          '=== JSON PARSE FAILED, RETRYING ===\nError: $firstError\nRaw: $response',
          name: 'AgentCypher',
        );
        _report('Retrying step ${step + 1}...\n(Failed to parse: $firstError)');
        // Wait 2 seconds before retrying to prevent rate-limit spam
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final retryResponse = await _aiService.sendTaskMessage(
            _taskSystemPrompt,
            prompt,
          );
          totalTokens += retryResponse.totalTokens;
          developer.log(
            '=== RETRY AI RESPONSE ===\n${retryResponse.content}',
            name: 'AgentCypher',
          );

          String jsonStr = _extractJson(retryResponse.content);
          actionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
          parsedJsonStr = jsonStr;
        } catch (e) {
          results.add('Step ${step + 1}: Error after retry: $e');

          String debugInfo = 'Error: $e';
          _report('AI Error: $debugInfo\n\nRaw output:\n${response}');

          await _notificationService.showTaskCompleteNotification(
            'Task Error',
            'AI formatting error.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Failed',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Agent Error: $e');
          await Future.delayed(const Duration(milliseconds: 700));
          return 'I could not understand the AI response. Please try again.';
        }
      }

      final action = actionJson['action'] as String?;
      if (action == null || action.trim().isEmpty) {
        results.add('Step ${step + 1}: AI response omitted an action.');
        _report('AI response omitted an action; observing again.');
        consecutiveFailures++;
        continue;
      }
      final params = actionJson['params'] as Map<String, dynamic>? ?? {};
      final reasoning = actionJson['reasoning'] as String? ?? '';
      final isComplete = actionJson['is_complete'] == true;

      developer.log(
        '=== PARSED ACTION ===\nAction: $action\nParams: $params\nReasoning: $reasoning\nIs Complete: $isComplete',
        name: 'AgentCypher',
      );

      _report('Step ${step + 1}: $reasoning');
      telemetry.recordPlannedAction(
        action: action,
        selectedTarget:
            params['text'] as String? ?? params['app_name'] as String?,
        confidence: (params['confidence'] as num?)?.toDouble(),
        subGoal: 'Step ${step + 1}: $reasoning',
        expectedResult: isComplete
            ? 'The root goal is complete.'
            : 'The current screen advances toward the root goal.',
      );
      if (action == 'press_enter' ||
          action == 'type_text' ||
          action == 'click_text') {
        _report('Verifying UI change after action...');
      }

      final confidence = (params['confidence'] as num?)?.toDouble();
      if (!hasSufficientTargetConfidence(action, confidence)) {
        final blockedResult =
            'Rejected low-confidence target for $action; observing again before any click.';
        results.add(blockedResult);
        _report(blockedResult);
        telemetry.recordVerification(
          diagnostic: blockedResult,
          progressed: false,
        );
        consecutiveFailures++;
        lastFailedAction = action;
        continue;
      }

      sameActionCount = action == lastAction ? sameActionCount + 1 : 1;
      final repeatLimit = action == 'press_enter'
          ? 2
          : (action == 'scroll' || action == 'swipe' ? 3 : 1000);
      if (sameActionCount > repeatLimit) {
        final blockedResult =
            'Blocked repeated $action action. Use a different action on the visible screen.';
        results.add(blockedResult);
        _report(blockedResult);
        consecutiveFailures = 3;
        lastFailedAction = action;
        lastAction = action;
        continue;
      }
      lastAction = action; // Track for adaptive delay

      // 5. Execute the action
      telemetry.stageStart('action');
      final actionStopwatch = Stopwatch()..start();
      bool success = false;
      String actionResult = '';

      switch (action) {
        case 'click_text':
          final text = params['text'] as String? ?? '';
          success = await _screenService.clickByText(text);
          actionResult = success
              ? 'Clicked "$text"'
              : 'Could not find "$text" to click';
          break;

        case 'click_at':
          final x = (params['x'] as num?)?.toDouble() ?? 0;
          final y = (params['y'] as num?)?.toDouble() ?? 0;
          success = await _screenService.clickAt(x, y);
          actionResult = success ? 'Clicked at ($x, $y)' : 'Click failed';
          break;

        case 'type_text':
          final text = params['text'] as String? ?? '';
          final hint = params['field_hint'] as String?;
          success = await _screenService.typeText(text, fieldHint: hint);
          actionResult = success ? 'Typed "$text"' : 'Could not type text';
          break;

        case 'press_enter':
          success = await _submitKeyboardAction();
          actionResult = success
              ? 'Submitted the focused search/form field'
              : 'Could not submit the focused field';
          break;

        case 'swipe':
          final startX = (params['startX'] as num?)?.toDouble() ?? 540;
          final startY = (params['startY'] as num?)?.toDouble() ?? 2000;
          final endX = (params['endX'] as num?)?.toDouble() ?? 540;
          final endY = (params['endY'] as num?)?.toDouble() ?? 500;

          success = await _performSwipe(startX, startY, endX, endY);
          actionResult = 'Swiped from ($startX,$startY) to ($endX,$endY)';
          break;

        case 'scroll':
          final direction = params['direction'] as String? ?? 'down';
          success = await _performScroll(direction);
          actionResult = success
              ? 'Scrolled $direction'
              : 'Could not scroll $direction';
          break;

        case 'press_back':
          success = await _screenService.pressBack();
          actionResult = 'Pressed back';
          break;

        case 'press_home':
          success = await _screenService.pressHome();
          actionResult = 'Pressed home';
          break;

        case 'open_app':
          final appName = params['app_name'] as String? ?? '';
          actionResult = await _appLauncher.openApp(appName);
          success = actionResult.startsWith('Opened');
          break;

        case 'wait':
          await Future.delayed(const Duration(seconds: 1));
          actionResult = 'Waited';
          success = true;
          break;

        case 'done':
          final completionVerified = await _verifyGoalCompletion(
            userGoal,
            screenState,
            screenContent,
          );
          if (!completionVerified) {
            const blockedResult =
                'Completion rejected: observable evidence does not prove the root goal is complete.';
            results.add(blockedResult);
            _report(blockedResult);
            telemetry.recordVerification(
              diagnostic: blockedResult,
              progressed: false,
            );
            consecutiveFailures++;
            lastFailedAction = 'done';
            continue;
          }
          results.add('Task complete: $reasoning');
          _report('Task complete: $reasoning');
          final finalReason = reasoning.trim().isEmpty
              ? 'Done.'
              : reasoning.trim();
          telemetry.finish(status: 'complete', finalResult: finalReason);
          await _notificationService.showTaskCompleteNotification(
            'Task Completed',
            reasoning.trim().isEmpty ? 'Agent finished its goal.' : reasoning,
          );
          await _screenService.showToast('Task completed');
          return finalReason;

        default:
          actionResult = 'Unknown action: $action';
      }

      actionStopwatch.stop();
      telemetry.stageEnd('action');
      telemetry.recordActionTiming(action, actionStopwatch.elapsedMilliseconds);
      telemetry.recordVerification(
        diagnostic: success
            ? 'Action returned success: $actionResult'
            : 'Action returned failure: $actionResult',
        progressed: success,
      );
      developer.log(
        '=== NATIVE EXECUTION RESULT ===\n$actionResult',
        name: 'AgentCypher',
      );

      // Track consecutive failures to detect stuck loops
      if (!success) {
        if (action == lastFailedAction) {
          consecutiveFailures++;
        } else {
          consecutiveFailures = 1;
          lastFailedAction = action;
        }

        // If stuck for 5+ consecutive failures, give up on this task
        if (consecutiveFailures >= 5) {
          results.add(
            'Agent is stuck. Stopping task after $consecutiveFailures consecutive failures.',
          );
          _report('Agent stuck — stopping task.');
          await _notificationService.showTaskCompleteNotification(
            'Task Stuck',
            'Agent could not complete the task after repeated failures.',
          );
          await TaskHistoryLogger.logTask(
            userGoal,
            'Failed',
            totalTokens,
            step,
            results,
          );
          await _screenService.showToast('Agent stuck. Task stopped.');
          await Future.delayed(const Duration(milliseconds: 900));
          return 'I could not complete the task. Please try again.';
        }

        // Use improved recovery engine to get multiple recovery strategies
        final recoveryActions = await _recoveryEngine.diagnoseWithAlternatives(
          action,
          screenContent,
          lastAttemptedValue: action == 'click_text'
              ? params['text'] as String?
              : action == 'type_text'
              ? params['text'] as String?
              : null,
        );

        if (recoveryActions.isNotEmpty) {
          // Try recovery actions in priority order (lowest priority number first)
          recoveryActions.sort((a, b) => a.priority.compareTo(b.priority));

          bool recoverySucceeded = false;
          for (final recovery in recoveryActions.take(2)) {
            // Try first 2 alternatives max
            if (recovery.action == 'give_up') {
              // Don't attempt recovery if engine recommends giving up
              results.add('Recovery: Too many failures. Giving up.');
              _report('Too many failures. Stopping task.');
              consecutiveFailures = 5; // Trigger stop condition
              break;
            }

            _report('Attempting recovery: ${recovery.description}');
            telemetry.stageStart('recovery');

            try {
              if (recovery.action == 'wait') {
                final ms = (recovery.params['milliseconds'] as int?) ?? 1000;
                await Future.delayed(Duration(milliseconds: ms));
                recoverySucceeded = true;
              } else if (recovery.action == 'press_back') {
                await _screenService.pressBack();
                recoverySucceeded = true;
              } else if (recovery.action == 'scroll') {
                final dir = recovery.params['direction'] as String? ?? 'down';
                final amount = (recovery.params['amount'] as int?) ?? 3;
                for (int i = 0; i < amount; i++) {
                  await _performScroll(dir);
                  await Future.delayed(const Duration(milliseconds: 400));
                }
                recoverySucceeded = true;
              } else if (recovery.action == 'press_home') {
                await _screenService.pressHome();
                recoverySucceeded = true;
              } else if (recovery.action == 'read_screen') {
                // Just a signal to re-read the screen on next iteration
                recoverySucceeded = true;
              } else if (recovery.action == 'click_text') {
                final text = recovery.params['text'] as String?;
                if (text != null) {
                  await _screenService.clickByText(text);
                  recoverySucceeded = true;
                }
              } else if (recovery.action == 'wait_for_user') {
                results.add(
                  'Recovery: ${recovery.description} Human input is required to continue.',
                );
                _report(
                  'Waiting for human verification on the current screen.',
                );
                recoverySucceeded = true;
                _cancelled = true;
              }

              telemetry.stageEnd('recovery');
              telemetry.recordRecovery(
                description: recovery.description,
                succeeded: recoverySucceeded,
              );
              if (recoverySucceeded) {
                results.add('Recovery: ${recovery.description}');
                break; // Success - don't try more recovery actions
              }
            } catch (e) {
              developer.log(
                'Recovery action ${recovery.action} failed: $e',
                name: 'AgentCypher',
              );
              // Continue to next recovery strategy
            }
          }

          if (!recoverySucceeded) {
            _report('Recovery failed. Retrying task...');
            results.add('Recovery actions exhausted, continuing with task...');
          }
        }
        continue;
      } else {
        consecutiveFailures = 0;
        lastFailedAction = '';
        executedSteps.add(ActionStep(action: action, params: params));
      }

      results.add('Step ${step + 1}: $actionResult ($reasoning)');

      // Provide progress feedback
      if (!isComplete && (step + 1) % 3 == 0) {
        await _screenService.showToast('Working... (Step ${step + 1})');
      }

      if (isComplete) {
        final completionVerified = await _verifyGoalCompletion(
          userGoal,
          screenState,
          screenContent,
        );
        if (!completionVerified) {
          const blockedResult =
              'Completion claim rejected: observable evidence does not yet prove the root goal is complete.';
          results.add(blockedResult);
          _report(blockedResult);
          telemetry.recordVerification(
            diagnostic: blockedResult,
            progressed: false,
          );
          consecutiveFailures++;
          lastFailedAction = action;
          continue;
        }

        results.add('Task complete.');
        _report('Task complete.');
        telemetry.finish(status: 'complete', finalResult: 'Done.');
        await _notificationService.showTaskCompleteNotification(
          'Task Completed',
          'Agent finished its goal.',
        );
        await TaskHistoryLogger.logTask(
          userGoal,
          'Success',
          totalTokens,
          step,
          results,
        );

        // Save to skill memory only after independent completion verification.
        await _skillMemory.saveSkill(userGoal, executedSteps);

        await _screenService.showToast('Task Complete!');
        await Future.delayed(const Duration(milliseconds: 900));
        return reasoning.trim().isEmpty ? 'Done.' : reasoning.trim();
      }
    }

    results.add(
      'Reached maximum steps (${_aiService.maxSteps}). Task may be incomplete.',
    );
    _report('Reached maximum steps.');
    await _notificationService.showTaskCompleteNotification(
      'Task Stopped',
      'Reached maximum steps (${_aiService.maxSteps}).',
    );
    await TaskHistoryLogger.logTask(
      userGoal,
      'Failed',
      totalTokens,
      _aiService.maxSteps,
      results,
    );
    await _screenService.showToast('Reached maximum steps.');
    await Future.delayed(const Duration(milliseconds: 900));

    const finalMessage =
        'I could not complete the task within the allowed steps.';
    telemetry.finish(status: 'failed', finalResult: finalMessage);
    return finalMessage;
  }

  /// Verifies model-declared completion against observable device state.
  /// A successful native call or `is_complete=true` is never sufficient alone.
  Future<bool> _verifyGoalCompletion(
    String userGoal,
    Map<String, dynamic> screenState,
    String screenContent,
  ) async {
    final goal = userGoal.toLowerCase().trim();
    final packageName = (screenState['package'] as String? ?? '').toLowerCase();
    final visible = screenContent.toLowerCase();

    // Opening an app is verified from the actual foreground package or visible
    // app identity, not from the launcher API's return string.
    final openMatch = RegExp(
      r'\b(?:open|launch|start)\s+([a-z0-9][a-z0-9 ._-]{1,40})',
    ).firstMatch(goal);
    if (openMatch != null) {
      final requested = openMatch.group(1)!.trim();
      final normalizedRequested = requested.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final normalizedPackage = packageName.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final normalizedVisible = visible.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return normalizedRequested.isNotEmpty &&
          (normalizedPackage.contains(normalizedRequested) ||
              normalizedVisible.contains(normalizedRequested));
    }

    // Search/find goals require meaningful query/result evidence on screen.
    final terms = goal
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .where(
          (word) => !const {
            'search',
            'google',
            'open',
            'first',
            'link',
            'result',
            'find',
            'look',
            'click',
            'show',
            'please',
            'using',
            'then',
          }.contains(word),
        )
        .take(6)
        .toList();
    if (terms.isNotEmpty) {
      final matches = terms.where(visible.contains).length;
      if (matches >= (terms.length >= 3 ? 2 : 1)) return true;
    }

    // Generic completion still requires non-trivial observable screen state.
    return visible.trim().length >= 20;
  }

  /// Verifies model-declared completion against observable device state.
  /// A successful native call or `is_complete=true` is never sufficient alone.
  Future<bool> _verifyGoalCompletion(
    String userGoal,
    Map<String, dynamic> screenState,
    String screenContent,
  ) async {
    final goal = userGoal.toLowerCase().trim();
    final packageName = (screenState['package'] as String? ?? '').toLowerCase();
    final visible = screenContent.toLowerCase();

    // Opening an app is verified from the actual foreground package or visible
    // app identity, not from the launcher API's return string.
    final openMatch = RegExp(
      r'\b(?:open|launch|start)\s+([a-z0-9][a-z0-9 ._-]{1,40})',
    ).firstMatch(goal);
    if (openMatch != null) {
      final requested = openMatch.group(1)!.trim();
      final normalizedRequested = requested.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final normalizedPackage = packageName.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final normalizedVisible = visible.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return normalizedRequested.isNotEmpty &&
          (normalizedPackage.contains(normalizedRequested) ||
              normalizedVisible.contains(normalizedRequested));
    }

    // Search/find goals require meaningful query/result evidence on screen.
    final terms = goal
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .where(
          (word) => !const {
            'search',
            'google',
            'open',
            'first',
            'link',
            'result',
            'find',
            'look',
            'click',
            'show',
            'please',
            'using',
            'then',
          }.contains(word),
        )
        .take(6)
        .toList();
    if (terms.isNotEmpty) {
      final matches = terms.where(visible.contains).length;
      if (matches >= (terms.length >= 3 ? 2 : 1)) return true;
    }

    // Generic completion still requires non-trivial observable screen state.
    return visible.trim().length >= 20;
  }

  void _report(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('planning') || lower.contains('shortcut')) {
      TaskTelemetryService.shared.stageStart('planning');
      TaskTelemetryService.shared.stageEnd('planning');
    } else if (lower.contains('verif')) {
      TaskTelemetryService.shared.stageStart('verification');
      TaskTelemetryService.shared.stageEnd('verification');
    } else if (lower.contains('error') || lower.contains('failed')) {
      TaskTelemetryService.shared.recordError(message);
    }
    onProgress?.call(message);
  }

  Future<bool> _submitKeyboardAction() async {
    if (await _screenService.pressEnter()) return true;

    final shizukuAvailable = await _shizukuService.checkAvailability();
    if (!shizukuAvailable) return false;

    final result = await _shizukuService.runCommand('input keyevent 66');
    final normalized = result.toLowerCase();
    return !normalized.contains('not running') &&
        !normalized.contains('permission denied') &&
        !normalized.startsWith('error');
  }

  Future<bool> _performScroll(String direction) async {
    if (await _screenService.scroll(direction)) return true;

    final isDown = direction.toLowerCase() == 'down';
    return _performSwipe(540, isDown ? 1800 : 600, 540, isDown ? 600 : 1800);
  }

  Future<bool> _performSwipe(
    double startX,
    double startY,
    double endX,
    double endY,
  ) async {
    if (await _screenService.swipe(startX, startY, endX, endY)) return true;

    final shizukuAvailable = await _shizukuService.checkAvailability();
    if (!shizukuAvailable) return false;

    final result = await _shizukuService.runCommand(
      'input swipe ${startX.toInt()} ${startY.toInt()} '
      '${endX.toInt()} ${endY.toInt()} 600',
    );
    final normalized = result.toLowerCase();
    return !normalized.contains('not running') &&
        !normalized.contains('permission denied') &&
        !normalized.startsWith('error');
  }

  /// Replays a saved skill without using the LLM
  Future<bool> _replaySkill(SavedSkill skill, List<String> results) async {
    for (int i = 0; i < skill.steps.length; i++) {
      if (_cancelled) return false;

      final step = skill.steps[i];
      _report('Replaying step ${i + 1}/${skill.steps.length}: ${step.action}');

      // Delay before executing each step
      int delay = 1200;
      if (step.action == 'open_app')
        delay = 3000;
      else if (step.action == 'type_text')
        delay = 2000;
      else if (step.action == 'click_text' || step.action == 'click_at')
        delay = 1500;
      else if (step.action == 'scroll')
        delay = 1000;

      await Future.delayed(Duration(milliseconds: delay));

      bool success = false;
      String actionResult = '';

      switch (step.action) {
        case 'click_text':
          final text = step.params['text'] as String? ?? '';
          success = await _screenService.clickByText(text);
          actionResult = success
              ? 'Clicked "$text"'
              : 'Could not find "$text" to click';
          break;
        case 'click_at':
          final x = (step.params['x'] as num?)?.toDouble() ?? 0;
          final y = (step.params['y'] as num?)?.toDouble() ?? 0;
          success = await _screenService.clickAt(x, y);
          actionResult = success ? 'Clicked at ($x, $y)' : 'Click failed';
          break;
        case 'type_text':
          final text = step.params['text'] as String? ?? '';
          final hint = step.params['field_hint'] as String?;
          success = await _screenService.typeText(text, fieldHint: hint);
          actionResult = success ? 'Typed "$text"' : 'Could not type text';
          break;
        case 'press_enter':
          success = await _submitKeyboardAction();
          actionResult = success
              ? 'Submitted the focused search/form field'
              : 'Could not submit the focused field';
          break;
        case 'swipe':
          final startX = (step.params['startX'] as num?)?.toDouble() ?? 540;
          final startY = (step.params['startY'] as num?)?.toDouble() ?? 2000;
          final endX = (step.params['endX'] as num?)?.toDouble() ?? 540;
          final endY = (step.params['endY'] as num?)?.toDouble() ?? 500;
          success = await _performSwipe(startX, startY, endX, endY);
          actionResult = 'Swiped from ($startX,$startY) to ($endX,$endY)';
          break;
        case 'scroll':
          final direction = step.params['direction'] as String? ?? 'down';
          success = await _performScroll(direction);
          actionResult = success
              ? 'Scrolled $direction'
              : 'Could not scroll $direction';
          break;
        case 'press_back':
          success = await _screenService.pressBack();
          actionResult = 'Pressed back';
          break;
        case 'press_home':
          success = await _screenService.pressHome();
          actionResult = 'Pressed home';
          break;
        case 'open_app':
          final appName = step.params['app_name'] as String? ?? '';
          actionResult = await _appLauncher.openApp(appName);
          success = actionResult.startsWith('Opened');
          break;
        case 'wait':
          await Future.delayed(const Duration(seconds: 1));
          actionResult = 'Waited';
          success = true;
          break;
        case 'done':
          success = true;
          actionResult = 'Done step reached';
          break;
        default:
          success = false;
          actionResult = 'Unknown action: ${step.action}';
      }

      results.add('Memory Replay Step ${i + 1}: $actionResult');
      developer.log(
        '=== MEMORY REPLAY RESULT ===\n$actionResult',
        name: 'AgentCypher',
      );

      if (!success) {
        return false; // Break out of replay if a step fails
      }
    }

    return true; // All steps succeeded
  }

  /// Returns predefined navigation steps for common tasks
  List<ActionStep>? _getNavigationShortcut(String goal) {
    final lower = goal.toLowerCase();

    if (lower.contains('dark mode') || lower.contains('dark theme')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(action: 'click_text', params: {'text': 'Display'}),
      ];
    }
    if (lower.contains('wifi') || lower.contains('wi-fi')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(
          action: 'click_text',
          params: {'text': 'Network & internet'},
        ),
      ];
    }
    if (lower.contains('bluetooth')) {
      return [
        ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
        ActionStep(action: 'click_text', params: {'text': 'Connected devices'}),
      ];
    }

    final appPatterns = <String, List<String>>{
      'Settings': ['settings', 'brightness', 'display', 'notification'],
      'Play Store': [
        'play store',
        'playstore',
        'download',
        'install app',
        'google play',
      ],
      'YouTube': ['youtube'],
      'WhatsApp': ['whatsapp'],
      'Chrome': ['chrome', 'browse', 'search google'],
      'Camera': ['camera', 'take a photo', 'take photo', 'take a picture'],
      'Gallery': ['gallery', 'photos'],
      'Messages': ['message', 'sms', 'text to'],
      'Phone': ['call', 'dial'],
      'Gmail': ['gmail', 'email'],
      'Maps': ['maps', 'navigate to', 'directions'],
      'Clock': ['alarm', 'timer', 'stopwatch'],
      'Calculator': ['calculator', 'calculate', 'calc'],
    };

    for (final entry in appPatterns.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return [
            ActionStep(action: 'open_app', params: {'app_name': entry.key}),
          ];
        }
      }
    }

    // Generic fallback for "open X"
    final openMatch = RegExp(r'^open\s+([a-zA-Z0-9]+)').firstMatch(lower);
    if (openMatch != null) {
      String app = openMatch.group(1)!;
      app = app[0].toUpperCase() + app.substring(1);
      return [
        ActionStep(action: 'open_app', params: {'app_name': app}),
      ];
    }

    return null;
  }
}
