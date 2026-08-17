import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('required UI and native integration files remain present', () {
    expect(File('lib/screens/startup_screen.dart').existsSync(), isTrue);
    expect(File('lib/screens/onboarding_screen.dart').existsSync(), isTrue);
    expect(
      File('lib/widgets/unified_task_workspace.dart').existsSync(),
      isTrue,
    );
    expect(File('assets/app-logo.png').existsSync(), isTrue);

    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('AgentAccessibilityService'));
    expect(manifest, contains('BackgroundWakeWordService'));
    expect(manifest, contains('SYSTEM_ALERT_WINDOW'));
  });

  test('native bridges and secret-redaction hooks remain wired', () {
    final activity = read(
      'android/app/src/main/kotlin/com/cypherghost/agentcypher/MainActivity.kt',
    );
    final diagnostics = read('lib/services/diagnostics_service.dart');
    final artifacts = read('lib/services/artifact_service.dart');

    expect(activity, contains('shareText'));
    expect(activity, contains('getAccessibilityDiagnostics'));
    expect(diagnostics, contains('_sanitizeValue'));
    expect(artifacts, contains('sanitize'));
  });

  test('project source does not contain obvious credential literals', () {
    final files = <String>[
      'lib/services/voice_service.dart',
      'lib/services/diagnostics_service.dart',
      'lib/services/artifact_service.dart',
      'android/app/src/main/kotlin/com/cypherghost/agentcypher/MainActivity.kt',
    ];
    final credentialPattern = RegExp(
      r'(github_pat_[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|BEGIN (RSA|OPENSSH|PRIVATE) KEY)',
    );

    for (final path in files) {
      expect(credentialPattern.hasMatch(read(path)), isFalse, reason: path);
    }
  });
}
