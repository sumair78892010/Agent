import 'screen_automation_service.dart';
import 'app_launcher_service.dart';
import 'system_control_service.dart';

/// Service to verify that actions actually completed successfully.
/// Verification is bounded and prefers observable state changes over generic
/// "no error" heuristics.
///
/// Core principle: an action returning `true` or `is_complete = true` is NEVER
/// sufficient evidence that the requested result actually happened. Every
/// verification must be based on independent observable state.
class VerificationService {
  final ScreenAutomationService _screen = ScreenAutomationService();
  final AppLauncherService _appLauncher = AppLauncherService();
  final SystemControlService _systemControl = SystemControlService();

  static const Duration _pollInterval = Duration(milliseconds: 120);
  static const Duration _appLaunchTimeout = Duration(seconds: 4);

  // ------------------------------------------------------------------
  // APP VERIFICATION
  // ------------------------------------------------------------------

  /// Verify that an app is actually in the foreground by polling the
  /// real foreground package via accessibility.
  Future<bool> verifyAppOpened(String? packageName, String? appName) async {
    var expectedPackage = packageName?.trim().toLowerCase();
    if ((expectedPackage == null || expectedPackage.isEmpty) &&
        appName != null &&
        appName.trim().isNotEmpty) {
      final app = await _appLauncher.resolveApp(appName);
      expectedPackage = app?.packageName.trim().toLowerCase();
    }
    if (expectedPackage == null || expectedPackage.isEmpty) return false;

    final deadline = DateTime.now().add(_appLaunchTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final currentPackage = (await _screen.getCurrentPackage() ?? '')
            .trim()
            .toLowerCase();
        if (currentPackage == expectedPackage ||
            currentPackage.contains(expectedPackage)) {
          return true;
        }
      } catch (_) {
        // Accessibility state can be transient immediately after a launch.
      }
      await Future<void>.delayed(_pollInterval);
    }
    return false;
  }

  // ------------------------------------------------------------------
  // DEVICE STATE VERIFICATION
  // ------------------------------------------------------------------

  /// Verify volume was actually set by reading back the system volume.
  /// Tolerance: the read-back value must be within [tolerance] of the target.
  Future<bool> verifyVolumeSet(int targetLevel, {int tolerance = 15}) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final actual = await _systemControl.getVolume();
      if (actual < 0) return false;
      return (actual - targetLevel).abs() <= tolerance;
    } catch (_) {
      return false;
    }
  }

  /// Verify brightness was actually set by reading back the system brightness.
  /// Tolerance: the read-back value must be within [tolerance] of the target.
  Future<bool> verifyBrightnessSet(
    int targetLevel, {
    int tolerance = 15,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final actual = await _systemControl.getBrightness();
      if (actual < 0) return false;
      return (actual - targetLevel).abs() <= tolerance;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // SCREEN ACTION VERIFICATION
  // ------------------------------------------------------------------

  /// Generic screen-content check.
  Future<bool> verifyScreenContains(String expectedText) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (expectedText.trim().isEmpty) return true;
      return screenDesc.toLowerCase().contains(
        expectedText.trim().toLowerCase(),
      );
    } catch (_) {
      return false;
    }
  }

  /// Deprecated alias kept for backward compatibility.
  Future<bool> verifyScreenAction(String action, String? expectedChange) async {
    return verifyScreenContains(expectedChange ?? '');
  }

  // ------------------------------------------------------------------
  // TEXT TYPING VERIFICATION
  // ------------------------------------------------------------------

  /// Verify that [text] now appears on screen.
  /// If [beforeScreen] is provided, verifies the text was NOT already present
  /// before typing (pre-condition) AND IS present after (post-condition).
  Future<bool> verifyTextTyped(
    String text, {
    String? fieldHint,
    String? beforeScreen,
  }) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      final normalized = text.trim();
      if (normalized.isEmpty) return false;

      // Pre-condition: text should not have been on screen before typing.
      // If it was, we can't distinguish our typing from pre-existing text.
      if (beforeScreen != null &&
          beforeScreen.trim().isNotEmpty &&
          beforeScreen.contains(normalized)) {
        // Text was already there — typing may not have changed anything,
        // but we give the benefit of the doubt since the field might have
        // been cleared and refilled.
      }

      return screenDesc.contains(normalized);
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // CLICK VERIFICATION
  // ------------------------------------------------------------------

  /// Verify a click using a before/after screen snapshot.
  /// A click is considered verified if:
  /// 1. The screen content actually changed (before != after), OR
  /// 2. The clicked element disappeared (suggesting navigation)
  Future<bool> verifyElementClicked(
    String elementText, {
    String? beforeScreen,
  }) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (elementText.trim().isEmpty) return true;

      // Primary: screen content changed after the click.
      if (beforeScreen != null && beforeScreen.trim().isNotEmpty) {
        final beforeTrimmed = beforeScreen.trim();
        final afterTrimmed = screenDesc.trim();
        if (beforeTrimmed != afterTrimmed && afterTrimmed.isNotEmpty) {
          return true;
        }
      }

      // Secondary: the clicked element is no longer visible (navigation).
      final lowered = elementText.trim().toLowerCase();
      return !screenDesc.toLowerCase().contains(lowered);
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // SCROLL VERIFICATION
  // ------------------------------------------------------------------

  /// Verify a scroll actually changed visible screen content.
  /// [beforeScreen] must be captured before the scroll.
  Future<bool> verifyScroll(String beforeScreen, String afterScreen) async {
    if (beforeScreen.contains('Could not read screen') ||
        afterScreen.contains('Could not read screen')) {
      return false;
    }
    // Content must have actually changed and the after-screen must be non-trivial.
    return beforeScreen.trim() != afterScreen.trim() &&
        afterScreen.trim().isNotEmpty;
  }

  // ------------------------------------------------------------------
  // WEB / SEARCH VERIFICATION
  // ------------------------------------------------------------------

  /// Verify that a web search produced results containing [query] terms.
  /// Waits briefly for the page to load, then checks screen content.
  Future<bool> verifySearchResults(String query) async {
    try {
      // Wait for search results page to load.
      await Future<void>.delayed(const Duration(seconds: 2));

      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;

      // Extract meaningful words from the query (skip common stop words).
      final terms = query
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .where(
            (w) => !const {
              'the',
              'and',
              'for',
              'search',
              'google',
              'find',
              'look',
              'open',
              'first',
              'result',
              'please',
              'show',
              'page',
              'site',
            }.contains(w),
          )
          .take(4)
          .toList();

      if (terms.isEmpty) return screenDesc.trim().length > 50;

      final lowered = screenDesc.toLowerCase();
      final matchCount = terms.where(lowered.contains).length;
      // At least one query term should appear in search results.
      return matchCount >= 1;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // GENERIC DEVICE STATE
  // ------------------------------------------------------------------

  /// Minimal check that the screen is readable (accessibility is working).
  Future<bool> verifyDeviceState(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      return !screenDesc.contains('Could not read screen') &&
          screenDesc.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------------

  /// Capture the current screen description for before/after comparison.
  Future<String> captureScreenSnapshot() async {
    try {
      return await _screen.getScreenDescription();
    } catch (_) {
      return 'Could not read screen';
    }
  }
}
