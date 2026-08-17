import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen_automation_service.dart';

/// Centralized permission status handling
/// Per spec section 26: Permission center with status and remediation
class PermissionService {
  static const String _permissionsPrefsKey = 'permissions_state';

  /// Check if microphone permission is granted
  Future<PermissionStatus> checkMicrophone() async {
    return await Permission.microphone.status;
  }

  /// Check if notification permission is granted
  Future<PermissionStatus> checkNotification() async {
    return await Permission.notification.status;
  }

  /// Check if system overlay (for floating bubble) is granted
  Future<bool> checkOverlay() async {
    // On Android 6+, this is SYSTEM_ALERT_WINDOW permission
    // We need to check in settings
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Check if accessibility service is enabled and responding.
  Future<bool> checkAccessibility() async {
    try {
      final screenService = ScreenAutomationService();
      if (!await screenService.waitUntilReady()) return false;
      return await screenService.isServiceRunning();
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if screen capture permission is granted
  Future<PermissionStatus> checkScreenCapture() async {
    // Android doesn't have a specific runtime permission for screen capture
    // It's usually granted automatically
    return PermissionStatus.granted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request notification permission
  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request system overlay permission
  Future<bool> requestOverlay() async {
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  /// Get permission explanation before requesting
  String getPermissionExplanation(String permissionType) {
    switch (permissionType) {
      case 'microphone':
        return 'Microphone access is needed for voice commands. The agent uses this to listen for wake words and voice input.';
      case 'notification':
        return 'Notification access allows the agent to read and display system notifications.';
      case 'overlay':
        return 'Overlay permission is needed to display the floating Cypher bubble on your screen.';
      case 'accessibility':
        return 'Accessibility service is needed to interact with apps on your screen. This allows the agent to tap, type, and read UI elements.';
      case 'screen_capture':
        return 'Screen capture permission allows the agent to take screenshots of your device for better context.';
      case 'shizuku':
        return 'Shizuku allows advanced device control operations that require system-level access.';
      default:
        return 'This permission is required for the agent to function properly.';
    }
  }

  /// Get all permission status
  Future<Map<String, PermissionStatusInfo>> getAllPermissionsStatus() async {
    return {
      'microphone': PermissionStatusInfo(
        name: 'Microphone',
        status: await checkMicrophone(),
        required: true,
      ),
      'notification': PermissionStatusInfo(
        name: 'Notifications',
        status: await checkNotification(),
        required: true,
      ),
      'overlay': PermissionStatusInfo(
        name: 'Display Overlay (Floating Bubble)',
        status: await checkOverlay()
            ? PermissionStatus.granted
            : PermissionStatus.denied,
        required: false,
      ),
      'accessibility': PermissionStatusInfo(
        name: 'Accessibility Service',
        status: await checkAccessibility()
            ? PermissionStatus.granted
            : PermissionStatus.denied,
        required: true,
      ),
      'screen_capture': PermissionStatusInfo(
        name: 'Screen Capture',
        status: await checkScreenCapture(),
        required: false,
      ),
    };
  }

  /// Get human-readable permission status
  String getStatusString(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✓ Granted';
      case PermissionStatus.denied:
        return '✗ Denied';
      case PermissionStatus.permanentlyDenied:
        return '⚠ Permanently Denied (must enable in settings)';
      case PermissionStatus.restricted:
        return '⚠ Restricted';
      case PermissionStatus.limited:
        return '⚠ Limited';
      default:
        return 'Unknown';
    }
  }

  /// Check if all critical permissions are granted
  Future<bool> allCriticalPermissionsGranted() async {
    final statuses = await getAllPermissionsStatus();
    for (final entry in statuses.entries) {
      if (entry.value.required &&
          entry.value.status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}

/// Permission status information with explanation
class PermissionStatusInfo {
  final String name;
  final PermissionStatus status;
  final bool required;

  PermissionStatusInfo({
    required this.name,
    required this.status,
    required this.required,
  });

  String get statusText {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  String get statusIcon {
    switch (status) {
      case PermissionStatus.granted:
        return '✓';
      case PermissionStatus.denied:
        return '✗';
      case PermissionStatus.permanentlyDenied:
        return '⚠';
      case PermissionStatus.restricted:
        return '⚠';
      case PermissionStatus.limited:
        return '⚠';
      default:
        return '?';
    }
  }
}
