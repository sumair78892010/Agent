import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_cypher/models/chat_message.dart';
import 'package:agent_cypher/services/ai_service.dart';
import 'package:agent_cypher/services/chat_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );

  test(
    'chat messages preserve action and image metadata across serialization',
    () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'Done',
        timestamp: DateTime.utc(2026, 8, 15, 12, 30),
        imageUrl: 'data:image/png;base64,redacted',
        actionResult: AgentActionResult(
          actionType: 'set_volume',
          success: true,
          details: 'Volume set',
        ),
      );

      final restored = ChatMessage.fromJson(original.toJson());

      expect(restored.role, 'assistant');
      expect(restored.content, 'Done');
      expect(restored.imageUrl, 'data:image/png;base64,redacted');
      expect(restored.actionResult?.actionType, 'set_volume');
      expect(restored.actionResult?.success, isTrue);
      expect(restored.actionResult?.details, 'Volume set');
    },
  );

  test('conversation search matches title and message content', () {
    final sessions = [
      ChatSession(
        id: 'one',
        title: 'YouTube research',
        timestamp: DateTime.utc(2026, 8, 15),
        messages: [
          {'role': 'user', 'content': 'Find a tutorial'},
        ],
      ),
      ChatSession(
        id: 'two',
        title: 'Volume control',
        timestamp: DateTime.utc(2026, 8, 14),
        messages: [
          {'role': 'user', 'content': 'Set the phone volume to 50'},
        ],
      ),
    ];

    expect(
      ChatHistoryService.filterSessions(sessions, 'youtube').map((s) => s.id),
      ['one'],
    );
    expect(
      ChatHistoryService.filterSessions(
        sessions,
        'phone volume',
      ).map((s) => s.id),
      ['two'],
    );
    expect(ChatHistoryService.filterSessions(sessions, '  ').map((s) => s.id), [
      'one',
      'two',
    ]);
  });

  test('attachment metadata is optional for legacy chat messages', () {
    final legacy = ChatMessage.fromJson({
      'role': 'user',
      'content': 'Legacy message',
    });
    expect(legacy.attachments, isEmpty);
  });

  test('stream cancellation has an explicit typed signal', () {
    expect(const StreamCancelledException().toString(), contains('cancelled'));
  });

  test('streaming status transitions persist through copyWith', () {
    final streaming = ChatMessage(
      role: 'assistant',
      content: 'partial',
      status: 'streaming',
    );
    final complete = streaming.copyWith(status: 'complete');
    final cancelled = streaming.copyWith(
      status: 'cancelled',
      content: 'Generation stopped.',
    );
    final failed = streaming.copyWith(
      status: 'failed',
      content: 'Error: timeout',
    );

    expect(complete.isComplete, isTrue);
    expect(complete.isRetryable, isFalse);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.isRetryable, isTrue);
    expect(failed.isFailed, isTrue);
    expect(failed.isRetryable, isTrue);
    expect(ChatMessage.fromJson(cancelled.toJson()).status, 'cancelled');
  });

  test(
    'interrupted empty streams are removed and partial streams become failed',
    () {
      final sanitized = ChatHistoryService.sanitizeMessages([
        ChatMessage(
          role: 'assistant',
          content: '',
          status: 'streaming',
        ).toJson(),
        ChatMessage(
          role: 'assistant',
          content: 'partial response',
          status: 'streaming',
        ).toJson(),
        ChatMessage(
          role: 'assistant',
          content: 'Generation stopped.',
          status: 'cancelled',
        ).toJson(),
      ]);

      expect(sanitized, hasLength(2));
      expect(sanitized.first['status'], 'failed');
      expect(sanitized.last['status'], 'cancelled');
    },
  );

  test('new sessions receive distinct IDs and generated titles are stable', () {
    final first = ChatHistoryService.newSession();
    final second = ChatHistoryService.newSession();
    expect(first.id, isNot(second.id));
    expect(
      ChatHistoryService.generateTitle([
        {'role': 'user', 'content': '  Search for cats  '},
      ]),
      'Search for cats',
    );
  });

  test('message updates preserve per-conversation memory settings', () async {
    const id = 'conversation-memory-contract';
    await ChatHistoryService.saveSession(
      ChatSession(
        id: id,
        title: 'Private chat',
        timestamp: DateTime.now(),
        messages: const [],
        memoryEnabled: false,
      ),
    );

    final updated = await ChatHistoryService.updateMessages(id, [
      ChatMessage(role: 'user', content: 'Do not save this').toJson(),
    ]);

    expect(updated, isTrue);
    expect((await ChatHistoryService.loadSession(id))?.memoryEnabled, isFalse);
    await ChatHistoryService.deleteSession(id);
  });

  test('deleting a persisted conversation removes its stored record', () async {
    final session = ChatSession(
      id: 'conversation-delete-contract',
      title: 'Delete me',
      timestamp: DateTime.now(),
      messages: [ChatMessage(role: 'user', content: 'temporary').toJson()],
    );
    await ChatHistoryService.saveSession(session);
    expect(
      (await ChatHistoryService.loadSessions()).any(
        (item) => item.id == session.id,
      ),
      isTrue,
    );

    await ChatHistoryService.deleteSession(session.id);

    expect(
      (await ChatHistoryService.loadSessions()).any(
        (item) => item.id == session.id,
      ),
      isFalse,
    );
  });
}
