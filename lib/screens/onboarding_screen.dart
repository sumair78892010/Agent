import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../config/feature_flags.dart';
import '../services/ai_service.dart';
import '../services/screen_automation_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ScreenAutomationService _screenAutomationService =
      ScreenAutomationService();
  final AiService _aiService = AiService();

  int _currentStep = 0;
  bool _isAccessibilityGranted = false;
  bool _isMicrophoneGranted = false;
  bool _isNotificationsGranted = false;
  bool _isContactsGranted = false;
  bool _isPhoneGranted = false;
  bool _isSmsGranted = false;
  bool _isOverlayGranted = false;

  // AI config states
  String _selectedProvider = 'deepseek';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://api.deepseek.com',
  );
  final TextEditingController _modelController = TextEditingController(
    text: 'deepseek-chat',
  );
  bool _obscureKey = true;
  bool _isValidating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAiDefaults();
    _checkPermissions();
  }

  Future<void> _loadAiDefaults() async {
    await _aiService.init();
    if (!mounted || !_aiService.isConfigured) return;
    setState(() {
      _selectedProvider = 'custom';
      _apiKeyController.text = _aiService.apiKey;
      _baseUrlController.text = _aiService.baseUrl;
      _modelController.text = _aiService.model;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final accessibilityRunning = await _screenAutomationService
        .isServiceRunning();
    final microphoneStatus = await Permission.microphone.status;
    final notificationsStatus = await Permission.notification.status;
    final contactsStatus = await Permission.contacts.status;
    final phoneStatus = await Permission.phone.status;
    final smsStatus = await Permission.sms.status;
    final overlayGranted = FeatureFlags.floatingOverlayEnabled
        ? await FlutterOverlayWindow.isPermissionGranted()
        : false;

    if (mounted) {
      setState(() {
        _isAccessibilityGranted = accessibilityRunning;
        _isMicrophoneGranted = microphoneStatus.isGranted;
        _isNotificationsGranted = notificationsStatus.isGranted;
        _isContactsGranted = contactsStatus.isGranted;
        _isPhoneGranted = phoneStatus.isGranted;
        _isSmsGranted = smsStatus.isGranted;
        _isOverlayGranted = overlayGranted;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    _checkPermissions();
  }

  Future<void> _requestAccessibility() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Screen Control'),
        content: const Text(
          'If Android shows “Restricted setting”, open App Info first, tap the '
          'three-dot menu, and choose “Allow restricted settings”. Then return '
          'and open Accessibility Settings to enable Agent Cypher Screen Control.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _screenAutomationService.openAccessibilitySettings();
            },
            child: const Text('Accessibility Settings'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Open App Info First'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestOverlayPermission() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
      granted = await FlutterOverlayWindow.isPermissionGranted();
    }
    setState(() {
      _isOverlayGranted = granted;
    });
  }

  void _selectProvider(String provider) {
    setState(() {
      _selectedProvider = provider;
      _validationError = null;
      if (provider == 'deepseek') {
        _baseUrlController.text = 'https://api.deepseek.com';
        _modelController.text = 'deepseek-chat';
      } else if (provider == 'groq') {
        _baseUrlController.text = 'https://api.groq.com/openai/v1';
        _modelController.text = 'llama-3.3-70b-versatile';
      } else if (provider == 'nvidia') {
        _baseUrlController.text = AiService.nvidiaBaseUrl;
        _modelController.text = AiService.nvidiaDefaultModel;
      } else if (provider == 'ollama') {
        _baseUrlController.text = 'http://10.0.2.2:11434/v1';
        _modelController.text = 'gemma2';
      } else if (provider == 'local') {
        _baseUrlController.text = 'http://10.0.2.2:1234/v1';
        _modelController.text = 'qwen2.5-7b-instruct';
      } else {
        _baseUrlController.clear();
        _modelController.clear();
      }
    });
  }

  Future<void> _testAndSave() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();

    if (baseUrl.isEmpty || model.isEmpty) {
      setState(() {
        _validationError = 'Please fill out API Base URL and Model.';
        _isValidating = false;
      });
      return;
    }

    if (_selectedProvider != 'ollama' &&
        _selectedProvider != 'local' &&
        apiKey.isEmpty) {
      setState(() {
        _validationError = 'API Key is required for this provider.';
        _isValidating = false;
      });
      return;
    }

    try {
      final models = await _aiService.fetchAvailableModels(baseUrl, apiKey);
      if (models.isNotEmpty ||
          _selectedProvider == 'ollama' ||
          _selectedProvider == 'local') {
        await _aiService.saveSettings(
          apiKey: apiKey,
          baseUrl: baseUrl,
          model: model,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);

        if (mounted) {
          setState(() {
            _isValidating = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Configuration validated! Launching Agent Cypher...',
              ),
              backgroundColor: Colors.indigoAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _validationError =
              'Failed to fetch models from the server. Verify base URL and API Key.';
          _isValidating = false;
        });
      }
    } catch (e) {
      setState(() {
        _validationError =
            'Error: ${e.toString().replaceFirst('Exception: ', '')}';
        _isValidating = false;
      });
    }
  }

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an API Base URL first.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      final models = await _aiService.fetchAvailableModels(baseUrl, apiKey);

      setState(() {
        _isValidating = false;
      });

      if (models.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No models found. Check base URL or API Key.',
              ),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF161329) : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AiService.isNvidiaBaseUrl(baseUrl)
                          ? 'Select a Free NVIDIA Model'
                          : 'Select a Model',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final modelName = models[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            title: Text(
                              modelName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            onTap: () {
                              setState(() {
                                _modelController.text = modelName;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  bool get _canProceedToModel {
    return _isAccessibilityGranted &&
        _isMicrophoneGranted &&
        (!FeatureFlags.floatingOverlayEnabled || _isOverlayGranted);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1C1917)
          : const Color(0xFFF7F3EE),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
              child: _buildProgressHeader(isDark),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildWelcomePage(isDark),
                  _buildPermissionsPage(isDark),
                  _buildModelSetupPage(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _ink(bool isDark) =>
      isDark ? const Color(0xFFF7F3EE) : const Color(0xFF1C1917);
  Color _muted(bool isDark) =>
      isDark ? const Color(0xFFD6CFC4) : const Color(0xFF57534E);
  Color _panel(bool isDark) =>
      isDark ? const Color(0xFF2E2A27) : const Color(0xFFF0EBE3);
  Color _accent(bool isDark) =>
      isDark ? const Color(0xFFF7F3EE) : const Color(0xFF1C1917);

  Widget _buildProgressHeader(bool isDark) {
    final labels = ['Welcome', 'Permissions', 'API setup'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = _currentStep == index;
        final complete = _currentStep > index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active || complete
                        ? _accent(isDark)
                        : _muted(isDark).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? _ink(isDark) : _muted(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _pageFrame({required bool isDark, required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      child: child,
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return _pageFrame(
      isDark: isDark,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 38),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1917),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildLogo(size: 132, background: const Color(0xFFF7F3EE)),
                const SizedBox(height: 28),
                const Text(
                  'AGENT CYPHER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF7F3EE),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'An Assistant for Sumair',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD6CFC4), fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your device. Your commands. Your intelligence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8C857D),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _primaryButton(
                  'Get Started',
                  () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  ),
                  dark: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'What is Agent Cypher?',
            style: TextStyle(
              color: _ink(isDark),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A device-native assistant that listens, understands, and acts while keeping you in control.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted(isDark), fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  isDark,
                  Icons.mic_none_rounded,
                  'Voice control',
                  'Speak naturally and receive spoken responses.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  isDark,
                  Icons.bolt_rounded,
                  'Automation',
                  'Navigate apps and complete verified device tasks.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _wideInfoCard(
            isDark,
            Icons.auto_awesome_outlined,
            'AI intelligence',
            'Research, write, analyze data, manage files, and work through a unified task workspace.',
          ),
          const SizedBox(height: 28),
          _sectionLabel('CAPABILITIES', isDark),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Web research',
              'Terminal workspace',
              'File management',
              'Memory',
              'Voice',
              'Verified actions',
            ].map((label) => _chip(label, isDark)).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Built by Sumair · Cypher Ghost',
            style: TextStyle(
              color: _muted(isDark),
              fontSize: 12,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage(bool isDark) {
    return _pageFrame(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Give Cypher the right tools',
            style: TextStyle(
              color: _ink(isDark),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable the essentials first. Optional permissions can be added later from Settings.',
            style: TextStyle(color: _muted(isDark), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 22),
          _sectionLabel('REQUIRED FOR DEVICE CONTROL', isDark),
          _permissionTile(
            isDark,
            'Screen control',
            'Accessibility lets Cypher read the current screen and perform verified actions.',
            Icons.visibility_outlined,
            _isAccessibilityGranted,
            _requestAccessibility,
          ),
          _permissionTile(
            isDark,
            'Microphone',
            'Used for voice commands and speech recognition.',
            Icons.mic_none_rounded,
            _isMicrophoneGranted,
            () => _requestPermission(Permission.microphone),
          ),
          if (FeatureFlags.floatingOverlayEnabled)
            _permissionTile(
              isDark,
              'Floating overlay',
              'Shows task progress while Cypher works in another app.',
              Icons.layers_outlined,
              _isOverlayGranted,
              _requestOverlayPermission,
            ),
          const SizedBox(height: 18),
          _sectionLabel('OPTIONAL FEATURES', isDark),
          _permissionTile(
            isDark,
            'Notifications',
            'Receive task updates and alerts.',
            Icons.notifications_none_rounded,
            _isNotificationsGranted,
            () => _requestPermission(Permission.notification),
          ),
          _permissionTile(
            isDark,
            'Contacts',
            'Look up names and numbers for calls or messages.',
            Icons.contacts_outlined,
            _isContactsGranted,
            () => _requestPermission(Permission.contacts),
          ),
          _permissionTile(
            isDark,
            'Phone & SMS',
            'Place calls and send messages when explicitly requested.',
            Icons.phone_outlined,
            _isPhoneGranted && _isSmsGranted,
            () async {
              await _requestPermission(Permission.phone);
              await _requestPermission(Permission.sms);
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              TextButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: _muted(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _primaryButton(
                'Continue',
                _canProceedToModel
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      )
                    : null,
                dark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelSetupPage(bool isDark) {
    return _pageFrame(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Connect your intelligence',
            style: TextStyle(
              color: _ink(isDark),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a provider and keep its credentials encrypted on this device.',
            style: TextStyle(color: _muted(isDark), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          _sectionLabel('PROVIDER', isDark),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildProviderCard(
                  'deepseek',
                  'DeepSeek',
                  Icons.analytics_outlined,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildProviderCard(
                  'groq',
                  'Groq',
                  Icons.speed_outlined,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildProviderCard(
                  'nvidia',
                  'NVIDIA',
                  Icons.memory_outlined,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildProviderCard(
                  'ollama',
                  'Ollama',
                  Icons.computer_outlined,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildProviderCard(
                  'local',
                  'Local',
                  Icons.dns_outlined,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildProviderCard(
                  'custom',
                  'Custom',
                  Icons.tune_outlined,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_selectedProvider != 'ollama' &&
              _selectedProvider != 'local') ...[
            _buildFormTextField(
              controller: _apiKeyController,
              label: 'API key',
              hint: 'Enter your provider key',
              obscure: _obscureKey,
              isDark: isDark,
              suffix: IconButton(
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted(isDark),
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _buildFormTextField(
            controller: _baseUrlController,
            label: 'API base URL',
            hint: 'https://api.example.com/v1',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildFormTextField(
            controller: _modelController,
            label: 'Model',
            hint: 'Model name',
            isDark: isDark,
            suffix: IconButton(
              icon: _isValidating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.sync_outlined, color: _muted(isDark)),
              onPressed: _isValidating ? null : _fetchModels,
            ),
          ),
          if (_validationError != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
              ),
              child: Text(
                _validationError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: _isValidating
                    ? null
                    : () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: _muted(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _primaryButton(
                _isValidating ? 'Checking…' : 'Finish setup',
                _isValidating ? null : _testAndSave,
                dark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo({required double size, required Color background}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .22),
      ),
      child: Image.asset(
        'assets/app-logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Agent Cypher AC logo',
      ),
    );
  }

  Widget _primaryButton(
    String label,
    VoidCallback? onPressed, {
    required bool dark,
  }) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: enabled
              ? (dark ? const Color(0xFFF7F3EE) : const Color(0xFF1C1917))
              : const Color(0xFF8C857D).withValues(alpha: 0.35),
          foregroundColor: enabled
              ? (dark ? const Color(0xFF1C1917) : const Color(0xFFF7F3EE))
              : const Color(0xFF57534E),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 17),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        color: _muted(isDark),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _chip(String text, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _panel(isDark),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: _muted(isDark),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _infoCard(bool isDark, IconData icon, String title, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink(isDark), size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _ink(isDark),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(color: _muted(isDark), fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _wideInfoCard(bool isDark, IconData icon, String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink(isDark), size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _ink(isDark),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(
                    color: _muted(isDark),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionTile(
    bool isDark,
    String title,
    String description,
    IconData icon,
    bool granted,
    VoidCallback action,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _panel(isDark),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: granted
            ? Colors.green.withValues(alpha: 0.45)
            : _muted(isDark).withValues(alpha: 0.12),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _ink(isDark).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _ink(isDark), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _ink(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: _muted(isDark),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        granted
            ? const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 23,
              )
            : OutlinedButton(
                onPressed: action,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink(isDark),
                  side: BorderSide(color: _ink(isDark).withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
      ],
    ),
  );

  Widget _buildProviderCard(
    String id,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final selected = _selectedProvider == id;
    return GestureDetector(
      onTap: () => _selectProvider(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 104,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? _ink(isDark).withValues(alpha: 0.1)
              : _panel(isDark),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? _ink(isDark)
                : _muted(isDark).withValues(alpha: 0.16),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _ink(isDark), size: 23),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink(isDark),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    required bool isDark,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    style: TextStyle(color: _ink(isDark), fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: _muted(isDark), fontSize: 13),
      hintStyle: TextStyle(
        color: _muted(isDark).withValues(alpha: 0.65),
        fontSize: 13,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: _panel(isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _muted(isDark).withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _muted(isDark).withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _ink(isDark), width: 1.2),
      ),
    ),
  );
}
