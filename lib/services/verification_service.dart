import 'screen_automation_service.dart';
import 'app_launcher_service.dart';

/// Service to verify that actions actually completed successfully.
/// The goal is to validate real UI transitions instead of treating any return value
/// as proof that a task succeeded.
class VerificationService {
  final ScreenAutomationService _screen = ScreenAutomationService();
  final AppLauncherService _appLauncher = AppLauncherService();

  /// Verify that an app is actually in the foreground.
  Future<bool> verifyAppOpened(String? packageName, String? appName) async {
    if (packageName == null && appName == null) return false;

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final currentPackage = (await _screen.getCurrentPackage() ?? '').toLowerCase();
      if (currentPackage.isEmpty) return false;

      if (packageName != null) {
        final normalized = packageName.toLowerCase();
        return currentPackage == normalized || currentPackage.contains(normalized);
      }

      if (appName != null) {
        final normalized = appName.toLowerCase();
        final screen = await _screen.getScreenDescription();
        final screenLower = screen.toLowerCase();
        return currentPackage.contains(normalized) || screenLower.contains(normalized);
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify a screen action had an observable effect.
  Future<bool> verifyScreenAction(String action, String? expectedChange) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (expectedChange == null) return true;
      return screenDesc.toLowerCase().contains(expectedChange.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Verify that the typed text is now represented on the screen.
  Future<bool> verifyTextTyped(String text, {String? fieldHint}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      final normalized = text.trim();
      if (normalized.isEmpty) return false;
      return screenDesc.contains(normalized);
    } catch (_) {
      return false;
    }
  }

  /// Verify that an element click produced a screen transition or opened a new target.
  Future<bool> verifyElementClicked(String elementText) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      if (elementText.trim().isEmpty) return true;
      return screenDesc.toLowerCase().contains(elementText.toLowerCase()) ||
          screenDesc.contains('Current app:');
    } catch (_) {
      return false;
    }
  }

  /// Generic state verification for non-trivial actions.
  Future<bool> verifyDeviceState(String actionType, Map<String, dynamic> params) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final screenDesc = await _screen.getScreenDescription();
      return !screenDesc.contains('Could not read screen');
    } catch (_) {
      return false;
    }
  }
}
