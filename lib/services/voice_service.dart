import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.cypherghost.agentcypher/accessibility',
  );
  static const EventChannel _wakeWordEventChannel = EventChannel(
    'com.cypherghost.agentcypher/wake_word_events',
  );
  bool _isInitialized = false;
  bool _ttsAvailable = false;
  bool _wakeWordAvailable = false;
  bool _wakeWordEnabled = false;
  bool _wakeWordListening = false;
  bool _isListening = false;

  final StreamController<VoiceEvent> _eventController =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _wakeWordEvents;

  String _lastRecognizedText = '';
  String? _lastSpokenResponseId;
  String? _lastSpokenText;

  bool get isListening => _isListening;
  Stream<VoiceEvent> get eventStream => _eventController.stream;
  bool get speechRecognitionAvailable => _isInitialized;
  bool get ttsAvailable => _ttsAvailable;
  bool get wakeWordAvailable => _wakeWordAvailable;
  bool get wakeWordEnabled => _wakeWordEnabled;
  bool get wakeWordListening => _wakeWordListening;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _isListening = false;
          _eventController.add(
            VoiceEvent(
              type: 'error',
              message: 'Speech recognition error: $error',
            ),
          );
        },
        onStatus: (status) {
          _eventController.add(
            VoiceEvent(type: 'status', message: 'Speech status: $status'),
          );
        },
      );

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsAvailable = true;

      // Bridge the native foreground wake-word service into the same event
      // stream consumed by the UI. Native uses "wake_word"; Flutter exposes
      // the stable "wake_word_detected" event to avoid leaking platform names.
      _wakeWordEvents ??= _wakeWordEventChannel
          .receiveBroadcastStream()
          .listen(_handleNativeWakeWordEvent, onError: (Object error) {
        _wakeWordAvailable = false;
        _wakeWordListening = false;
        _eventController.add(
          VoiceEvent(
            type: 'wake_word_error',
            message: 'Wake-word event channel error: $error',
          ),
        );
      });

      _eventController.add(
        VoiceEvent(type: 'initialized', message: 'Voice service initialized'),
      );
    } catch (e) {
      _eventController.add(
        VoiceEvent(type: 'error', message: 'Voice initialization failed: $e'),
      );
    }
  }

  void _handleNativeWakeWordEvent(dynamic rawEvent) {
    if (rawEvent is! Map) return;
    final event = Map<String, dynamic>.from(
      rawEvent.map((key, value) => MapEntry('$key', value)),
    );
    final type = event['type']?.toString() ?? '';

    switch (type) {
      case 'wake_word':
        _wakeWordAvailable = true;
        _wakeWordListening = false;
        _eventController.add(
          VoiceEvent(
            type: 'wake_word_detected',
            message: 'Hey Cypher detected',
            content: event['text']?.toString(),
            wakeWordAvailable: true,
            wakeWordEnabled: _wakeWordEnabled,
            wakeWordListening: false,
          ),
        );
        break;
      case 'unavailable':
        _wakeWordAvailable = false;
        _wakeWordListening = false;
        _eventController.add(
          VoiceEvent(
            type: 'wake_word_unavailable',
            message: event['reason']?.toString() ??
                'Background wake-word recognition is unavailable.',
            wakeWordAvailable: false,
            wakeWordEnabled: _wakeWordEnabled,
            wakeWordListening: false,
          ),
        );
        break;
      case 'status':
        final running = event['running'] == true;
        final paused = event['paused'] == true;
        _wakeWordEnabled = running && !paused;
        _wakeWordListening = running && !paused;
        _wakeWordAvailable = true;
        _eventController.add(
          VoiceEvent(
            type: running && !paused
                ? 'wake_word_listening'
                : 'wake_word_stopped',
            message: running && !paused
                ? 'Listening for Hey Cypher...'
                : 'Wake-word service stopped.',
            wakeWordAvailable: true,
            wakeWordEnabled: _wakeWordEnabled,
            wakeWordListening: _wakeWordListening,
          ),
        );
        break;
      case 'listening':
        if (event['state'] == 'ready' || event['state'] == 'began') {
          _wakeWordAvailable = true;
          _wakeWordListening = true;
          _eventController.add(
            VoiceEvent(
              type: 'wake_word_listening',
              message: 'Listening for Hey Cypher...',
              wakeWordAvailable: true,
              wakeWordEnabled: _wakeWordEnabled,
              wakeWordListening: true,
            ),
          );
        }
        break;
      case 'error':
        _wakeWordListening = false;
        _eventController.add(
          VoiceEvent(
            type: 'wake_word_error',
            message: event['message']?.toString() ??
                'Background wake-word recognition failed.',
            wakeWordAvailable: _wakeWordAvailable,
            wakeWordEnabled: _wakeWordEnabled,
            wakeWordListening: false,
          ),
        );
        break;
    }
  }

  Future<bool> isTtsAvailable() async => _ttsAvailable;

  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) {
      _eventController.add(
        VoiceEvent(type: 'error', message: 'Voice service not initialized'),
      );
      return;
    }
    if (_isListening) return;

    _isListening = true;
    _eventController.add(
      VoiceEvent(
        type: 'listening_started',
        message: 'Started listening for voice input',
      ),
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            _lastRecognizedText = result.recognizedWords;
          }

          if (result.finalResult) {
            _isListening = false;
            _eventController.add(
              VoiceEvent(
                type: 'recognized',
                message: 'Speech recognized',
                content: result.recognizedWords,
              ),
            );
            onResult(result.recognizedWords);
            onDone();
          } else if (result.recognizedWords.isNotEmpty) {
            _eventController.add(
              VoiceEvent(
                type: 'partial_result',
                message: 'Partial result',
                content: result.recognizedWords,
              ),
            );
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          onDevice: false,
        ),
      );
    } catch (e) {
      _isListening = false;
      _eventController.add(
        VoiceEvent(type: 'error', message: 'Listening error: $e'),
      );
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    _eventController.add(
      VoiceEvent(type: 'listening_stopped', message: 'Stopped listening'),
    );
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      _eventController.add(
        VoiceEvent(type: 'speaking_started', message: 'Started speaking'),
      );
      await _tts.speak(text);
      _eventController.add(
        VoiceEvent(type: 'speaking_completed', message: 'Finished speaking'),
      );
    } catch (e) {
      _eventController.add(VoiceEvent(type: 'error', message: 'TTS error: $e'));
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _eventController.add(
      VoiceEvent(type: 'speaking_stopped', message: 'Stopped speaking'),
    );
  }

  String getLastRecognizedText() => _lastRecognizedText;
  void clearLastRecognizedText() => _lastRecognizedText = '';

  Future<Map<String, dynamic>> getWakeWordStatus() async {
    try {
      final raw = await _nativeChannel.invokeMethod<dynamic>('getWakeWordStatus');
      final status = raw is Map
          ? raw.map((key, value) => MapEntry('$key', value))
          : <String, dynamic>{};
      _wakeWordAvailable =
          status['available'] == true || status['supported'] == true;
      _wakeWordEnabled = status['enabled'] == true || status['running'] == true;
      _wakeWordListening =
          status['listening'] == true || status['running'] == true;
      return status;
    } catch (_) {
      _wakeWordAvailable = false;
      _wakeWordEnabled = false;
      _wakeWordListening = false;
      return const <String, dynamic>{'available': false};
    }
  }

  Future<bool> startWakeWordMode() async {
    try {
      final result = await _nativeChannel.invokeMethod<dynamic>(
        'startWakeWordDetection',
      );
      await getWakeWordStatus();
      return result == true;
    } catch (_) {
      _wakeWordAvailable = false;
      return false;
    }
  }

  Future<bool> stopWakeWordMode() async {
    try {
      final result = await _nativeChannel.invokeMethod<dynamic>(
        'stopWakeWordDetection',
      );
      _wakeWordEnabled = false;
      _wakeWordListening = false;
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseWakeWordMode() async {
    try {
      final result = await _nativeChannel.invokeMethod<dynamic>(
        'pauseWakeWordDetection',
      );
      _wakeWordListening = false;
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resumeWakeWordMode() async {
    try {
      final result = await _nativeChannel.invokeMethod<dynamic>(
        'resumeWakeWordDetection',
      );
      await getWakeWordStatus();
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> speakResponse(
    String text, {
    bool fromVoice = false,
    String? responseId,
  }) async {
    if (!fromVoice) return false;
    if (!_ttsAvailable && !_isInitialized) await init();
    if (!_ttsAvailable) return false;

    final sanitized = _sanitizeForSpeech(text);
    if (sanitized.isEmpty) return false;
    if (responseId != null && responseId == _lastSpokenResponseId) return false;
    if (responseId == null && sanitized == _lastSpokenText) return false;

    _lastSpokenResponseId = responseId;
    _lastSpokenText = sanitized;
    await speak(sanitized);
    return true;
  }

  String _sanitizeForSpeech(String text) {
    var sanitized = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code block ')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'https?://\S+'), ' link ')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'~~([^~]+)~~'), r'$1')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\|'), ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized;
  }

  void dispose() {
    _wakeWordEvents?.cancel();
    _wakeWordEvents = null;
    _speech.stop();
    _tts.stop();
    _eventController.close();
  }
}

class VoiceEvent {
  final String type;
  final String message;
  final String? content;
  final bool? speechRecognitionAvailable;
  final bool? ttsAvailable;
  final bool? wakeWordAvailable;
  final bool? wakeWordEnabled;
  final bool? wakeWordListening;

  VoiceEvent({
    required this.type,
    required this.message,
    this.content,
    this.speechRecognitionAvailable,
    this.ttsAvailable,
    this.wakeWordAvailable,
    this.wakeWordEnabled,
    this.wakeWordListening,
  });

  @override
  String toString() =>
      'VoiceEvent($type: $message' +
      (content != null ? ', "$content"' : '') +
      ')';
}
