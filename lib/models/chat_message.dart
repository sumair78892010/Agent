import 'package:flutter/foundation.dart';

import '../services/attachment_service.dart';

@immutable
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final AgentActionResult? actionResult;
  final String? imageUrl;
  final String status;
  final String? sourceMessageId;
  final List<AttachmentReference> attachments;
  final List<AttachmentDataSummary> dataSummaries;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.actionResult,
    this.imageUrl,
    this.status = 'complete',
    this.sourceMessageId,
    List<AttachmentReference>? attachments,
    List<AttachmentDataSummary>? dataSummaries,
  }) : id = id ?? _newId(),
       timestamp = timestamp ?? DateTime.now(),
       attachments = List.unmodifiable(attachments ?? const []),
       dataSummaries = List.unmodifiable(dataSummaries ?? const []);

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isComplete => status == 'complete';
  bool get isCancelled => status == 'cancelled';
  bool get isFailed => status == 'failed';
  bool get isStreaming => status == 'streaming';
  bool get isRetryable => isFailed || isCancelled;

  ChatMessage copyWith({
    String? content,
    DateTime? timestamp,
    AgentActionResult? actionResult,
    String? imageUrl,
    String? status,
    String? sourceMessageId,
    bool clearActionResult = false,
    bool clearImageUrl = false,
    bool clearSourceMessageId = false,
    List<AttachmentReference>? attachments,
    bool clearAttachments = false,
    List<AttachmentDataSummary>? dataSummaries,
    bool clearDataSummaries = false,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      actionResult: clearActionResult
          ? null
          : actionResult ?? this.actionResult,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      sourceMessageId: clearSourceMessageId
          ? null
          : sourceMessageId ?? this.sourceMessageId,
      attachments: clearAttachments
          ? const []
          : attachments ?? this.attachments,
      dataSummaries: clearDataSummaries
          ? const []
          : dataSummaries ?? this.dataSummaries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'actionResult': actionResult?.toJson(),
    'imageUrl': imageUrl,
    'status': status,
    'sourceMessageId': sourceMessageId,
    if (attachments.isNotEmpty)
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    if (dataSummaries.isNotEmpty)
      'dataSummaries': dataSummaries
          .map((summary) => summary.toJson())
          .toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString(),
    role: json['role']?.toString() ?? 'assistant',
    content: json['content']?.toString() ?? '',
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    actionResult: json['actionResult'] is Map
        ? AgentActionResult.fromJson(
            Map<String, dynamic>.from(json['actionResult'] as Map),
          )
        : null,
    imageUrl: json['imageUrl']?.toString(),
    status: _normalizeStatus(json['status']?.toString()),
    sourceMessageId: json['sourceMessageId']?.toString(),
    attachments: json['attachments'] is List
        ? (json['attachments'] as List)
              .whereType<Map>()
              .map(AttachmentReference.fromMap)
              .toList()
        : const [],
    dataSummaries: json['dataSummaries'] is List
        ? (json['dataSummaries'] as List)
              .whereType<Map>()
              .map(
                (item) => AttachmentDataSummary.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .take(5)
              .toList()
        : const [],
  );

  static String _normalizeStatus(String? value) {
    const allowed = {'streaming', 'complete', 'failed', 'cancelled'};
    return allowed.contains(value) ? value! : 'complete';
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  static int _idCounter = 0;
}

@immutable
class AgentActionResult {
  final String actionType;
  final bool success;
  final String? details;

  const AgentActionResult({
    required this.actionType,
    required this.success,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    'success': success,
    'details': details,
  };

  factory AgentActionResult.fromJson(Map<String, dynamic> json) =>
      AgentActionResult(
        actionType: json['actionType']?.toString() ?? 'unknown',
        success: json['success'] == true,
        details: json['details']?.toString(),
      );
}
