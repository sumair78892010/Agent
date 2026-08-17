import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Safe, app-scoped artifact management for generated task outputs.
///
/// Artifacts are bounded, sanitized before persistence, and expose metadata
/// rather than raw filesystem paths through their public serialization.
class ArtifactService {
  static const int maxArtifactBytes = 256 * 1024;
  static const int maxPreviewCharacters = 4 * 1024;
  static const MethodChannel _shareChannel = MethodChannel(
    'com.cypherghost.agentcypher/accessibility',
  );

  static final ArtifactService shared = ArtifactService._();

  ArtifactService._();

  final ValueNotifier<List<ArtifactRecord>> artifacts =
      ValueNotifier<List<ArtifactRecord>>(const []);
  Directory? _artifactDirectory;

  Future<void> init() async {
    if (_artifactDirectory != null) return;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/artifacts');
    await directory.create(recursive: true);
    _artifactDirectory = directory;
    await _loadRecords();
  }

  Future<ArtifactRecord?> exportText({
    required String name,
    required String content,
    String kind = 'text',
    String sourceTask = '',
    String validationState = 'not_validated',
  }) async {
    await init();
    final safeName = _safeName(name);
    final sanitized = sanitize(content);
    final bounded = _boundedUtf8(sanitized);
    final id = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final extension = _extension(kind, safeName);
    final base = '${_artifactDirectory!.path}/$id';
    final contentFile = File('$base$extension');
    final metadataFile = File('$base.json');
    await contentFile.writeAsString(bounded, flush: true);
    final record = ArtifactRecord(
      id: id,
      name: safeName,
      kind: kind,
      size: utf8.encode(bounded).length,
      createdAt: DateTime.now().toUtc(),
      sourceTask: _boundedText(sanitize(sourceTask), 240),
      validationState: _boundedText(sanitize(validationState), 80),
      content: bounded,
      storagePath: contentFile.path,
    );
    await metadataFile.writeAsString(jsonEncode(record.toJson()), flush: true);
    _publish([record, ...artifacts.value].take(40).toList(growable: false));
    return record;
  }

  Future<String> preview(ArtifactRecord record) async {
    if (record.content.isNotEmpty) {
      return _boundedText(record.content, maxPreviewCharacters);
    }
    try {
      final content = await File(record.storagePath).readAsString();
      return _boundedText(sanitize(content), maxPreviewCharacters);
    } catch (_) {
      return '';
    }
  }

  Future<bool> copy(ArtifactRecord record) async {
    final content = await preview(record);
    if (content.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: content));
    return true;
  }

  Future<bool> share(ArtifactRecord record) async {
    final content = await preview(record);
    if (content.isEmpty) return false;
    try {
      final result = await _shareChannel.invokeMethod<bool>('shareText', {
        'text': content,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static String sanitize(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b(?:sk-|nvapi-|github_pat_)[A-Za-z0-9_-]+',
            caseSensitive: false,
          ),
          '[REDACTED_SECRET]',
        )
        .replaceAll(
          RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
          'Bearer [REDACTED_SECRET]',
        )
        .replaceAllMapped(
          RegExp(
            r'(api[_-]?key|password|secret|token)\s*[:=]\s*[^\s,;]+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}=[REDACTED_SECRET]',
        );
  }

  Future<void> _loadRecords() async {
    final loaded = <ArtifactRecord>[];
    try {
      await for (final entity in _artifactDirectory!.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map) continue;
        final record = ArtifactRecord.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        final contentPath = entity.path.substring(0, entity.path.length - 5);
        final content = await File(contentPath).readAsString();
        loaded.add(
          record.copyWith(
            content: _boundedUtf8(sanitize(content)),
            storagePath: contentPath,
          ),
        );
      }
    } catch (_) {
      // A corrupt artifact must not prevent the app from starting.
    }
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _publish(loaded.take(40).toList(growable: false));
  }

  void _publish(List<ArtifactRecord> value) {
    artifacts.value = List<ArtifactRecord>.unmodifiable(value);
  }

  static String _boundedUtf8(String value) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxArtifactBytes) return value;
    return utf8.decode(
      bytes.take(maxArtifactBytes).toList(),
      allowMalformed: true,
    );
  }

  static String _boundedText(String value, int maxCharacters) {
    if (value.length <= maxCharacters) return value;
    return '${value.substring(0, maxCharacters)}\n[TRUNCATED]';
  }

  static String _safeName(String value) {
    final trimmed = value.trim().isEmpty ? 'artifact' : value.trim();
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  static String _extension(String kind, String name) {
    if (name.contains('.')) return '.${name.split('.').last}';
    switch (kind.toLowerCase()) {
      case 'json':
        return '.json';
      case 'markdown':
      case 'md':
        return '.md';
      case 'csv':
        return '.csv';
      default:
        return '.txt';
    }
  }
}

class ArtifactRecord {
  final String id;
  final String name;
  final String kind;
  final int size;
  final DateTime createdAt;
  final String sourceTask;
  final String validationState;
  final String content;
  final String storagePath;

  const ArtifactRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.createdAt,
    required this.sourceTask,
    required this.validationState,
    this.content = '',
    this.storagePath = '',
  });

  String get preview => ArtifactService._boundedText(
    content,
    ArtifactService.maxPreviewCharacters,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'size': size,
    'created_at': createdAt.toIso8601String(),
    'source_task': sourceTask,
    'validation_state': validationState,
  };

  factory ArtifactRecord.fromJson(Map<String, dynamic> json) {
    return ArtifactRecord(
      id: (json['id'] as String?) ?? 'artifact',
      name: (json['name'] as String?) ?? 'artifact',
      kind: (json['kind'] as String?) ?? 'text',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceTask: (json['source_task'] as String?) ?? '',
      validationState: (json['validation_state'] as String?) ?? 'unknown',
    );
  }

  ArtifactRecord copyWith({String? content, String? storagePath}) {
    return ArtifactRecord(
      id: id,
      name: name,
      kind: kind,
      size: size,
      createdAt: createdAt,
      sourceTask: sourceTask,
      validationState: validationState,
      content: content ?? this.content,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}
