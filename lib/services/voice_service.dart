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
  bool _isInitialized = false;
  bool _ttsAvailable = false;
  bool _wakeWordAvailable = false;
  bool _wakeWordEnabled = false;
  bool _wakeWordListening = false;
  bool _isListening = false;

  // Event stream controllers
  final StreamController<VoiceEvent> _eventController =
      StreamController.broadcast();

  String _lastRecognizedText = '';

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

      // Configure TTS
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsAvailable = true;

      _eventController.add(
        VoiceEvent(type: 'initialized', message: 'Voice service initialized'),
      );
    } catch (e) {
      _eventController.add(
        VoiceEvent(type: 'error', message: 'Voice initialization failed: $e'),
      );
    }
  }

  /// Check if TTS engine is available
  Future<bool> isTtsAvailable() async {
    try {
      return _ttsAvailable;
    } catch (e) {
      return false;
    }
  }

  /// Start listening for speech. Returns transcribed text via callback.
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

    if (_isListening) return; // Already listening

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

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    _eventController.add(
      VoiceEvent(type: 'listening_stopped', message: 'Stopped listening'),
    );
  }

  /// Speak text aloud
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

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

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _eventController.add(
      VoiceEvent(type: 'speaking_stopped', message: 'Stopped speaking'),
    );
  }

  /// Get last recognized text
  String getLastRecognizedText() => _lastRecognizedText;

  /// Clear last recognized text
  void clearLastRecognizedText() => _lastRecognizedText = '';

  Future<Map<String, dynamic>> getWakeWordStatus() async {
    try {
      final raw = await _nativeChannel.invokeMethod<dynamic>(
        'getWakeWordStatus',
      );
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
    // Text prompts remain visual-only. Only a response originating from a
    // voice prompt may be spoken automatically.
    if (!fromVoice) return false;
    if (!_ttsAvailable && !_isInitialized) await init();
    if (!_ttsAvailable) return false;
    await speak(_sanitizeForSpeech(text));
    return true;
  }

  String _sanitizeForSpeech(String text) {
    var sanitized = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code block ')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized;
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
    _eventController.close();
  }
}

/// Voice event for streaming updates
class VoiceEvent {
  final String
  type; // initialized, listening_started, listening_stopped, recognized, partial_result, speaking_started, speaking_completed, speaking_stopped, error
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
