import 'package:flutter_test/flutter_test.dart';

import '../lib/services/diagnostics_service.dart';
import '../lib/services/task_telemetry_service.dart';

void main() {
  final telemetry = TaskTelemetryService.shared;

  test('records real workspace command metadata in bounded telemetry', () {
    telemetry.start(rootGoal: 'Controlled validation');
    telemetry.recordWorkspaceCommand(
      command: 'flutter test',
      workingDirectory: '/workspace/agent-cypher',
      exitCode: 0,
      elapsedMs: 123,
      output: '12 tests passed',
    );

    final entry = telemetry.developerState.value.workspaceCommands.single;
    expect(entry.command, 'flutter test');
    expect(entry.workingDirectory, '/workspace/agent-cypher');
    expect(entry.exitCode, 0);
    expect(entry.elapsedMs, 123);
    expect(entry.output, '12 tests passed');
    expect(entry.succeeded, isTrue);
  });

  test('workspace output is sanitized before display and export', () {
    telemetry.start(rootGoal: 'Safe diagnostics');
    telemetry.recordWorkspaceCommand(
      command: 'python3 worker.py --api_key=sk-command-secret',
      workingDirectory: '/workspace',
      exitCode: 1,
      elapsedMs: 9,
      output: 'Bearer private-token api_key=sk-output-secret',
    );

    final snapshot = telemetry.developerState.value;
    expect(snapshot.workspaceCommands.single.command, isNot(contains('sk-command-secret')));
    expect(snapshot.workspaceCommands.single.output, isNot(contains('private-token')));
    expect(snapshot.workspaceCommands.single.output, isNot(contains('sk-output-secret')));

    final report = DiagnosticsService.buildSanitizedDeveloperReport(
      snapshot: snapshot,
      system: const {},
    );
    expect(report, contains('workspace_commands'));
    expect(report, isNot(contains('private-token')));
    expect(report, isNot(contains('sk-output-secret')));
  });

  test('workspace command history remains bounded', () {
    telemetry.start(rootGoal: 'Bounded workspace history');
    for (var index = 0; index < 25; index++) {
      telemetry.recordWorkspaceCommand(
        command: 'command-$index',
        workingDirectory: '/workspace',
        exitCode: index == 24 ? 1 : 0,
        elapsedMs: index,
      );
    }

    final commands = telemetry.developerState.value.workspaceCommands;
    expect(commands.length, 20);
    expect(commands.first.command, 'command-5');
    expect(commands.last.command, 'command-24');
  });
}
