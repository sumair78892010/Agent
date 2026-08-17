import 'screen_automation_service.dart';
import 'app_launcher_service.dart';

/// Service to verify that actions actually completed successfully.
/// Verification is bounded and prefers the Android foreground package over
/// fragile text-only heuristics.
class VerificationService {
  final ScreenAutomationService _screen = ScreenAutomationService();
  final AppLauncherService _appLauncher = AppLauncherService();

  /// Verify that an app is actually in the foreground.
  Future<bool> verifyAppOpened(String? packageName, String? appName) async {
    if (packageName == null && appName == null) return false;

    try {
      final normalizedPackage = packageName?.trim().toLowerCase();
      final normalizedApp = appName?.trim().toLowerCase() ?? '';
      final packageHint = normalizedApp.replaceAll(RegExp(r'[^a-z0-9]'), '');

      // App launches can take a little time on a cold start. Poll briefly rather
      // than sleeping for a fixed 800ms, so fast devices return immediately.
      for (var attempt = 0; attempt < 8; attempt++) {
        final currentPackage =
            (await _screen.getCurrentPackage() ?? '').trim().toLowerCase();
        if (currentPackage.isNotEmpty) {
          if (normalizedPackage != null &&
              (currentPackage == normalizedPackage ||
                  currentPackage.contains(normalizedPackage))) {
            return true;
          }

          if (normalizedApp.isNotEmpty) {
            final compactPackage = currentPackage.replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
            if (compactPackage.contains(packageHint)) return true;

            // Fall back to visible app text only when package matching is
            // inconclusive. This is slower, so it is not the first check.
            final screen = await _screen.getScreenDescription();
            final screenLower = screen.toLowerCase();
            if (screenLower.contains(normalizedApp)) return true;
          }
        }

        if (attempt < 7) {
          await Future.delayed(
            Duration(milliseconds: attempt == 0 ? 120 : 180),
          );
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify a screen action had an observable effect.
  Future<bool> verifyScreenAction(String action, String? expectedChange) async {
    try {
      await Future.delayed(const Duration(milliseconds: 180));
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
      await Future.delayed(const Duration(milliseconds: 180));
      final screenDesc = await _screen.getScreenDescription();
      if (screenDesc.contains('Could not read screen')) return false;
      final normalized = text.trim();
      if (normalized.isEmpty) return false;
      return screenDesc.contains(normalized);
    } catch (_) {
      return false;
    }
  }

  /// Verify that a click did not simply disappear into the accessibility layer.
  /// A readable screen is necessary; when the clicked label is still present,
  /// that is acceptable because some controls update state without navigation.
  Future<bool> verifyElementClicked(String elementText) async {
    try {
      await Future.delayed(const Duration(milliseconds: 180));
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
  Future<bool> verifyDeviceState(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    try {
      await Future.delayed(const Duration(milliseconds: 180));
      final screenDesc = await _screen.getScreenDescription();
      return !screenDesc.contains('Could not read screen');
    } catch (_) {
      return false;
    }
  }
}
