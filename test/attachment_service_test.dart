import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/chat_message.dart';
import '../lib/services/attachment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cypherghost.agentcypher/files');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pickDocuments maps native metadata and limits selections', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pickDocuments');
          return List.generate(
            7,
            (index) => {
              'id': 'id-$index',
              'name': 'file-$index.txt',
              'path': '/cache/file-$index.txt',
              'mimeType': 'text/plain',
              'size': 12,
              'selectedAt': '2026-08-16T00:00:00.000Z',
            },
          );
        });

    final attachments = await AttachmentService().pickDocuments();

    expect(attachments, hasLength(5));
    expect(attachments.first.name, 'file-0.txt');
    expect(attachments.first.mimeType, 'text/plain');
  });

  test(
    'text inspection redacts common secrets and builds bounded context',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/cypher-attachment-test.txt',
      );
      await file.writeAsString(
        'normal note\napi_key=super-secret-value\nAuthorization: Bearer abcdefghijklmnop',
      );
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final attachment = AttachmentReference(
        id: 'safe-id',
        name: 'notes.txt',
        path: file.path,
        mimeType: 'text/plain',
        size: await file.length(),
        selectedAt: DateTime.utc(2026, 8, 16),
      );
      final service = AttachmentService();

      final inspection = await service.inspect(attachment);
      final context = await service.buildPromptContext([attachment]);

      expect(inspection.textPreview, contains('[REDACTED]'));
      expect(inspection.textPreview, isNot(contains('super-secret-value')));
      expect(context, contains('notes.txt'));
      expect(context, isNot(contains('abcdefghijklmnop')));
    },
  );

  test('CSV inspection returns bounded structure and numeric summaries', () async {
    final file = File('${Directory.systemTemp.path}/cypher-data-test.csv');
    await file.writeAsString('name,amount\nA,10\nB,20\nC,30\n');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final attachment = AttachmentReference(
      id: 'csv-1',
      name: 'data.csv',
      path: file.path,
      mimeType: 'text/csv',
      size: await file.length(),
      selectedAt: DateTime.utc(2026, 8, 16),
    );
    final inspection = await AttachmentService().inspect(attachment);

    expect(inspection.dataSummary?.format, 'CSV');
    expect(inspection.dataSummary?.rowCount, 3);
    expect(inspection.dataSummary?.columns, containsAll(['name', 'amount']));
    expect(inspection.dataSummary?.numericColumns['amount']?.average, 20);
    expect(inspection.summary, contains('3 rows'));
  });

  test('JSON inspection summarizes object collections without exposing secrets', () async {
    final file = File('${Directory.systemTemp.path}/cypher-data-test.json');
    await file.writeAsString('[{"label":"A","score":2},{"label":"B","score":4}]');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final attachment = AttachmentReference(
      id: 'json-1',
      name: 'data.json',
      path: file.path,
      mimeType: 'application/json',
      size: await file.length(),
      selectedAt: DateTime.utc(2026, 8, 16),
    );
    final inspection = await AttachmentService().inspect(attachment);

    expect(inspection.dataSummary?.format, 'JSON');
    expect(inspection.dataSummary?.rowCount, 2);
    expect(inspection.dataSummary?.numericColumns['score']?.maximum, 4);
  });

  test('ChatMessage preserves attachment metadata across JSON round trips', () {
    final message = ChatMessage(
      role: 'user',
      content: 'Review this file',
      attachments: [
        AttachmentReference(
          id: 'attachment-1',
          name: 'report.txt',
          path: '/cache/report.txt',
          mimeType: 'text/plain',
          size: 42,
          selectedAt: DateTime.utc(2026, 8, 16),
        ),
      ],
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.attachments, hasLength(1));
    expect(restored.attachments.single.name, 'report.txt');
    expect(restored.attachments.single.path, '/cache/report.txt');
  });
}
