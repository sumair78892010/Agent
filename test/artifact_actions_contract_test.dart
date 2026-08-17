import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/services/artifact_service.dart';

void main() {
  test('artifact metadata excludes storage paths and content', () {
    final record = ArtifactRecord(
      id: 'artifact-1',
      name: 'report.md',
      kind: 'markdown',
      size: 24,
      createdAt: DateTime.utc(2026, 8, 16),
      sourceTask: 'Summarize the report',
      validationState: 'passed',
      content: 'private content',
      storagePath: '/private/app/artifacts/report.md',
    );

    final json = record.toJson();

    expect(json['name'], 'report.md');
    expect(json['validation_state'], 'passed');
    expect(json.containsKey('content'), isFalse);
    expect(json.containsKey('storage_path'), isFalse);
    expect(json.toString(), isNot(contains('/private/app')));
  });

  test(
    'artifact sanitization redacts keys, bearer values, and provider tokens',
    () {
      final sanitized = ArtifactService.sanitize(
        'api_key=sk-live-secret Bearer abc-token '
        'password: hunter2 nvapi-very-secret',
      );

      expect(sanitized, contains('[REDACTED_SECRET]'));
      expect(sanitized, isNot(contains('sk-live-secret')));
      expect(sanitized, isNot(contains('abc-token')));
      expect(sanitized, isNot(contains('hunter2')));
      expect(sanitized, isNot(contains('nvapi-very-secret')));
    },
  );

  test(
    'artifact records restore bounded metadata and preview remains bounded',
    () {
      final restored = ArtifactRecord.fromJson({
        'id': 'artifact-2',
        'name': 'large.txt',
        'kind': 'text',
        'size': 999,
        'created_at': '2026-08-16T00:00:00.000Z',
        'source_task': 'bounded task',
        'validation_state': 'not_validated',
      }).copyWith(content: 'a' * (ArtifactService.maxPreviewCharacters + 100));

      expect(restored.name, 'large.txt');
      expect(
        restored.preview.length,
        lessThanOrEqualTo(ArtifactService.maxPreviewCharacters + 12),
      );
      expect(restored.preview, endsWith('[TRUNCATED]'));
    },
  );

  test(
    'workspace source exposes copy, share, and generated artifact actions',
    () {
      final source = File(
        'lib/widgets/unified_task_workspace.dart',
      ).readAsStringSync();

      expect(source, contains('Generated artifacts'));
      expect(source, contains("label: const Text('Copy')"));
      expect(source, contains("label: const Text('Share')"));
      expect(source, contains('ArtifactService.shared.copy'));
    },
  );
}
