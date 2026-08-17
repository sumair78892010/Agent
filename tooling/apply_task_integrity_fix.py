from pathlib import Path

TARGET = Path('lib/services/task_executor.dart')


def main() -> None:
    source = TARGET.read_text()
    original = source

    helper_anchor = '  void _report(String message) {'
    helper = '''  /// Verifies model-declared completion against observable device state.
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
      r'\\b(?:open|launch|start)\\s+([a-z0-9][a-z0-9 ._-]{1,40})',
    ).firstMatch(goal);
    if (openMatch != null) {
      final requested = openMatch.group(1)!.trim();
      final normalizedRequested =
          requested.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final normalizedPackage =
          packageName.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final normalizedVisible =
          visible.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return normalizedRequested.isNotEmpty &&
          (normalizedPackage.contains(normalizedRequested) ||
              normalizedVisible.contains(normalizedRequested));
    }

    // Search/find goals require meaningful query/result evidence on screen.
    final terms = goal
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\\s+'))
        .where((word) => word.length >= 4)
        .where((word) => !const {
              'search', 'google', 'open', 'first', 'link', 'result',
              'find', 'look', 'click', 'show', 'please', 'using', 'then',
            }.contains(word))
        .take(6)
        .toList();
    if (terms.isNotEmpty) {
      final matches = terms.where(visible.contains).length;
      if (matches >= (terms.length >= 3 ? 2 : 1)) return true;
    }

    // Generic completion still requires non-trivial observable screen state.
    return visible.trim().length >= 20;
  }

'''
    if helper not in source:
        if helper_anchor not in source:
            raise SystemExit('completion helper anchor not found')
        source = source.replace(helper_anchor, helper + helper_anchor, 1)

    old_done = '''        case 'done':
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
'''
    new_done = '''        case 'done':
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
'''
    if old_done in source:
        source = source.replace(old_done, new_done, 1)
    elif new_done not in source:
        raise SystemExit('done completion block not found')

    old_complete = '''      if (isComplete) {
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

        // Save to skill memory
        await _skillMemory.saveSkill(userGoal, executedSteps);

        await _screenService.showToast('Task Complete!');
        // Wait 4 seconds so the user can see the result before jumping back
        await Future.delayed(const Duration(milliseconds: 900));
        return reasoning.trim().isEmpty ? 'Done.' : reasoning.trim();
      }
'''
    new_complete = '''      if (isComplete) {
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
'''
    if old_complete in source:
        source = source.replace(old_complete, new_complete, 1)
    elif new_complete not in source:
        raise SystemExit('isComplete block not found')

    if source == original:
        print('No source changes required.')
        return
    TARGET.write_text(source)
    print('Applied task completion integrity guard.')


if __name__ == '__main__':
    main()
