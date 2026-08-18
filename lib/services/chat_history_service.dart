import 'dart:developer' as developer;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<Map<String, dynamic>> messages;
  final bool memoryEnabled;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
    this.memoryEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'timestamp': timestamp.toIso8601String(),
    'messages': messages,
    'memoryEnabled': memoryEnabled,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    timestamp:
        DateTime.tryParse('${json['timestamp'] ?? ''}') ?? DateTime.now(),
    messages: (json['messages'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
    memoryEnabled: json['memoryEnabled'] != false,
  );
}

class ChatHistoryService {
  static List<ChatSession> _lastLoadedSessions = <ChatSession>[];
  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/chat_history_sessions.json');
  }

  static Future<Directory> get _overlayHandoffDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/overlay_chat_handoff');
  }

  static Future<void> appendOverlayMessage(Map<String, dynamic> message) async {
    try {
      final directory = await _overlayHandoffDirectory;
      await directory.create(recursive: true);
      final eventId = DateTime.now().microsecondsSinceEpoch;
      final temporary = File('${directory.path}/$eventId.tmp');
      final event = File('${directory.path}/$eventId.json');
      await temporary.writeAsString(jsonEncode(message), flush: true);
      await temporary.rename(event.path);
    } catch (e) {
      developer.log('Error appending overlay chat message: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> consumeOverlayMessages() async {
    try {
      final directory = await _overlayHandoffDirectory;
      if (!await directory.exists()) return [];

      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));

      final messages = <Map<String, dynamic>>[];
      for (final file in files) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          messages.add(Map<String, dynamic>.from(decoded as Map));
          await file.delete();
        } catch (_) {
          // Leave an incomplete event for the next foreground sync pass.
        }
      }
      return messages;
    } catch (e) {
      developer.log('Error consuming overlay chat messages: $e');
      return [];
    }
  }

  /// Saves a session. Overwrites if ID already exists.
  static Future<void> saveSession(ChatSession session) async {
    try {
      final file = await _localFile;
      List<ChatSession> sessions = await loadSessions();

      final index = sessions.indexWhere((s) => s.id == session.id);
      if (index >= 0) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session); // Newest first
      }

      final jsonList = sessions.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      developer.log('Error saving chat session: $e');
    }
  }

  /// Loads all saved chat sessions.
  static Future<List<ChatSession>> loadSessions() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content) as List;
      final sessions = decoded
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
      _lastLoadedSessions = sessions;
      return sessions;
    } catch (e) {
      developer.log('Error loading chat sessions: $e');
      return [];
    }
  }

  /// Deletes a specific session.
  static Future<void> deleteSession(String id) async {
    try {
      final file = await _localFile;
      List<ChatSession> sessions = await loadSessions();
      sessions.removeWhere((s) => s.id == id);

      final jsonList = sessions.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      developer.log('Error deleting chat session: $e');
    }
  }

  static Future<ChatSession?> loadSession(String id) async {
    final sessions = await loadSessions();
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  static ChatSession newSession({
    String? id,
    String title = 'New conversation',
    bool memoryEnabled = true,
  }) {
    final session = ChatSession(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      timestamp: DateTime.now(),
      messages: <Map<String, dynamic>>[],
      memoryEnabled: memoryEnabled,
    );
    unawaited(saveSession(session));
    return session;
  }

  static String generateTitle(List<Map<String, dynamic>> messages) {
    final firstUser = messages.cast<Map<String, dynamic>?>().firstWhere(
      (message) =>
          message?['role'] == 'user' &&
          '${message?['content'] ?? ''}'.trim().isNotEmpty,
      orElse: () => null,
    );
    final content = '${firstUser?['content'] ?? ''}'
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (content.isEmpty) return 'New conversation';
    final words = content.split(' ');
    final title = words.take(7).join(' ');
    return title.length > 60 ? '${title.substring(0, 60).trim()}…' : title;
  }

  static Future<void> renameSession(String id, String title) async {
    final session = await loadSession(id);
    if (session == null) return;
    await saveSession(
      ChatSession(
        id: session.id,
        title: title.trim().isEmpty ? 'New conversation' : title.trim(),
        timestamp: DateTime.now(),
        messages: session.messages,
        memoryEnabled: session.memoryEnabled,
      ),
    );
  }

  static Future<bool> updateMessages(
    String id,
    List<Map<String, dynamic>> messages, {
    bool? memoryEnabled,
  }) async {
    final session = await loadSession(id);
    if (session == null) return false;
    await saveSession(
      ChatSession(
        id: session.id,
        title: session.title,
        timestamp: DateTime.now(),
        messages: List<Map<String, dynamic>>.from(messages),
        memoryEnabled: memoryEnabled ?? session.memoryEnabled,
      ),
    );
    return true;
  }

  static List<ChatSession> filterSessions(
    Object sessionsOrQuery, [
    String? query,
  ]) {
    final sessions = sessionsOrQuery is List<ChatSession>
        ? sessionsOrQuery
        : _lastLoadedSessions;
    final normalized = (query ?? sessionsOrQuery.toString())
        .trim()
        .toLowerCase();
    if (normalized.isEmpty) return sessions;
    return sessions.where((session) {
      if (session.title.toLowerCase().contains(normalized)) return true;
      return session.messages.any(
        (message) =>
            '${message['content'] ?? ''}'.toLowerCase().contains(normalized),
      );
    }).toList();
  }

  static List<Map<String, dynamic>> sanitizeMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final sanitizedMessages = <Map<String, dynamic>>[];
    for (final message in messages) {
      final sanitized = Map<String, dynamic>.from(message);
      final status = sanitized['status'];
      final content = sanitized['content'];
      if (status == 'streaming' && content is String && content.isEmpty) {
        continue;
      }
      if (status == 'streaming' && content is String && content.isNotEmpty) {
        sanitized['status'] = 'failed';
      }
      if (content is String && content.length > 20000) {
        sanitized['content'] = '${content.substring(0, 20000)}…';
      }
      sanitized.remove('apiKey');
      sanitized.remove('token');
      sanitized.remove('authorization');
      sanitizedMessages.add(sanitized);
    }
    return sanitizedMessages;
  }

  /// Clears all saved chat sessions.
  static Future<void> clearAll() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      developer.log('Error clearing chat history: $e');
    }
  }
}
