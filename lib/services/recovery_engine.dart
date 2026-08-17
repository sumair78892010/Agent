class RecoveryAction {
  final String action;
  final Map<String, dynamic> params;
  final String description;
  final int priority; // 0=highest priority (try first), 10=lowest

  RecoveryAction({
    required this.action,
    required this.params,
    required this.description,
    this.priority = 5,
  });
}

class RecoveryEngine {
  /// Track failed attempts to avoid repeating the same failure
  final Map<String, int> _failureAttempts = {};
  static const int MAX_SAME_FAILURE_ATTEMPTS = 2;

  /// Diagnoses the failure and suggests recovery actions based on actual device state
  /// Returns a prioritized list of recovery strategies to try
  Future<List<RecoveryAction>> diagnoseWithAlternatives(
    String lastFailedAction,
    String screenContent, {
    String? lastAttemptedValue,
  }) async {
    final lowerScreen = screenContent.toLowerCase();
    final actions = <RecoveryAction>[];

    // Track this failure to prevent infinite loops
    final failureKey = '$lastFailedAction:$lastAttemptedValue';
    _failureAttempts[failureKey] = (_failureAttempts[failureKey] ?? 0) + 1;

    // If we've already tried this exact action/value combo multiple times, skip it
    if ((_failureAttempts[failureKey] ?? 0) > MAX_SAME_FAILURE_ATTEMPTS) {
      actions.add(RecoveryAction(
        action: 'give_up',
        params: {},
        description: 'Action "$lastFailedAction" with value "$lastAttemptedValue" failed too many times. Giving up.',
        priority: 0, // Highest priority - don't retry endlessly
      ));
      return actions;
    }

    // 1. LOADING STATE: App is loading - wait for content
    if (lowerScreen.contains('loading') ||
        lowerScreen.contains('progress') ||
        lowerScreen.contains('spinner') ||
        lowerScreen.contains('wait') ||
        lowerScreen.contains('buffering')) {
      actions.add(RecoveryAction(
        action: 'wait',
        params: {'milliseconds': 2000},
        description: 'App is loading or buffering. Waiting for content to load...',
        priority: 0,
      ));
      return actions;
    }

    if (lowerScreen.contains('captcha') ||
        lowerScreen.contains('verify you are human') ||
        lowerScreen.contains('challenge')) {
      actions.add(RecoveryAction(
        action: 'wait_for_user',
        params: {'reason': 'Human verification required'},
        description: 'A CAPTCHA or human verification step is blocking browser automation.',
        priority: 0,
      ));
      return actions;
    }

    // 2. KEYBOARD BLOCKING: Dismiss keyboard that may be covering UI
    if (lowerScreen.contains('keyboard') ||
        lowerScreen.contains('gboard') ||
        lowerScreen.contains('input method')) {
      actions.add(RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'Keyboard is blocking UI. Attempting to dismiss it.',
        priority: 1,
      ));
      actions.add(RecoveryAction(
        action: 'scroll',
        params: {'direction': 'up', 'amount': 3},
        description: 'Alternative: Scroll up to reveal elements above keyboard.',
        priority: 2,
      ));
      return actions;
    }

    // 3. ERROR DIALOG: Handle error dialogs
    if (lowerScreen.contains('error') ||
        lowerScreen.contains('failed') ||
        lowerScreen.contains('something went wrong') ||
        lowerScreen.contains('oops')) {
      actions.add(RecoveryAction(
        action: 'click_text',
        params: {'text': 'OK', 'fuzzyMatch': true},
        description: 'Error dialog detected. Attempting to dismiss with OK button.',
        priority: 1,
      ));
      actions.add(RecoveryAction(
        action: 'click_text',
        params: {'text': 'Retry', 'fuzzyMatch': true},
        description: 'Alternative: Try Retry button if available.',
        priority: 2,
      ));
      actions.add(RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'Fallback: Press back to dismiss error.',
        priority: 3,
      ));
      return actions;
    }

    // 4. CLICK ACTION FAILED
    if (lastFailedAction == 'click_text' || lastFailedAction == 'click_at') {
      // Element might not be visible/clickable - try to scroll to it
      if (lowerScreen.contains('scroll')) {
        actions.add(RecoveryAction(
          action: 'scroll',
          params: {'direction': 'down', 'amount': 3},
          description: 'Element not found. Scrolling down to look for it.',
          priority: 1,
        ));
        actions.add(RecoveryAction(
          action: 'scroll',
          params: {'direction': 'up', 'amount': 3},
          description: 'Alternative: Try scrolling up.',
          priority: 2,
        ));
      }

      // Maybe need to switch to coordinate-based clicking if text matching failed
      actions.add(RecoveryAction(
        action: 'read_screen',
        params: {},
        description: 'Re-read screen to get updated element coordinates.',
        priority: 3,
      ));

      // Last resort: go back and retry
      actions.add(RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'Element not found/clickable. Going back to retry.',
        priority: 4,
      ));
      return actions;
    }

    // 5. TYPE TEXT FAILED
    if (lastFailedAction == 'type_text') {
      // Try clicking the field first if not focused
      actions.add(RecoveryAction(
        action: 'wait',
        params: {'milliseconds': 500},
        description: 'Waiting for input field to become active.',
        priority: 1,
      ));
      actions.add(RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'Dismiss any popups that might be covering the field.',
        priority: 2,
      ));
      actions.add(RecoveryAction(
        action: 'scroll',
        params: {'direction': 'down', 'amount': 2},
        description: 'Scroll to ensure input field is visible.',
        priority: 3,
      ));
      return actions;
    }

    // 6. OPEN APP FAILED
    if (lastFailedAction == 'open_app') {
      actions.add(RecoveryAction(
        action: 'wait',
        params: {'milliseconds': 3000},
        description: 'App may be loading. Waiting longer before next attempt.',
        priority: 1,
      ));
      actions.add(RecoveryAction(
        action: 'press_home',
        params: {},
        description: 'App failed to open. Going home and will retry.',
        priority: 2,
      ));
      return actions;
    }

    // 7. SCROLL FAILED
    if (lastFailedAction == 'scroll') {
      actions.add(RecoveryAction(
        action: 'wait',
        params: {'milliseconds': 500},
        description: 'Animation delay. Waiting before retry.',
        priority: 1,
      ));
      actions.add(RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'View may not be scrollable. Going back.',
        priority: 2,
      ));
      return actions;
    }

    // DEFAULT: Generic recovery strategy
    actions.add(RecoveryAction(
      action: 'wait',
      params: {'milliseconds': 1000},
      description: 'Waiting briefly for screen to settle.',
      priority: 1,
    ));
    actions.add(RecoveryAction(
      action: 'read_screen',
      params: {},
      description: 'Re-reading screen to assess current state.',
      priority: 2,
    ));
    actions.add(RecoveryAction(
      action: 'press_back',
      params: {},
      description: 'Fallback: Going back to previous screen.',
      priority: 3,
    ));

    return actions;
  }

  /// Legacy single-action diagnosis for backward compatibility
  Future<RecoveryAction> diagnose(
    String lastFailedAction,
    String screenContent,
  ) async {
    final actions = await diagnoseWithAlternatives(
      lastFailedAction,
      screenContent,
    );
    return actions.isNotEmpty
        ? actions.first
        : RecoveryAction(
            action: 'wait',
            params: {},
            description: 'Unknown error, waiting to retry.',
          );
  }

  /// Clear failure tracking (call when an action succeeds)
  void resetFailureTracking() {
    _failureAttempts.clear();
  }

  /// Get current failure statistics for diagnostics
  Map<String, int> getFailureStats() => Map.from(_failureAttempts);
}
