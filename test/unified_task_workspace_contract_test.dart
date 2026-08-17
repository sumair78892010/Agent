import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../lib/services/attachment_service.dart';
import '../lib/services/diagnostics_service.dart';
import '../lib/services/task_telemetry_service.dart';

void main() {
  final telemetry = TaskTelemetryService.shared;

  test('unified workspace preserves root goal and real execution state', () {
    telemetry.start(rootGoal: 'Search for Shizuku');
    telemetry.stageStart('screen_observation');
    telemetry.recordScreenObservation(packageName: 'com.android.vending');
    telemetry.stageEnd('screen_observation');
    telemetry.recordPlannedAction(
      action: 'click_text',
      selectedTarget: 'Search',
      confidence: 0.91,
      subGoal: 'Locate Play Store search',
      expectedResult: 'Search UI is visible',
    );
    telemetry.recordVerification(
      diagnostic: 'Search UI is visible',
      progressed: true,
    );

    final snapshot = telemetry.developerState.value;
    expect(snapshot.rootGoal, 'Search for Shizuku');
    expect(snapshot.currentSubGoal, 'Locate Play Store search');
    expect(snapshot.plannedAction, 'click_text');
    expect(snapshot.selectedTarget, 'Search');
    expect(snapshot.confidence, 0.91);
    expect(snapshot.verificationPassed, isTrue);
    expect(snapshot.currentAppPackage, 'com.android.vending');
    expect(snapshot.events, isNotEmpty);
  });

  test('attachment handoff exposes metadata but never raw path or content', () {
    telemetry.recordAttachments([
      AttachmentReference(
        id: '1',
        name: 'report.csv',
        path: '/private/secret/report.csv',
        mimeType: 'text/csv',
        size: 42,
        selectedAt: DateTime(2026, 1, 1),
      ),
    ]);

    final snapshot = telemetry.developerState.value;
    expect(snapshot.attachments.single.name, 'report.csv');
    expect(snapshot.attachments.single.mimeType, 'text/csv');
    expect(snapshot.attachments.single.size, 42);
    expect(snapshot.attachments.single.summary, isNot(contains('/private')));

    final report = DiagnosticsService.buildSanitizedDeveloperReport(
      snapshot: snapshot,
      system: const {},
    );
    final decoded = jsonDecode(report) as Map<String, dynamic>;
    final agent = decoded['agent'] as Map<String, dynamic>;
    expect(agent['attachments'], isA<List<dynamic>>());
    expect(report, isNot(contains('/private/secret')));
  });

  test(
    'workspace reports validation, commands, artifacts, and rollback state',
    () {
      telemetry.start(rootGoal: 'Controlled upgrade');
      telemetry.recordWorkspaceCommand(
        command: 'flutter test',
        workingDirectory: '/workspace',
        exitCode: 0,
        elapsedMs: 12,
        output: 'passed',
      );
      telemetry.recordUpgradeState(
        stage: 'validated',
        files: const ['lib/widgets/unified_task_workspace.dart'],
        evidence: 'Focused tests passed.',
        finalResult: 'Change kept.',
        canApply: false,
      );

      final snapshot = telemetry.developerState.value;
      expect(snapshot.workspaceCommands.single.succeeded, isTrue);
      expect(snapshot.upgradeStage, 'validated');
      expect(snapshot.upgradeFiles, contains('unified_task_workspace.dart'));
      expect(snapshot.upgradeEvidence, contains('passed'));
    },
  );
}
