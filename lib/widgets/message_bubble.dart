import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'data_summary_card.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<ChatMessage>? onEdit;
  final ValueChanged<ChatMessage>? onRegenerate;
  final ValueChanged<ChatMessage>? onRetry;
  final ValueChanged<ChatMessage>? onContinue;
  final ValueChanged<String>? onShare;

  const MessageBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onRegenerate,
    this.onRetry,
    this.onContinue,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 8,
          right: isUser ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.08),
                  width: 1.2,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.02,
              ),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.12),
                    ),
                    child: Image.asset(
                      'assets/app-logo.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Cypher logo',
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Cypher',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Action result badge
            if (message.actionResult != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: message.actionResult!.success
                      ? Colors.green.withOpacity(0.12)
                      : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: message.actionResult!.success
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.actionResult!.success
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 14,
                      color: message.actionResult!.success
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.actionResult!.actionType.toUpperCase().replaceAll(
                        '_',
                        ' ',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: message.actionResult!.success
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Message text
            if (isUser)
              SelectableText(
                message.content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              )
            else
              MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        height: 1.45,
                      ),
                      listBullet: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
              ),
            if (message.dataSummaries.isNotEmpty)
              ...message.dataSummaries.map(
                (summary) => DataSummaryCard(summary: summary),
              ),
            if (onEdit != null ||
                onRegenerate != null ||
                onRetry != null ||
                onContinue != null ||
                onShare != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  if (onEdit != null)
                    _MessageAction(
                      icon: Icons.edit_outlined,
                      onPressed: () => onEdit!(message),
                    ),
                  if (onRegenerate != null)
                    _MessageAction(
                      icon: Icons.refresh_rounded,
                      onPressed: () => onRegenerate!(message),
                    ),
                  if (onRetry != null)
                    _MessageAction(
                      icon: Icons.replay_rounded,
                      onPressed: () => onRetry!(message),
                    ),
                  if (onContinue != null)
                    _MessageAction(
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => onContinue!(message),
                    ),
                  if (onShare != null)
                    _MessageAction(
                      icon: Icons.share_outlined,
                      onPressed: () => onShare!(message.content),
                    ),
                ],
              ),
            ],
            // Timestamp
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isUser
                    ? Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.6)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MessageAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MessageAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onPressed,
      tooltip: 'Message action',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}
