import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/attachment_service.dart';
import '../services/ai_service.dart';
import '../services/action_handler.dart';
import '../services/voice_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/background_glows.dart';
import '../widgets/mode_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_progress_panel.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_history_drawer.dart';
import '../services/chat_history_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/user_memory_service.dart';
import '../services/task_telemetry_service.dart';
import '../services/research_report_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../config/feature_flags.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();
  final ActionHandler _actionHandler = ActionHandler();
  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();
  final UserMemoryService _userMemoryService = UserMemoryService();
  final SettingsService _settingsService = SettingsService();
  final AttachmentService _attachmentService = AttachmentService();
  final ResearchReportService _researchReportService = ResearchReportService();
  StreamSubscription<VoiceEvent>? _voiceEvents;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isVoiceProcessing = false;
  bool _lastRequestFromVoice = false;
  bool _wakeWordAvailable = false;
  bool _wakeWordEnabled = false;
  // ignore: unused_field — written by wake-word event handler; UI binding pending
  bool _wakeWordListening = false;
  bool _microphonePermissionGranted = false;
  bool _speechRecognitionAvailable = false;
  bool _ttsAvailable = false;
  // ignore: unused_field — written by voice init and wake-word handler; UI binding pending
  String _voiceStatus = 'Checking voice capabilities...';
  // ignore: unused_field — written by speech recognition callback; UI binding pending
  String _partialTranscript = '';
  bool _streamCancellationRequested = false;
  bool _automaticMemoryEnabled = true;
  bool _memoryEnabledForConversation = true;
  String _historyQuery = '';
  List<AttachmentReference> _selectedAttachments = const [];

  // Custom switch state: 'chat' or 'agent'
  String _mode = 'chat';

  // Chat Session state tracking
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  String _sessionTitle = '';
  int _conversationRevision = 0;
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.cypherghost.agentcypher/accessibility',
  );

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Timer? _overlayHistoryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _startOverlayHistorySync();
    // Register as the handler for overlay bubble tasks
    onOverlayTask = (task) => _sendMessage(task);
  }

  Future<void> _initServices() async {
    _voiceEvents ??= _voiceService.eventStream.listen(_handleVoiceEvent);
    try {
      await _aiService.init();
      _automaticMemoryEnabled = await _userMemoryService
          .getAutomaticMemoryEnabled();
      await _notificationService.requestPermission();
      await _voiceService.init();
      await _settingsService.init();
      _wakeWordEnabled = _settingsService.isWakeWordEnabled();
      final microphoneStatus = await _permissionService.checkMicrophone();
      _microphonePermissionGranted =
          microphoneStatus == PermissionStatus.granted;
      _speechRecognitionAvailable = _voiceService.speechRecognitionAvailable;
      _ttsAvailable = _voiceService.ttsAvailable;
      _wakeWordAvailable = _voiceService.wakeWordAvailable;
      _wakeWordListening = _voiceService.wakeWordListening;
      if (_wakeWordEnabled && _microphonePermissionGranted) {
        unawaited(_voiceService.startWakeWordMode());
      }
      if (mounted) {
        setState(() {
          _voiceStatus = _voiceReadinessSummary;
        });
      }
      await _actionHandler.shizuku.checkAvailability();
    } catch (error, stackTrace) {
      developer.log(
        'Optional home services failed to initialize: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  String get _voiceReadinessSummary {
    if (_speechRecognitionAvailable && _ttsAvailable) {
      return 'Listening and spoken responses are ready.';
    }
    if (!_speechRecognitionAvailable && !_ttsAvailable) {
      return 'Microphone recognition and TTS are unavailable.';
    }
    if (!_speechRecognitionAvailable) {
      return 'Spoken responses are ready; speech recognition is unavailable.';
    }
    return 'Speech recognition is ready; spoken responses are unavailable.';
  }

  void _handleVoiceEvent(VoiceEvent event) {
    if (!mounted) return;
    setState(() {
      if (event.speechRecognitionAvailable != null) {
        _speechRecognitionAvailable = event.speechRecognitionAvailable!;
      }
      if (event.ttsAvailable != null) {
        _ttsAvailable = event.ttsAvailable!;
      }
      if (event.wakeWordAvailable != null) {
        _wakeWordAvailable = event.wakeWordAvailable!;
      }
      if (event.wakeWordEnabled != null) {
        _wakeWordEnabled = event.wakeWordEnabled!;
      }
      if (event.wakeWordListening != null) {
        _wakeWordListening = event.wakeWordListening!;
      }
      switch (event.type) {
        case 'listening_started':
          _isListening = true;
          _voiceStatus = 'Listening for a command...';
          break;
        case 'partial_result':
          _partialTranscript = event.content ?? '';
          _voiceStatus = 'Listening...';
          break;
        case 'recognized':
          _isListening = false;
          _partialTranscript = event.content ?? '';
          _voiceStatus = 'Command recognized. Processing...';
          break;
        case 'speaking_started':
          _isSpeaking = true;
          _voiceStatus = 'Speaking response...';
          break;
        case 'speaking_completed':
        case 'speaking_stopped':
          _isSpeaking = false;
          _voiceStatus = _voiceReadinessSummary;
          break;
        case 'listening_stopped':
          _isListening = false;
          _voiceStatus = _voiceReadinessSummary;
          break;
        case 'recognition_unavailable':
          _speechRecognitionAvailable = false;
          _isListening = false;
          _voiceStatus = 'Speech recognition is unavailable.';
          break;
        case 'tts_unavailable':
          _ttsAvailable = false;
          _isSpeaking = false;
          _voiceStatus = 'Text-to-speech is unavailable.';
          break;
        case 'error':
          _isListening = false;
          _isSpeaking = false;
          _voiceStatus = event.message;
          break;
        case 'wake_word_ready':
        case 'wake_word_status':
          _voiceStatus = _wakeWordAvailable
              ? 'Hey Cypher background trigger is ready.'
              : 'Hey Cypher background trigger is unavailable.';
          break;
        case 'wake_word_listening':
          _wakeWordListening = true;
          _voiceStatus = 'Listening locally for Hey Cypher...';
          break;
        case 'wake_word_detected':
          _wakeWordListening = false;
          _voiceStatus = 'Hey Cypher detected. Listening for your command...';
          break;
        case 'wake_word_unavailable':
          _wakeWordAvailable = false;
          _wakeWordListening = false;
          _voiceStatus = event.message;
          break;
        case 'wake_word_stopped':
          _wakeWordListening = false;
          _voiceStatus = _voiceReadinessSummary;
          break;
        case 'wake_word_error':
          _wakeWordListening = false;
          _voiceStatus = event.message;
          break;
        case 'initialized':
          _voiceStatus = _voiceReadinessSummary;
          break;
      }
    });
    _publishVoiceOrbState(event);
    if (event.type == 'wake_word_detected') {
      final command = event.content?.trim() ?? '';
      if (command.isNotEmpty) {
        _dispatchVoiceCommand(command);
      } else {
        unawaited(_startWakeCommandListening());
      }
    }
  }

  void _dispatchVoiceCommand(String text) {
    if (!mounted || text.trim().isEmpty || _isVoiceProcessing) return;
    _lastRequestFromVoice = true;
    setState(() {
      _isVoiceProcessing = true;
      _voiceStatus = 'Processing your command...';
    });
    _sendOverlayOrbState(
      state: 'processing',
      label: 'Processing command',
      detail: 'Voice request received',
      mode: _mode,
    );
    unawaited(
      _sendMessage(text.trim()).whenComplete(() async {
        if (_wakeWordEnabled) await _voiceService.resumeWakeWordMode();
        if (mounted) {
          setState(() {
            _isVoiceProcessing = false;
            _voiceStatus = _voiceReadinessSummary;
          });
        }
      }),
    );
  }

  Future<void> _startWakeCommandListening() async {
    if (!mounted || !_microphonePermissionGranted) return;
    var commandDispatched = false;
    setState(() {
      _isListening = true;
      _partialTranscript = '';
      _voiceStatus = 'Listening for your command...';
    });
    try {
      await _voiceService.startListening(
        onResult: (text) {
          if (!mounted || text.trim().isEmpty) return;
          commandDispatched = true;
          _dispatchVoiceCommand(text);
        },
        onDone: () {
          if (mounted) setState(() => _isListening = false);
          if (!commandDispatched && _wakeWordEnabled) {
            unawaited(_voiceService.resumeWakeWordMode());
          }
        },
      );
    } catch (error) {
      developer.log(
        'Wake command listening failed: $error',
        name: 'AgentCypher',
      );
      if (mounted) {
        setState(() {
          _isListening = false;
          _voiceStatus = 'Speech recognition failed to start.';
        });
      }
      if (_wakeWordEnabled) await _voiceService.resumeWakeWordMode();
    }
  }

  Future<void> _saveSession({int? revision}) async {
    if (_messages.isEmpty) return;
    if (revision != null && revision != _conversationRevision) return;

    // ChatHistoryService also derives a safe title when this is empty.
    if (_sessionTitle.isEmpty) {
      _sessionTitle = ChatHistoryService.generateTitle(
        _messages.map((message) => message.toJson()).toList(),
      );
    }

    final session = ChatSession(
      id: _sessionId,
      title: _sessionTitle,
      timestamp: DateTime.now(),
      messages: _messages.map((m) => m.toJson()).toList(),
      memoryEnabled: _memoryEnabledForConversation,
    );

    await ChatHistoryService.saveSession(session);
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      final picked = await _attachmentService.pickDocuments();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        final existingIds = _selectedAttachments.map((item) => item.id).toSet();
        _selectedAttachments = List.unmodifiable(
          [
            ..._selectedAttachments,
            ...picked.where((item) => !existingIds.contains(item.id)),
          ].take(AttachmentService.maxAttachments),
        );
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not open documents')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open documents')));
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _selectedAttachments = List.unmodifiable(
        _selectedAttachments.where((item) => item.id != id),
      );
    });
  }

  Future<void> _renameSession(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Conversation name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (renamed == null || renamed.trim().isEmpty) return;
    await ChatHistoryService.renameSession(session.id, renamed);
    if (mounted) {
      setState(() {
        if (session.id == _sessionId) _sessionTitle = renamed.trim();
      });
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This removes the saved conversation from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ChatHistoryService.deleteSession(session.id);
    if (!mounted) return;
    if (session.id == _sessionId) _startNewChat();
    setState(() {});
  }

  void _stopCurrentOperation() {
    if (!_isLoading) return;
    _streamCancellationRequested = true;
    _aiService.cancelStreaming();
    _actionHandler.cancelTask();
    // The owning stream will persist its cancelled state before unwinding.
  }

  bool _isCurrentRevision(int revision) =>
      mounted && revision == _conversationRevision;

  void _rebuildAiHistory() {
    _aiService.clearHistory();
    for (final message in _messages) {
      if (message.actionResult != null || message.isStreaming) continue;
      if (message.content.trim().isEmpty) continue;
      _aiService.addHistoryMessage(message.role, message.content);
    }
  }

  Future<void> _finishRequest(int revision) async {
    if (!_isCurrentRevision(revision)) return;
    setState(() => _isLoading = false);
    _scrollToBottom();
    unawaited(
      _updateOverlayState().catchError((error) {
        developer.log(
          'Overlay state update failed: $error',
          name: 'AgentCypher',
        );
      }),
    );
  }

  Future<void> _handleImageGeneration(
    String prompt,
    int revision,
    bool requestFromVoice,
  ) async {
    try {
      final generated = await _aiService.generateImage(prompt);
      if (!_isCurrentRevision(revision)) return;
      final imageResponse = ChatMessage(
        role: 'assistant',
        content: generated.revisedPrompt == null
            ? 'Generated image.'
            : 'Generated image.\n\n_${generated.revisedPrompt}_',
        imageUrl: generated.imageUrl,
        status: 'complete',
      );
      setState(() => _messages.add(imageResponse));
      unawaited(
        _voiceService.speakResponse(
          imageResponse.content,
          fromVoice: requestFromVoice,
          responseId: imageResponse.id,
        ),
      );
      await _saveSession(revision: revision);
    } catch (error) {
      if (_isCurrentRevision(revision)) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content:
                  'Image generation unavailable: ${error.toString().replaceFirst('Exception: ', '')}',
              status: 'failed',
            ),
          );
        });
        await _saveSession(revision: revision);
      }
    } finally {
      await _finishRequest(revision);
    }
  }

  Future<void> _handleWebResearch(
    String prompt,
    List<AttachmentReference> selectedAttachments,
    int revision,
    bool requestFromVoice,
  ) async {
    _sendOverlayOrbState(
      state: 'processing',
      label: 'Researching online',
      detail: 'Retrieving public sources',
      mode: 'chat',
    );
    try {
      final report = await _researchReportService.createReport(
        goal: prompt,
        attachments: selectedAttachments,
      );
      final artifact = await _researchReportService.exportReport(report);
      if (!_isCurrentRevision(revision)) return;
      final responseBuffer = StringBuffer(report.toMarkdown());
      if (artifact != null) {
        responseBuffer
          ..writeln()
          ..writeln(
            '**Report artifact:** `${artifact.name}` is available in Unified Task Workspace for viewing, copying, exporting, or sharing.',
          );
      }
      final researchMessage = ChatMessage(
        role: 'assistant',
        content: responseBuffer.toString().trim(),
        status: 'complete',
      );
      setState(() => _messages.add(researchMessage));
      _sendOverlayOrbState(
        state: 'complete',
        label: 'Research complete',
        detail:
            '${report.sourceCount} public sources found; report status ${report.status}',
        mode: 'chat',
      );
      unawaited(
        _voiceService.speakResponse(
          researchMessage.content,
          fromVoice: requestFromVoice,
          responseId: researchMessage.id,
        ),
      );
      await _saveSession(revision: revision);
    } catch (error) {
      if (_isCurrentRevision(revision)) {
        final researchError = ChatMessage(
          role: 'assistant',
          content: 'Web research failed: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          status: 'failed',
        );
        setState(() => _messages.add(researchError));
        _sendOverlayOrbState(
          state: 'error',
          label: 'Research failed',
          detail: error.toString(),
          mode: 'chat',
        );
        unawaited(
          _voiceService.speakResponse(
            researchError.content,
            fromVoice: requestFromVoice,
            responseId: researchError.id,
          ),
        );
        await _saveSession(revision: revision);
      }
    } finally {
      await _finishRequest(revision);
    }
  }

  Future<void> _sendMessage(
    String text, {
    bool displayUserMessage = true,
    String? appendToMessageId,
  }) async {
    final requestFromVoice = _lastRequestFromVoice;
    _lastRequestFromVoice = false;
    final selectedAttachments = List<AttachmentReference>.unmodifiable(
      _selectedAttachments,
    );
    final prompt = text.trim().isEmpty && selectedAttachments.isNotEmpty
        ? 'Please inspect the attached files.'
        : text.trim();
    if (!mounted || prompt.isEmpty || _isLoading) return;
    final attachmentContext = await _attachmentService.buildPromptContext(
      selectedAttachments,
    );
    final inspectedAttachments = await Future.wait(
      selectedAttachments.map(_attachmentService.inspect),
    );
    final dataSummaries = inspectedAttachments
        .where((inspection) => inspection.dataSummary != null)
        .map((inspection) => inspection.dataSummary!)
        .take(AttachmentService.maxAttachments)
        .toList(growable: false);

    final revision = ++_conversationRevision;
    _streamCancellationRequested = false;
    if (displayUserMessage) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'user',
            content: prompt,
            attachments: selectedAttachments,
            dataSummaries: dataSummaries,
          ),
        );
        _selectedAttachments = const [];
        _isLoading = true;
      });
      _textController.clear();
    } else {
      setState(() => _isLoading = true);
    }
    _updateOverlayState();
    _scrollToBottom();

    try {
      await _saveSession(revision: revision);
    } catch (error, stackTrace) {
      developer.log(
        'Could not save chat session before request: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!_isCurrentRevision(revision)) return;

    if (_aiService.isImageGenerationRequest(prompt)) {
      await _handleImageGeneration(prompt, revision, requestFromVoice);
      return;
    }

    if (_aiService.isWebResearchRequest(prompt)) {
      await _handleWebResearch(prompt, selectedAttachments, revision, requestFromVoice);
      return;
    }

    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      status: 'streaming',
      sourceMessageId: appendToMessageId,
    );
    setState(() => _messages.add(assistantMessage));
    await _saveSession(revision: revision);
    if (!_isCurrentRevision(revision)) return;
    final assistantId = assistantMessage.id;
    String accumulated = '';

    int currentAssistantIndex() =>
        _messages.indexWhere((message) => message.id == assistantId);

    Future<void> persistAssistant({
      required String status,
      String? content,
    }) async {
      if (!_isCurrentRevision(revision)) return;
      final index = currentAssistantIndex();
      if (index < 0) return;
      setState(() {
        _messages[index] = _messages[index].copyWith(
          content: content,
          status: status,
        );
      });
      await _saveSession(revision: revision);
    }

    try {
      final isAgent = _mode == 'agent';
      _sendOverlayOrbState(
        state: isAgent ? 'planning' : 'processing',
        label: isAgent ? 'Planning task' : 'Thinking',
        detail: isAgent ? 'Agent mode selected' : 'Chat mode selected',
        mode: isAgent ? 'agent' : 'chat',
      );
      final memoryContext =
          _automaticMemoryEnabled && _memoryEnabledForConversation
          ? await _userMemoryService.getMemorySummary()
          : null;
      if (!_isCurrentRevision(revision)) return;
      final stream = _aiService
          .sendMessageStream(
            prompt,
            isAgentMode: isAgent,
            memoryContext: memoryContext,
            attachmentContext: attachmentContext.isEmpty
                ? null
                : attachmentContext,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: (sink) {
              sink.addError(
                TimeoutException(
                  'The model did not return visible text within 90 seconds.',
                ),
              );
              sink.close();
            },
          );

      await for (final chunk in stream) {
        if (!_isCurrentRevision(revision)) return;
        accumulated += chunk;
        final index = currentAssistantIndex();
        if (index < 0) return;
        setState(() {
          _messages[index] = _messages[index].copyWith(
            content: accumulated,
            status: 'streaming',
          );
        });
        _scrollToBottom();
      }

      if (!_isCurrentRevision(revision)) return;
      final action = _aiService.parseAction(accumulated);
      final index = currentAssistantIndex();
      if (index < 0) return;

      if (action != null) {
        setState(() {
          _messages[index] = _messages[index].copyWith(status: 'complete');
        });
        _rebuildAiHistory();
        setState(() => _messages.removeAt(index));

        await _showTaskProgressOverlay('Starting: $prompt');
        if (selectedAttachments.isNotEmpty) {
          TaskTelemetryService.shared.recordAttachments(selectedAttachments);
        }
        final result = await _actionHandler.execute(
          action,
          aiService: _aiService,
          onProgress: (msg) {
            developer.log('Task progress: $msg', name: 'AgentCypher');
            _sendOverlayEvent('OVERLAY_PROGRESS', msg);
            _sendOverlayOrbState(
              state: _orbStateForTaskProgress(msg),
              label: msg,
              detail: 'Agent mode',
              mode: 'agent',
            );
            if (_isCurrentRevision(revision)) {
              setState(() {
                _messages.add(
                  ChatMessage(role: 'assistant', content: '⏳ $msg'),
                );
              });
              _scrollToBottom();
            }
          },
        );
        if (!_isCurrentRevision(revision)) return;

        final actionResponse = ChatMessage(
          role: 'assistant',
          content: result.success
              ? (action.response.isNotEmpty
                    ? action.response
                    : (result.details ?? 'Done.'))
              : (action.response.isNotEmpty
                    ? '${action.response}\n\n⚠️ ${result.details}'
                    : '⚠️ ${result.details}'),
          actionResult: result,
          status: 'complete',
        );
        setState(() => _messages.add(actionResponse));
        unawaited(
          _voiceService.speakResponse(
            actionResponse.content,
            fromVoice: requestFromVoice,
            responseId: actionResponse.id,
          ),
        );
        _sendOverlayOrbState(
          state: result.success ? 'complete' : 'error',
          label: result.success ? 'Task complete' : 'Task failed',
          detail:
              result.details ??
              (result.success ? 'Verified' : 'Recovery stopped'),
          mode: 'agent',
        );
        _sendOverlayEvent(
          'OVERLAY_TASK_FINISHED',
          result.success
              ? (result.details ?? 'Task complete.')
              : 'Task failed: ${result.details ?? 'Unknown error'}',
        );
        if (action.action != 'execute_task') {
          await _notificationService.showTaskCompleteNotification(
            result.success ? 'Task Completed' : 'Task Failed',
            result.details ??
                (result.success
                    ? 'Agent finished its goal.'
                    : 'Agent could not complete the task.'),
          );
        }
        await _saveSession(revision: revision);
      } else {
        if (appendToMessageId != null) {
          final targetIndex = _messages.indexWhere(
            (message) => message.id == appendToMessageId,
          );
          final responseIndex = currentAssistantIndex();
          if (targetIndex >= 0 && responseIndex >= 0) {
            final target = _messages[targetIndex];
            final addition = accumulated.trim();
            setState(() {
              _messages[targetIndex] = target.copyWith(
                content: addition.isEmpty
                    ? target.content
                    : '${target.content.trimRight()}\n\n$addition',
                status: 'complete',
              );
              _messages.removeAt(responseIndex);
            });
            _rebuildAiHistory();
            await _saveSession(revision: revision);
          } else {
            await persistAssistant(status: 'complete', content: accumulated);
          }
        } else {
          await persistAssistant(status: 'complete', content: accumulated);
        }
        _sendOverlayOrbState(
          state: 'complete',
          label: 'Chat complete',
          detail: 'Response ready',
          mode: 'chat',
        );
        if (accumulated.trim().isNotEmpty) {
          unawaited(
            _voiceService.speakResponse(
              accumulated,
              fromVoice: requestFromVoice,
              responseId: assistantId,
            ),
          );
        }
      }
    } catch (error) {
      if (!_isCurrentRevision(revision)) return;
      final cancelled =
          _streamCancellationRequested || error is StreamCancelledException;
      _sendOverlayOrbState(
        state: cancelled ? 'idle' : 'error',
        label: cancelled ? 'Generation stopped' : 'Response failed',
        detail: cancelled
            ? 'Ready for another request'
            : 'Tap or say Hey Cypher to retry',
        mode: _mode,
      );
      await persistAssistant(
        status: cancelled ? 'cancelled' : 'failed',
        content: accumulated.trim().isEmpty
            ? (cancelled
                  ? 'Generation stopped.'
                  : 'Error: ${error.toString().replaceFirst('Exception: ', '')}')
            : accumulated,
      );
    } finally {
      await _finishRequest(revision);
    }
  }

  String _orbStateForTaskProgress(String message) {
    final text = message.toLowerCase();
    if (text.contains('recover')) return 'recovering';
    if (text.contains('verif')) return 'verifying';
    if (text.contains('observ')) return 'observing';
    if (text.contains('select') || text.contains('target')) return 'acting';
    if (text.contains('plan') || text.contains('understand')) return 'planning';
    return 'acting';
  }

  int _messageIndex(ChatMessage message) =>
      _messages.indexWhere((candidate) => candidate.id == message.id);

  Future<void> _replaceFromUserMessage(int userIndex, String prompt) async {
    if (_isLoading || userIndex < 0 || userIndex >= _messages.length) return;
    setState(() {
      _messages.removeRange(userIndex, _messages.length);
      _rebuildAiHistory();
    });
    await _saveSession();
    await _sendMessage(prompt);
  }

  Future<void> _editAndResend(ChatMessage message) async {
    final index = _messageIndex(message);
    if (index < 0 || _isLoading) return;
    final controller = TextEditingController(text: message.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Resend'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || edited.trim().isEmpty || !mounted) return;
    await _replaceFromUserMessage(index, edited.trim());
  }

  Future<void> _regenerateResponse(ChatMessage message) async {
    final assistantIndex = _messageIndex(message);
    if (assistantIndex < 1 || _isLoading) return;
    var userIndex = assistantIndex - 1;
    while (userIndex >= 0 && !_messages[userIndex].isUser) {
      userIndex--;
    }
    if (userIndex < 0) return;
    await _replaceFromUserMessage(userIndex, _messages[userIndex].content);
  }

  Future<void> _retryResponse(ChatMessage message) async {
    await _regenerateResponse(message);
  }

  Future<void> _continueResponse(ChatMessage message) async {
    if (_isLoading || _messageIndex(message) < 0) return;
    await _sendMessage(
      'Continue the previous response without repeating it.',
      displayUserMessage: false,
      appendToMessageId: message.id,
    );
  }

  Future<void> _shareResponse(String content) async {
    if (content.trim().isEmpty) return;
    try {
      await _nativeChannel.invokeMethod<bool>('shareText', {'text': content});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Sharing unavailable: $error')));
    }
  }

  Future<void> _showTaskProgressOverlay(String message) async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    if (!await FlutterOverlayWindow.isPermissionGranted()) return;

    // Never cover Agent Cypher itself. The lifecycle observer will create the
    // overlay after an automated action moves this app to the background.
    if (_appLifecycleState != AppLifecycleState.paused) return;

    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Agent Cypher',
        overlayContent: 'Performing task...',
        flag: OverlayFlag.focusPointer,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        startPosition: const OverlayPosition(0, 200),
        width: 56,
        height: 56,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    // Keep the overlay minimized during automation. The user can still tap the
    // bubble to open the full conversation whenever they choose.
    _sendOverlayEvent('OVERLAY_TASK_STARTED', message);
  }

  void _sendOverlayEvent(String type, String message) {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final safeMessage = message.replaceAll('|', ' ');
    unawaited(
      FlutterOverlayWindow.shareData(
        '$type|$safeMessage',
      ).timeout(const Duration(seconds: 2)).catchError((Object _) {}),
    );
  }

  void _sendOverlayOrbState({
    required String state,
    required String label,
    required String detail,
    required String mode,
    bool visible = true,
  }) {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final payload = base64Encode(
      utf8.encode(
        jsonEncode({
          'state': state,
          'label': label,
          'detail': detail,
          'mode': mode,
          'visible': visible,
        }),
      ),
    );
    unawaited(
      FlutterOverlayWindow.shareData(
        'OVERLAY_ORB_STATE|$payload',
      ).timeout(const Duration(seconds: 2)).catchError((Object _) {}),
    );
  }

  void _publishVoiceOrbState(VoiceEvent event) {
    switch (event.type) {
      case 'wake_word_listening':
        _sendOverlayOrbState(
          state: 'listening',
          label: 'Listening for Hey Cypher',
          detail: 'Say the wake phrase',
          mode: 'auto',
        );
        break;
      case 'wake_word_detected':
        _sendOverlayOrbState(
          state: 'listening',
          label: 'Hey Cypher detected',
          detail: 'Listening for your command',
          mode: 'auto',
        );
        break;
      case 'listening_started':
        _sendOverlayOrbState(
          state: 'listening',
          label: 'Listening',
          detail: 'Speak your request',
          mode: _mode,
        );
        break;
      case 'recognized':
        _sendOverlayOrbState(
          state: 'processing',
          label: 'Processing request',
          detail: 'Understanding your words',
          mode: _mode,
        );
        break;
      case 'speaking_started':
        _sendOverlayOrbState(
          state: 'speaking',
          label: 'Speaking',
          detail: 'Response ready',
          mode: _mode,
        );
        break;
      case 'speaking_completed':
      case 'speaking_stopped':
        _sendOverlayOrbState(
          state: 'complete',
          label: 'Ready',
          detail: 'Say Hey Cypher again',
          mode: _mode,
        );
        break;
      case 'wake_word_stopped':
        _sendOverlayOrbState(
          state: 'idle',
          label: 'Wake phrase off',
          detail: 'Enable it in Voice settings',
          mode: 'auto',
        );
        break;
      case 'wake_word_error':
      case 'wake_word_unavailable':
      case 'error':
        _sendOverlayOrbState(
          state: 'error',
          label: 'Voice unavailable',
          detail: event.message,
          mode: 'auto',
        );
        break;
    }
  }

  Future<void> _sendOverlayHistorySnapshot() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final history = base64Encode(
      utf8.encode(
        jsonEncode(_messages.map((message) => message.toJson()).toList()),
      ),
    );
    try {
      await FlutterOverlayWindow.shareData(
        'OVERLAY_HISTORY|$history',
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (!mounted) return;
    if (_isListening) {
      try {
        await _voiceService.stopListening();
      } catch (error) {
        developer.log('Voice stop failed: $error', name: 'AgentCypher');
      }
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_microphonePermissionGranted) {
      _showVoiceNotice(
        'Microphone permission is required for speech recognition.',
      );
      return;
    }
    if (!_speechRecognitionAvailable) {
      _showVoiceNotice('Speech recognition is unavailable on this device.');
      return;
    }

    if (_wakeWordEnabled) await _voiceService.pauseWakeWordMode();
    var commandDispatched = false;
    setState(() {
      _isListening = true;
      _partialTranscript = '';
      _voiceStatus = 'Listening for a command...';
    });

    try {
      await _voiceService.startListening(
        onResult: (text) {
          if (!mounted || text.trim().isEmpty) return;
          commandDispatched = true;
          _dispatchVoiceCommand(text);
        },
        onDone: () {
          if (mounted) setState(() => _isListening = false);
          if (!commandDispatched && _wakeWordEnabled) {
            unawaited(_voiceService.resumeWakeWordMode());
          }
        },
      );
    } catch (error) {
      developer.log('Voice start failed: $error', name: 'AgentCypher');
      if (mounted) {
        setState(() {
          _isListening = false;
          _voiceStatus = 'Speech recognition failed to start.';
        });
      }
      if (_wakeWordEnabled) await _voiceService.resumeWakeWordMode();
    }
  }

  Future<void> _stopSpeaking() async {
    await _voiceService.stopSpeaking();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _voiceStatus = _voiceReadinessSummary;
    });
  }

  void _showVoiceNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setConversationMemoryEnabled(bool enabled) async {
    if (!mounted) return;
    setState(() => _memoryEnabledForConversation = enabled);
    await _saveSession();
  }

  Future<void> _refreshMemoryPreference() async {
    final enabled = await _userMemoryService.getAutomaticMemoryEnabled();
    if (mounted && enabled != _automaticMemoryEnabled) {
      setState(() => _automaticMemoryEnabled = enabled);
    }
  }

  void _startNewChat() {
    _conversationRevision++;
    _streamCancellationRequested = true;
    _aiService.cancelStreaming();
    _actionHandler.cancelTask();
    setState(() {
      _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
      _sessionTitle = '';
      _memoryEnabledForConversation = true;
      _messages.clear();
      _isLoading = false;
      _aiService.clearHistory();
    });
  }

  void _loadChatSession(ChatSession session) {
    _conversationRevision++;
    _streamCancellationRequested = true;
    _aiService.cancelStreaming();
    _actionHandler.cancelTask();
    setState(() {
      _sessionId = session.id;
      _sessionTitle = session.title;
      _memoryEnabledForConversation = session.memoryEnabled;
      _messages
        ..clear()
        ..addAll(session.messages.map(ChatMessage.fromJson));
      _isLoading = false;
      _rebuildAiHistory();
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayHistoryTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _voiceEvents?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _appLifecycleState = state;
    });
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshMemoryPreference());
      _startOverlayHistorySync();
      unawaited(_handleAppForegrounded());
    } else {
      _overlayHistoryTimer?.cancel();
      _updateOverlayState();
    }
  }

  void _startOverlayHistorySync() {
    _overlayHistoryTimer?.cancel();
    if (!FeatureFlags.floatingOverlayEnabled) return;
    unawaited(_importOverlayChatHistory());
    _overlayHistoryTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      if (_appLifecycleState == AppLifecycleState.resumed) {
        unawaited(_importOverlayChatHistory());
      }
    });
  }

  Future<void> _handleAppForegrounded() async {
    await _updateOverlayState();
    await _importOverlayChatHistory();
  }

  Future<void> _importOverlayChatHistory() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    if (_importingOverlayHistory) return;
    _importingOverlayHistory = true;
    try {
      final handoff = await ChatHistoryService.consumeOverlayMessages();
      if (!mounted || handoff.isEmpty) return;

      final imported = handoff.map(ChatMessage.fromJson).toList();
      for (final message in imported) {
        if (message.actionResult == null) {
          _aiService.addHistoryMessage(message.role, message.content);
        }
      }
      setState(() {
        _messages.addAll(imported);
      });
      _scrollToBottom();
      await _saveSession();
    } finally {
      _importingOverlayHistory = false;
    }
  }

  int _overlayUpdateGeneration = 0;
  bool _importingOverlayHistory = false;

  Future<void> _updateOverlayState() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final generation = ++_overlayUpdateGeneration;
    final isBackground = _appLifecycleState == AppLifecycleState.paused;
    final shouldBeActive = isBackground;

    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted || generation != _overlayUpdateGeneration) return;

      final active = await FlutterOverlayWindow.isActive();
      if (generation != _overlayUpdateGeneration) return;
      if (shouldBeActive && !active) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (generation != _overlayUpdateGeneration) return;
        if (_appLifecycleState != AppLifecycleState.paused) return;
        if (await FlutterOverlayWindow.isActive()) return;
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'Agent Cypher',
          overlayContent: _isLoading
              ? 'Performing task...'
              : 'Floating Assistant',
          flag: OverlayFlag.focusPointer,
          alignment: OverlayAlignment.centerRight,
          visibility: NotificationVisibility.visibilitySecret,
          positionGravity: PositionGravity.auto,
          startPosition: const OverlayPosition(0, 200),
          width: 56,
          height: 56,
        );
        if (_isLoading && _appLifecycleState == AppLifecycleState.paused) {
          // Give the overlay isolate time to attach its listener, then send the
          // full active conversation. A second snapshot makes cold starts
          // reliable without duplicating messages because the overlay replaces
          // its list atomically.
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await _sendOverlayHistorySnapshot();
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (_isLoading && _appLifecycleState == AppLifecycleState.paused) {
            await _sendOverlayHistorySnapshot();
          }
        }
      } else if (shouldBeActive && active && _isLoading) {
        await _sendOverlayHistorySnapshot();
      } else if (!shouldBeActive && active) {
        try {
          await FlutterOverlayWindow.shareData(
            'OVERLAY_RESET|',
          ).timeout(const Duration(milliseconds: 150));
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (generation != _overlayUpdateGeneration) return;
        if (_appLifecycleState == AppLifecycleState.paused) return;
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Overlay state synchronization failed: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0A15)
          : const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            children: [
              TextSpan(
                text: 'Agent',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const TextSpan(
                text: ' Cypher',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _isLoading ? null : _startNewChat,
          ),
          // Settings Action
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    aiService: _aiService,
                    shizukuService: _actionHandler.shizuku,
                    screenAutomationService: _actionHandler.screenAutomation,
                    voiceService: _voiceService,
                  ),
                ),
              );
              await _actionHandler.shizuku.checkAvailability();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      drawer: ChatHistoryDrawer(
        sessionId: _sessionId,
        memoryEnabledForConversation: _memoryEnabledForConversation,
        automaticMemoryEnabled: _automaticMemoryEnabled,
        historyQuery: _historyQuery,
        onNewChat: _startNewChat,
        onMemoryChanged: _setConversationMemoryEnabled,
        onQueryChanged: (q) => setState(() => _historyQuery = q),
        onLoadSession: _loadChatSession,
        onRenameSession: _renameSession,
        onDeleteSession: _deleteSession,
        aiService: _aiService,
        shizukuService: _actionHandler.shizuku,
        screenAutomationService: _actionHandler.screenAutomation,
        voiceService: _voiceService,
      ),
      body: Stack(
        children: [
          // Background mesh glows
          BackgroundGlows(isDark: isDark),

          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),

          Column(
            children: [
              // Pill selector switcher
              ModeSelector(
            currentMode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            isDark: isDark,
          ),

              // API key warning banner
              if (!_aiService.isConfigured)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'API not configured. Tap Settings to add details.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                aiService: _aiService,
                                shizukuService: _actionHandler.shizuku,
                                screenAutomationService:
                                    _actionHandler.screenAutomation,
                                voiceService: _voiceService,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        child: const Text('Configure'),
                      ),
                    ],
                  ),
                ),

              // Chat content area
              Expanded(
                child: _messages.isEmpty
                    ? EmptyState(
                        mode: _mode,
                        isDark: isDark,
                        onSuggestionTap: _sendMessage,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return MessageBubble(
                            message: message,
                            onEdit: message.isUser ? _editAndResend : null,
                            onRegenerate: message.isAssistant
                                ? _regenerateResponse
                                : null,
                            onRetry: message.isAssistant
                                ? _retryResponse
                                : null,
                            onContinue: message.isAssistant
                                ? _continueResponse
                                : null,
                            onShare: message.isAssistant
                                ? _shareResponse
                                : null,
                          );
                        },
                      ),
              ),

              if (_isLoading)
                TaskProgressPanel(
                  isDark: isDark,
                  onStop: _stopCurrentOperation,
                ),

              // Voice readiness/status lives in Settings. Keep only the
              // compact microphone control in the composer.

              ChatInputBar(
                textController: _textController,
                isDark: isDark,
                isLoading: _isLoading,
                isListening: _isListening,
                isSpeaking: _isSpeaking,
                selectedAttachments: _selectedAttachments,
                onSend: () => _sendMessage(_textController.text),
                onSendText: _isLoading ? null : (text) => _sendMessage(text),
                onToggleVoice: _toggleVoice,
                onStopSpeaking: _stopSpeaking,
                onPickFiles: _pickFiles,
                onRemoveAttachment: _isLoading ? null : _removeAttachment,
              ),
            ],
          ),
        ],
      ),
    );
  }



}
