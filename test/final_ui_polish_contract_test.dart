import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'lib';

  String read(String relativePath) =>
      File('$root/$relativePath').readAsStringSync();

  test(
    'startup screen preserves logo, Sumair attribution, and safe routing',
    () {
      final source = read('screens/startup_screen.dart');
      expect(source, contains("assets/app-logo.png"));
      expect(source, contains("'by Sumair'"));
      expect(source, contains('OnboardingScreen'));
      expect(source, contains('HomeScreen'));
      expect(source, contains('Timer'));
    },
  );

  test('welcome experience remains scrollable and keeps the existing CTA', () {
    final source = read('screens/onboarding_screen.dart');
    expect(source, contains('SingleChildScrollView'));
    expect(source, contains('BouncingScrollPhysics'));
    expect(source, contains("'assets/app-logo.png'"));
    expect(source, contains('Get Started'));
  });

  test(
    'assistant identity and execution details are observable, not hidden reasoning',
    () {
      final bubble = read('widgets/message_bubble.dart');
      final home = read('screens/home_screen.dart');
      expect(bubble, contains("'Cypher'"));
      expect(bubble, contains("'assets/app-logo.png'"));
      expect(home, contains('Observable execution details'));
      expect(home, contains('plannedAction'));
      expect(home, contains('verificationResult'));
      expect(home, contains('Open Developer Mode for Terminal/Workspace'));
      expect(home, isNot(contains('chain of thought')));
    },
  );
}
