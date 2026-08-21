import 'package:flutter/material.dart';
import '../services/attachment_service.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController textController;
  final bool isDark;
  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final List<AttachmentReference> selectedAttachments;
  final VoidCallback? onSend;
  final ValueChanged<String>? onSendText;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onStopSpeaking;
  final VoidCallback? onPickFiles;
  final ValueChanged<String>? onRemoveAttachment;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.isDark,
    required this.isLoading,
    required this.isListening,
    required this.isSpeaking,
    required this.selectedAttachments,
    this.onSend,
    this.onSendText,
    this.onToggleVoice,
    this.onStopSpeaking,
    this.onPickFiles,
    this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: selectedAttachments
                        .map(
                          (attachment) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 150,
                                ),
                                child: Text(
                                  attachment.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onDeleted: isLoading
                                  ? null
                                  : onRemoveAttachment != null
                                      ? () => onRemoveAttachment!(attachment.id)
                                      : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? Colors.redAccent
                      : isSpeaking
                      ? Colors.indigoAccent
                      : Theme.of(context).cardTheme.color,
                  border: Border.all(
                    color: isListening
                        ? Colors.redAccent
                        : isSpeaking
                        ? Colors.indigoAccent
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    if (isListening)
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    if (isSpeaking)
                      BoxShadow(
                        color: Colors.indigoAccent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: IconButton(
                  tooltip: isSpeaking
                      ? 'Interrupt spoken response'
                      : isListening
                      ? 'Stop listening'
                      : 'Activate microphone',
                  icon: Icon(
                    isSpeaking
                        ? Icons.volume_off_rounded
                        : isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    color: isListening || isSpeaking
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: isLoading
                      ? null
                      : (isSpeaking
                          ? onStopSpeaking
                          : onToggleVoice),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 52,
                    maxHeight: 150,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        icon: Icon(
                          Icons.attach_file_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: isLoading ? null : onPickFiles,
                      ),
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: const TextStyle(fontSize: 14),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: isListening
                                ? 'Listening...'
                                : 'Message Agent Cypher...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: isLoading
                              ? null
                              : onSendText,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: isLoading
                              ? null
                              : onSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
