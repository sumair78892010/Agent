import 'package:flutter/material.dart';
import '../services/chat_history_service.dart';
import '../screens/settings_screen.dart';
import '../screens/task_history_screen.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../services/shizuku_service.dart';
import '../services/screen_automation_service.dart';

class ChatHistoryDrawer extends StatefulWidget {
  final String sessionId;
  final bool memoryEnabledForConversation;
  final bool automaticMemoryEnabled;
  final String historyQuery;
  final VoidCallback onNewChat;
  final ValueChanged<bool> onMemoryChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ChatSession> onLoadSession;
  final Future<void> Function(ChatSession) onRenameSession;
  final Future<void> Function(ChatSession) onDeleteSession;
  final AiService aiService;
  final ShizukuService shizukuService;
  final ScreenAutomationService screenAutomationService;
  final VoiceService voiceService;

  const ChatHistoryDrawer({
    super.key,
    required this.sessionId,
    required this.memoryEnabledForConversation,
    required this.automaticMemoryEnabled,
    required this.historyQuery,
    required this.onNewChat,
    required this.onMemoryChanged,
    required this.onQueryChanged,
    required this.onLoadSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.aiService,
    required this.shizukuService,
    required this.screenAutomationService,
    required this.voiceService,
  });

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final textStyle = TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
    );
    final headerStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF1E293B),
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    );

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 20,
              left: 24,
              right: 24,
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app-logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Agent Cypher', style: headerStyle),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNewChat();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_comment_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 20),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(
              widget.memoryEnabledForConversation
                  ? Icons.psychology_alt_rounded
                  : Icons.psychology_alt_outlined,
              size: 20,
            ),
            title: const Text('Memory for this conversation'),
            subtitle: Text(
              widget.memoryEnabledForConversation
                  ? 'Use approved saved memories when relevant'
                  : 'Do not use saved memories in this chat',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Switch.adaptive(
              value: widget.memoryEnabledForConversation,
              onChanged: widget.automaticMemoryEnabled
                  ? (v) => widget.onMemoryChanged(v)
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CHAT HISTORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  'LOCAL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: widget.onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: widget.historyQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 17),
                        onPressed: () => widget.onQueryChanged(''),
                      ),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF151D30) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatSession>>(
              future: ChatHistoryService.loadSessions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent chats',
                      style: TextStyle(
                        color: isDark ? Colors.grey[800] : Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                final sessions = ChatHistoryService.filterSessions(
                  snapshot.data!,
                  widget.historyQuery,
                );
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isCurrent = session.id == widget.sessionId;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent
                            ? Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                              )
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        dense: true,
                        leading: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.grey[600] : Colors.grey[500]),
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrent
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B))
                                : null,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          onSelected: (value) async {
                            if (value == 'rename') {
                              await widget.onRenameSession(session);
                            }
                            if (value == 'delete') {
                              await widget.onDeleteSession(session);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onLoadSession(session);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 20),
          ListTile(
            horizontalTitleGap: 8,
            leading: Icon(
              Icons.history_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            title: Text('Task History', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
              );
            },
          ),
          ListTile(
            horizontalTitleGap: 8,
            leading: Icon(
              Icons.settings_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            title: Text('Settings', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    aiService: widget.aiService,
                    shizukuService: widget.shizukuService,
                    screenAutomationService: widget.screenAutomationService,
                    voiceService: widget.voiceService,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
