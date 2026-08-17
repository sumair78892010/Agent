import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class StartupScreen extends StatefulWidget {
  final bool onboardingCompleted;

  const StartupScreen({super.key, required this.onboardingCompleted});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _routeTimer = Timer(const Duration(milliseconds: 1450), _openNextScreen);
  }

  void _openNextScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => widget.onboardingCompleted
            ? const HomeScreen()
            : const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? AgentCypherTheme.darkBg
        : AgentCypherTheme.lightBg;
    final foreground = isDark
        ? AgentCypherTheme.darkText
        : AgentCypherTheme.lightText;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _StartupGlow(isDark: isDark),
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 148,
                      height: 148,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AgentCypherTheme.darkSurface
                            : AgentCypherTheme.lightSurface,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.18),
                            blurRadius: 32,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/app-logo.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Agent Cypher logo',
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Agent Cypher',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'by Sumair',
                      style: TextStyle(
                        color: foreground.withOpacity(0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 92,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: foreground.withOpacity(0.12),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Text(
              'Preparing your workspace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground.withOpacity(0.48),
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupGlow extends StatelessWidget {
  final bool isDark;

  const _StartupGlow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _glow(color.withOpacity(isDark ? 0.2 : 0.1), 330),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _glow(color.withOpacity(isDark ? 0.13 : 0.06), 360),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}
