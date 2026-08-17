import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final settingsSource = File(
    'lib/screens/settings_screen.dart',
  ).readAsStringSync();
  final telemetrySource = File(
    'lib/services/task_telemetry_service.dart',
  ).readAsStringSync();
  final diagnosticsSource = File(
    'lib/services/diagnostics_service.dart',
  ).readAsStringSync();

  test('Developer Mode exposes Workspace Files and Artifacts', () {
    expect(settingsSource, contains('Workspace Files & Artifacts'));
    expect(settingsSource, contains('Impacted files'));
    expect(settingsSource, contains('Rollback checkpoints'));
    expect(settingsSource, contains('Expected result'));
    expect(settingsSource, contains('Selected tests'));
  });

  test('workspace artifacts reuse existing plan and checkpoint state', () {
    expect(settingsSource, contains('snapshot.upgradePlan'));
    expect(settingsSource, contains('snapshot.upgradeHistory'));
    expect(telemetrySource, contains('UpgradeExecutionPlan'));
    expect(telemetrySource, contains('UpgradeHistoryEntry'));
  });

  test('workspace artifacts remain sanitized in diagnostics export', () {
    expect(telemetrySource, contains('REDACTED_SECRET'));
    expect(diagnosticsSource, contains('workspace_commands'));
    expect(
      settingsSource,
      contains('no source is silently created or deleted'),
    );
  });
}
