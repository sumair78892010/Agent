import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// A user-selected document or media attachment copied into app-scoped cache.
///
/// The attachment reference is safe to persist in conversation metadata. Raw
/// content is read only when a request explicitly asks the AI to inspect it.
class AttachmentReference {
  final String id;
  final String name;
  final String path;
  final String mimeType;
  final int size;
  final DateTime selectedAt;

  const AttachmentReference({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.size,
    required this.selectedAt,
  });

  factory AttachmentReference.fromMap(Map<dynamic, dynamic> map) {
    return AttachmentReference(
      id: map['id']?.toString() ?? _fallbackId(map['name']?.toString()),
      name: map['name']?.toString() ?? 'attachment',
      path: map['path']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
      size: int.tryParse(map['size']?.toString() ?? '') ?? 0,
      selectedAt:
          DateTime.tryParse(map['selectedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'mimeType': mimeType,
    'size': size,
    'selectedAt': selectedAt.toIso8601String(),
  };

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isTextLike => _textExtensions.contains(extension);

  bool get isImage => mimeType.startsWith('image/');

  static String _fallbackId(String? name) =>
      '${DateTime.now().microsecondsSinceEpoch}-${name ?? 'file'}';

  static const _textExtensions = {
    'csv',
    'css',
    'dart',
    'go',
    'html',
    'js',
    'json',
    'log',
    'md',
    'py',
    'sql',
    'toml',
    'ts',
    'txt',
    'xml',
    'yaml',
    'yml',
  };
}

class AttachmentInspection {
  final AttachmentReference attachment;
  final String summary;
  final String? textPreview;
  final bool truncated;
  final AttachmentDataSummary? dataSummary;

  const AttachmentInspection({
    required this.attachment,
    required this.summary,
    this.textPreview,
    this.truncated = false,
    this.dataSummary,
  });

  Map<String, dynamic> toJson() => {
    'attachment': attachment.toJson(),
    'summary': summary,
    'textPreview': textPreview,
    'truncated': truncated,
    'dataSummary': dataSummary?.toJson(),
  };
}

class AttachmentDataSummary {
  final String format;
  final int rowCount;
  final int columnCount;
  final List<String> columns;
  final Map<String, NumericSummary> numericColumns;

  const AttachmentDataSummary({
    required this.format,
    required this.rowCount,
    required this.columnCount,
    required this.columns,
    required this.numericColumns,
  });

  Map<String, dynamic> toJson() => {
    'format': format,
    'rowCount': rowCount,
    'columnCount': columnCount,
    'columns': columns,
    'numericColumns': numericColumns.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };

  factory AttachmentDataSummary.fromJson(Map<String, dynamic> json) {
    final numeric = json['numericColumns'];
    return AttachmentDataSummary(
      format: json['format']?.toString() ?? 'DATA',
      rowCount: int.tryParse(json['rowCount']?.toString() ?? '') ?? 0,
      columnCount: int.tryParse(json['columnCount']?.toString() ?? '') ?? 0,
      columns: json['columns'] is List
          ? (json['columns'] as List)
                .map((value) => value.toString())
                .take(50)
                .toList()
          : const [],
      numericColumns: numeric is Map
          ? {
              for (final entry in numeric.entries)
                entry.key.toString(): NumericSummary.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                ),
            }
          : const {},
    );
  }

  String get promptDescription {
    final numeric = numericColumns.entries
        .map((entry) => '${entry.key}: ${entry.value.promptDescription}')
        .join('; ');
    return '$format dataset with $rowCount rows and $columnCount columns'
        '${columns.isEmpty ? '' : ' (${columns.join(', ')})'}'
        '${numeric.isEmpty ? '' : '. Numeric summaries: $numeric'}.';
  }
}

class NumericSummary {
  final int count;
  final double minimum;
  final double maximum;
  final double average;

  const NumericSummary({
    required this.count,
    required this.minimum,
    required this.maximum,
    required this.average,
  });

  Map<String, dynamic> toJson() => {
    'count': count,
    'minimum': minimum,
    'maximum': maximum,
    'average': average,
  };

  factory NumericSummary.fromJson(Map<String, dynamic> json) => NumericSummary(
    count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
    minimum: double.tryParse(json['minimum']?.toString() ?? '') ?? 0,
    maximum: double.tryParse(json['maximum']?.toString() ?? '') ?? 0,
    average: double.tryParse(json['average']?.toString() ?? '') ?? 0,
  );

  String get promptDescription =>
      'count=$count, min=${_format(minimum)}, max=${_format(maximum)}, '
      'average=${_format(average)}';

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3);
}

/// Attachment picker and bounded document-inspection service.
///
/// The Android picker copies selected content into an app-scoped cache path.
/// This service never uploads or persists raw content by itself.
class AttachmentService {
  static const MethodChannel _channel = MethodChannel(
    'com.cypherghost.agentcypher/files',
  );

  static const int maxAttachments = 5;
  static const int maxPreviewBytes = 128 * 1024;

  Future<List<AttachmentReference>> pickDocuments() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('pickDocuments');
    if (raw == null) return const [];

    return raw
        .whereType<Map>()
        .take(maxAttachments)
        .map(AttachmentReference.fromMap)
        .where((attachment) => attachment.path.isNotEmpty)
        .toList(growable: false);
  }

  Future<AttachmentInspection> inspect(AttachmentReference attachment) async {
    if (!attachment.isTextLike) {
      final kind = attachment.isImage ? 'image' : 'binary document';
      return AttachmentInspection(
        attachment: attachment,
        summary:
            '${attachment.name} is an $kind and needs a compatible '
            'vision or document extractor before its contents can be read.',
      );
    }

    try {
      final file = File(attachment.path);
      if (!await file.exists()) {
        return AttachmentInspection(
          attachment: attachment,
          summary: 'The selected file is no longer available in app cache.',
        );
      }

      final bytes = await file
          .openRead(0, maxPreviewBytes)
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
      final truncated = bytes.length >= maxPreviewBytes;
      final content = _redactSecrets(utf8.decode(bytes, allowMalformed: true));
      final dataSummary = _analyzeStructured(attachment, content);
      return AttachmentInspection(
        attachment: attachment,
        summary: dataSummary == null
            ? 'Text preview extracted from ${attachment.name}.'
            : 'Text preview extracted from ${attachment.name}. ${dataSummary.promptDescription}',
        textPreview: content,
        truncated: truncated,
        dataSummary: dataSummary,
      );
    } catch (_) {
      return AttachmentInspection(
        attachment: attachment,
        summary: 'The selected file could not be read safely.',
      );
    }
  }

  Future<String> buildPromptContext(
    List<AttachmentReference> attachments, {
    int maxTotalCharacters = 24000,
  }) async {
    if (attachments.isEmpty) return '';

    final sections = <String>[];
    var remaining = maxTotalCharacters;
    for (final attachment in attachments.take(maxAttachments)) {
      if (remaining <= 0) break;
      final inspection = await inspect(attachment);
      final preview = inspection.textPreview;
      final body = preview == null
          ? inspection.summary
          : '${inspection.summary}\n$preview';
      final section = '--- Attachment: ${attachment.name} ---\n$body';
      final bounded = section.length > remaining
          ? section.substring(0, remaining)
          : section;
      sections.add(bounded);
      remaining -= bounded.length;
    }

    return sections.join('\n\n');
  }

  static AttachmentDataSummary? _analyzeStructured(
    AttachmentReference attachment,
    String content,
  ) {
    try {
      if (attachment.extension == 'json') {
        final decoded = jsonDecode(content);
        final rows = decoded is List
            ? decoded.whereType<Map>().toList()
            : decoded is Map
            ? [decoded]
            : const <Map>[];
        if (rows.isEmpty) return null;
        final columns = rows
            .expand((row) => row.keys.map((key) => key.toString()))
            .toSet()
            .take(50)
            .toList();
        return AttachmentDataSummary(
          format: 'JSON',
          rowCount: rows.length,
          columnCount: columns.length,
          columns: columns,
          numericColumns: _numericSummaries(rows, columns),
        );
      }
      if (attachment.extension == 'csv') {
        final lines = content
            .split(RegExp(r'\r?\n'))
            .where((line) => line.trim().isNotEmpty)
            .take(1001)
            .toList();
        if (lines.length < 2) return null;
        final columns = _splitCsvLine(lines.first);
        final rows = lines.skip(1).map(_splitCsvLine).toList();
        final maps = rows
            .map(
              (row) => <String, dynamic>{
                for (var i = 0; i < columns.length && i < row.length; i++)
                  columns[i]: row[i],
              },
            )
            .toList();
        return AttachmentDataSummary(
          format: 'CSV',
          rowCount: rows.length,
          columnCount: columns.length,
          columns: columns.take(50).toList(),
          numericColumns: _numericSummaries(maps, columns),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final character = line[i];
      if (character == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    values.add(buffer.toString().trim());
    return values;
  }

  static Map<String, NumericSummary> _numericSummaries(
    List<Map> rows,
    List<String> columns,
  ) {
    final summaries = <String, NumericSummary>{};
    for (final column in columns.take(50)) {
      final values = rows
          .map((row) => double.tryParse(row[column]?.toString().trim() ?? ''))
          .whereType<double>()
          .take(1000)
          .toList();
      if (values.isEmpty) continue;
      final total = values.fold<double>(0, (sum, value) => sum + value);
      summaries[column] = NumericSummary(
        count: values.length,
        minimum: values.reduce((a, b) => a < b ? a : b),
        maximum: values.reduce((a, b) => a > b ? a : b),
        average: total / values.length,
      );
    }
    return summaries;
  }

  static String _redactSecrets(String input) {
    var output = input;
    output = output.replaceAllMapped(
      RegExp(
        r'(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}: [REDACTED]',
    );
    output = output.replaceAll(
      RegExp(r'bearer\s+[a-z0-9._~+/=-]{16,}', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    return output;
  }
}
