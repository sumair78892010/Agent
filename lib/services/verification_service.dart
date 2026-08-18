import 'screen_automation_service.dart';
import 'app_launcher_service.dart';

/// Service to verify that actions actually completed successfully.
/// Verification is bounded and prefers observable state changes over generic
/// "no error" heuristics.
class VerificationService {
  final ScreenAutomationService _screen = ScreenAutomationService();
  final AppLauncherService _appLauncher = AppLauncherService();

  static const Duration _pollInterval = Duration(milliseconds: 120);
  static const Duration _appLaunchTimeout = Duration(seconds: 4);

  /// Verify that an app is actually in the foreground.
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

  Future<bool> verifyScreenAction(String action, String? expectedChange) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (expectedChange == null || expectedChange.trim().isEmpty) {
        return screenDesc.trim().isNotEmpty;
      }
      return screenDesc.toLowerCase().contains(expectedChange.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyTextTyped(String text, {String? fieldHint}) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      final normalized = text.trim();
      if (normalized.isEmpty) return false;
      return screenDesc.contains(normalized);
    } catch (_) {
      return false;
    }
  }

  /// Verify a click using a before/after screen snapshot when available.
  Future<bool> verifyElementClicked(
    String elementText, {
    String? beforeScreen,
  }) async {
    try {
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (elementText.trim().isEmpty) return true;

      if (beforeScreen != null && beforeScreen.trim().isNotEmpty) {
        if (beforeScreen.trim() != screenDesc.trim()) return true;
      }

      // A target disappearing is useful evidence that the click changed state.
      return !screenDesc.toLowerCase().contains(
        elementText.trim().toLowerCase(),
      );
    } catch (_) {
      return false;
    }
  }

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
}
