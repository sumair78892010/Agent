import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/services/voice_service.dart').readAsStringSync();

  test('text responses are not automatically spoken', () {
    expect(source, contains('Future<bool> speakResponse('));
    expect(source, contains('if (!fromVoice) return false;'));
  });

  test('voice responses sanitize markdown before TTS', () {
    expect(source, contains('_sanitizeForSpeech(text)'));
    expect(source, contains("RegExp(r'```[\\s\\S]*?```')"));
    expect(source, contains("RegExp(r'\\s+')"));
  });

  test('wake-word availability remains truthful on native failure', () {
    expect(source, contains("'available': false"));
    expect(source, contains('_wakeWordAvailable = false;'));
  });
}
