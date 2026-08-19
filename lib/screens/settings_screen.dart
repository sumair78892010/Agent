import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/ai_service.dart';
import '../services/provider/provider_manager.dart';
import '../services/provider/provider_configuration.dart';
import '../services/shizuku_service.dart';
import '../services/screen_automation_service.dart';
import '../services/task_telemetry_service.dart';
import '../services/settings_service.dart';
import '../services/diagnostics_service.dart';
import '../services/controlled_upgrade_service.dart';
import '../services/artifact_service.dart';
import '../services/user_memory_service.dart';
import '../services/skill_memory_service.dart';
import '../services/voice_service.dart';
import '../models/saved_skill.dart';
import 'task_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../config/feature_flags.dart';
import '../widgets/unified_task_workspace.dart';

class SettingsScreen extends StatefulWidget {
  final AiService aiService;
  final ShizukuService shizukuService;
  final ScreenAutomationService screenAutomationService;
  final VoiceService voiceService;

  const SettingsScreen({
    super.key,
    required this.aiService,
    required this.shizukuService,
    required this.screenAutomationService,
    required this.voiceService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  bool _obscureKey = true;
  double _maxSteps = 15;
  bool _disableMaxSteps = false;
  late TextEditingController _maxTokensController;
  double _temperature = 1.0;
  bool _useScreenCompression = true;
  bool _useSystemPrompt = true;
  bool _floatingIconEnabled = false;
  bool _isOverlayPermissionGranted = false;
  final ProviderManager _providerManager = ProviderManager();
  List<ProviderConfiguration> _providerConfigurations = const [];
  String _activeProviderId = '';
  final UserMemoryService _userMemoryService = UserMemoryService();
  final SkillMemoryService _skillMemoryService = SkillMemoryService();
  List<MemoryRecord> _memories = const [];
  List<SavedSkill> _savedSkills = const [];
  bool _automaticMemoryEnabled = true;
  bool _memoryLoading = true;
  final SettingsService _settingsService = SettingsService();
  bool _developerModeEnabled = false;
  bool _developerLoading = true;
  bool _developerRefreshing = false;
  String _flutterVersion = 'Unavailable';
  String _androidVersion = 'Unavailable';
  String _appVersion = 'Unavailable';
  Map<String, dynamic> _accessibilityDiagnostics = const {};
  bool _shizukuAvailable = false;
  bool _shizukuPermission = false;
  DateTime? _developerDiagnosticsAt;
  bool _wakeWordEnabled = false;
  bool _wakeWordAvailable = false;
  bool _wakeWordListening = false;
  bool _wakeWordBusy = false;
  StreamSubscription<VoiceEvent>? _voiceEvents;

  final Map<String, PermissionStatus> _permissions = {};
  final ControlledUpgradeService _upgradeService =
      ControlledUpgradeService.shared;
  late TextEditingController _upgradeRepoController;
  late TextEditingController _upgradeProblemController;
  late TextEditingController _upgradeTaskController;
  late TextEditingController _upgradeFilesController;
  bool _upgradeBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiKeyController = TextEditingController(text: widget.aiService.apiKey);
    _baseUrlController = TextEditingController(text: widget.aiService.baseUrl);
    _modelController = TextEditingController(text: widget.aiService.model);
    _maxSteps = widget.aiService.rawMaxSteps.toDouble();
    _disableMaxSteps = widget.aiService.disableMaxSteps;
    _temperature = widget.aiService.temperature;
    _maxTokensController = TextEditingController(
      text: widget.aiService.maxTokens.toString(),
    );
    _upgradeRepoController = TextEditingController(
      text: const String.fromEnvironment('AGENT_CYPHER_REPO'),
    );
    _upgradeProblemController = TextEditingController();
    _upgradeTaskController = TextEditingController();
    _upgradeFilesController = TextEditingController(
      text: 'lib/services/task_executor.dart',
    );
    _useScreenCompression = widget.aiService.useScreenCompression;
    _useSystemPrompt = widget.aiService.useSystemPrompt;

    // Auto-save listeners
    _apiKeyController.addListener(_autoSave);
    _baseUrlController.addListener(_autoSave);
    _modelController.addListener(_autoSave);
    _maxTokensController.addListener(_autoSave);

    _voiceEvents = widget.voiceService.eventStream.listen(_handleVoiceEvent);
    unawaited(_loadWakeWordState());
    _checkPermissions();
    if (FeatureFlags.floatingOverlayEnabled) {
      _checkOverlayStatus();
    }
    _loadProviderConfigurations();
    _loadMemoryState();
    _loadDeveloperMode();
  }

  Future<void> _loadMemoryState() async {
    try {
      final automatic = await _userMemoryService.getAutomaticMemoryEnabled();
      final memories = await _userMemoryService.getMemories();
      final skills = await _skillMemoryService.getSkills();
      if (!mounted) return;
      setState(() {
        _automaticMemoryEnabled = automatic;
        _memories = memories;
        _savedSkills = skills;
        _memoryLoading = false;
      });
    } catch (error) {
      debugPrint('Memory load failed: $error');
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  Future<void> _setAutomaticMemoryEnabled(bool enabled) async {
    await _userMemoryService.setAutomaticMemoryEnabled(enabled);
    if (mounted) setState(() => _automaticMemoryEnabled = enabled);
  }

  Future<void> _deleteMemoryRecord(MemoryRecord record) async {
    await _userMemoryService.deleteMemory(record.id);
    await _loadMemoryState();
  }

  Future<void> _deleteSavedSkill(SavedSkill skill) async {
    await _skillMemoryService.deleteSkill(skill.id);
    await _loadMemoryState();
  }

  Future<void> _clearAllMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all memory?'),
        content: const Text(
          'This removes saved preferences, workflow memories, app preferences, and saved skills. It does not delete chat history or provider credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _userMemoryService.clearAll();
    await _skillMemoryService.clearAll();
    await _loadMemoryState();
  }

  Future<void> _loadDeveloperMode() async {
    try {
      await _settingsService.init();
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _developerModeEnabled = _settingsService.isDeveloperModeEnabled();
        _flutterVersion = 'Flutter ${Platform.version.split(' ').first}';
        _androidVersion = Platform.operatingSystemVersion;
        _appVersion = '${info.version}+${info.buildNumber}';
        _developerLoading = false;
      });
      if (_developerModeEnabled) {
        await _loadUpgradeHistory();
        await _refreshDeveloperDiagnostics();
      }
    } catch (error) {
      debugPrint('Developer Mode load failed: $error');
      if (mounted) setState(() => _developerLoading = false);
    }
  }

  Future<void> _setDeveloperModeEnabled(bool enabled) async {
    await _settingsService.setDeveloperModeEnabled(enabled);
    if (!mounted) return;
    setState(() => _developerModeEnabled = enabled);
    if (enabled) {
      await _loadUpgradeHistory();
      await _refreshDeveloperDiagnostics();
    }
  }

  Future<void> _loadUpgradeHistory() async {
    final repoPath = _upgradeRepoController.text.trim();
    if (repoPath.isEmpty) return;
    await _upgradeService.loadHistory(repoPath);
  }

  Future<void> _refreshDeveloperDiagnostics() async {
    if (_developerRefreshing) return;
    setState(() => _developerRefreshing = true);
    try {
      await _loadUpgradeHistory();
      final accessibility = await widget.screenAutomationService
          .getAccessibilityDiagnostics();
      final shizuku = await widget.shizukuService.checkAvailability();
      if (!mounted) return;
      setState(() {
        _accessibilityDiagnostics = accessibility;
        _shizukuAvailable = shizuku;
        _shizukuPermission = widget.shizukuService.hasPermission;
        _developerDiagnosticsAt = DateTime.now();
        _developerRefreshing = false;
      });
    } catch (error) {
      debugPrint('Developer diagnostics refresh failed: $error');
      if (mounted) setState(() => _developerRefreshing = false);
    }
  }

  Future<void> _exportDeveloperDiagnostics() async {
    final snapshot = TaskTelemetryService.shared.developerState.value;
    final report = DiagnosticsService.buildSanitizedDeveloperReport(
      snapshot: snapshot,
      system: {
        'flutter_version': _flutterVersion,
        'android_version': _androidVersion,
        'app_version': _appVersion,
        'accessibility': _accessibilityDiagnostics,
        'overlay': {'permission_granted': _isOverlayPermissionGranted},
        'shizuku': {
          'available': _shizukuAvailable,
          'permission': _shizukuPermission,
        },
        'permissions': {
          for (final entry in _permissions.entries) entry.key: entry.value.name,
        },
        'provider': {
          'configured': widget.aiService.baseUrl.isNotEmpty,
          'model': widget.aiService.model,
          'endpoint': widget.aiService.baseUrl,
        },
      },
    );
    try {
      await ArtifactService.shared.exportText(
        name: 'agent_cypher_diagnostics.json',
        kind: 'json',
        content: report,
        sourceTask: snapshot.rootGoal,
        validationState: snapshot.upgradeFinalResult.isEmpty
            ? 'diagnostic_exported'
            : snapshot.upgradeFinalResult,
      );
      await const MethodChannel(
        'com.cypherghost.agentcypher/accessibility',
      ).invokeMethod<bool>('shareText', {'text': report});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export diagnostics: $error')),
      );
    }
  }

  Future<void> _loadProviderConfigurations() async {
    try {
      await _providerManager.init();
      if (!mounted) return;
      setState(() {
        _providerConfigurations = _providerManager.configurations;
        _activeProviderId = _providerManager.activeProviderId;
      });
    } catch (error) {
      debugPrint('Provider configuration load failed: $error');
    }
  }

  Future<void> _showProviderEditor({ProviderConfiguration? existing}) async {
    final nameController = TextEditingController(
      text: existing?.name ?? 'OpenAI-compatible',
    );
    final idController = TextEditingController(
      text: existing?.id ?? 'provider_${DateTime.now().millisecondsSinceEpoch}',
    );
    final baseUrlController = TextEditingController(
      text: existing?.baseUrl ?? 'https://api.openai.com/v1',
    );
    final modelController = TextEditingController(text: existing?.model ?? '');
    final keyController = TextEditingController();
    final selected = <String>{
      ...(existing?.capabilities ??
          const [
            ProviderCapabilities.chat,
            ProviderCapabilities.agentReasoning,
          ]),
    };
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Add provider' : 'Edit provider'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(labelText: 'Provider ID'),
                  ),
                  TextField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(labelText: 'Base URL'),
                  ),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'API key'
                          : 'API key (enter to replace)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Capabilities',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: ProviderCapabilities.all
                        .map(
                          (capability) => FilterChip(
                            label: Text(ProviderCapabilities.label(capability)),
                            selected: selected.contains(capability),
                            onSelected: (value) => setDialogState(
                              () => value
                                  ? selected.add(capability)
                                  : selected.remove(capability),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final id = idController.text.trim();
                  final key = keyController.text.trim();
                  final effectiveKey = key.isEmpty && existing != null
                      ? await _providerManager.getProviderApiKey(existing.id) ??
                            ''
                      : key;
                  if (id.isEmpty ||
                      baseUrlController.text.trim().isEmpty ||
                      modelController.text.trim().isEmpty ||
                      selected.isEmpty ||
                      effectiveKey.isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter provider details, an API key, and at least one capability.',
                        ),
                      ),
                    );
                    return;
                  }
                  try {
                    await _providerManager.addOrUpdateProviderConfiguration(
                      configuration: ProviderConfiguration(
                        id: id,
                        name: nameController.text.trim().isEmpty
                            ? id
                            : nameController.text.trim(),
                        baseUrl: baseUrlController.text.trim(),
                        model: modelController.text.trim(),
                        capabilities: selected.toList(),
                      ),
                      apiKey: effectiveKey,
                    );
                    if (mounted) {
                      setState(() {
                        _providerConfigurations =
                            _providerManager.configurations;
                        _activeProviderId = _providerManager.activeProviderId;
                      });
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not save provider: $error'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      idController.dispose();
      baseUrlController.dispose();
      modelController.dispose();
      keyController.dispose();
    }
  }

  Future<void> _checkOverlayStatus() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      final isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!mounted) return;
      setState(() {
        _floatingIconEnabled = isActive;
        _isOverlayPermissionGranted = isGranted;
      });
    } catch (error) {
      debugPrint('Overlay status check failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.removeListener(_autoSave);
    _baseUrlController.removeListener(_autoSave);
    _modelController.removeListener(_autoSave);
    _maxTokensController.removeListener(_autoSave);
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _maxTokensController.dispose();
    _upgradeRepoController.dispose();
    _upgradeProblemController.dispose();
    _upgradeTaskController.dispose();
    _upgradeFilesController.dispose();
    unawaited(_voiceEvents?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      if (FeatureFlags.floatingOverlayEnabled) {
        _checkOverlayStatus();
      }
    }
  }

  Future<void> _checkPermissions() async {
    final perms = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    try {
      for (final entry in perms.entries) {
        _permissions[entry.key] = await entry.value.status;
      }
      final overlayGranted = FeatureFlags.floatingOverlayEnabled
          ? await FlutterOverlayWindow.isPermissionGranted()
          : false;
      if (!mounted) return;
      setState(() {
        _isOverlayPermissionGranted = overlayGranted;
      });
    } catch (error) {
      debugPrint('Permission status check failed: $error');
    }
  }

  Future<void> _loadWakeWordState() async {
    try {
      await _settingsService.init();
      if (!mounted) return;
      setState(() {
        _wakeWordEnabled = _settingsService.isWakeWordEnabled();
        _wakeWordAvailable = widget.voiceService.wakeWordAvailable;
        _wakeWordListening = widget.voiceService.wakeWordListening;
      });
    } catch (error) {
      debugPrint('Wake-word state load failed: $error');
    }
  }

  void _handleVoiceEvent(VoiceEvent event) {
    if (!mounted) return;
    if (event.wakeWordAvailable != null ||
        event.wakeWordEnabled != null ||
        event.wakeWordListening != null) {
      setState(() {
        if (event.wakeWordAvailable != null) {
          _wakeWordAvailable = event.wakeWordAvailable!;
        }
        if (event.wakeWordEnabled != null) {
          _wakeWordEnabled = event.wakeWordEnabled!;
        }
        if (event.wakeWordListening != null) {
          _wakeWordListening = event.wakeWordListening!;
        }
      });
    }
  }

  Future<void> _setWakeWordEnabled(bool enabled) async {
    if (_wakeWordBusy) return;
    setState(() => _wakeWordBusy = true);
    try {
      if (!enabled) {
        await widget.voiceService.stopWakeWordMode();
        await _settingsService.setWakeWordEnabled(false);
        if (mounted) setState(() => _wakeWordEnabled = false);
        return;
      }

      var microphone = await Permission.microphone.status;
      if (!microphone.isGranted) {
        microphone = await Permission.microphone.request();
      }
      if (!microphone.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required for Hey Cypher.',
              ),
            ),
          );
          setState(() => _wakeWordEnabled = false);
        }
        return;
      }

      final started = await widget.voiceService.startWakeWordMode();
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hey Cypher is unavailable on this device or speech service.',
              ),
            ),
          );
          setState(() => _wakeWordEnabled = false);
        }
        return;
      }

      await _settingsService.setWakeWordEnabled(true);
      if (mounted) {
        setState(() {
          _wakeWordEnabled = true;
          _wakeWordAvailable = true;
        });
      }
    } catch (error) {
      debugPrint('Wake-word toggle failed: $error');
      if (mounted) {
        setState(() => _wakeWordEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change Hey Cypher: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _wakeWordBusy = false);
    }
  }

  Widget _buildWakeWordTile() {
    final status = !_wakeWordAvailable
        ? 'Unavailable: Android speech recognition is not ready.'
        : _wakeWordListening
        ? 'Listening for Hey Cypher in the background.'
        : _wakeWordEnabled
        ? 'Enabled; waiting for the background service.'
        : 'Ready but disabled.';
    return SwitchListTile.adaptive(
      secondary: Icon(
        _wakeWordListening ? Icons.hearing_rounded : Icons.hearing_disabled,
        color: _wakeWordAvailable ? null : Colors.grey,
      ),
      title: const Text('Hey Cypher wake phrase'),
      subtitle: Text(
        '$status\nAndroid shows a microphone notification while enabled.',
      ),
      value: _wakeWordEnabled,
      onChanged: _wakeWordBusy || (!_wakeWordAvailable && !_wakeWordEnabled)
          ? null
          : _setWakeWordEnabled,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _requestPermission(String name, Permission permission) async {
    try {
      final status = await permission.request();
      if (!mounted) return;
      setState(() => _permissions[name] = status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request $name permission: $error')),
      );
    }
  }

  void _autoSave() {
    widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );

    widget.aiService.saveMaxSteps(_maxSteps.toInt());
    widget.aiService.saveDisableMaxSteps(_disableMaxSteps);
    widget.aiService.saveAdvancedSettings(
      temperature: _temperature,
      maxTokens: int.tryParse(_maxTokensController.text) ?? 1024,
      useScreenCompression: _useScreenCompression,
      useSystemPrompt: _useSystemPrompt,
    );
  }

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Base URL and API Key first.'),
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final models = await widget.aiService.fetchAvailableModels(baseUrl, apiKey);

    // Hide loading
    if (mounted) Navigator.pop(context);

    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No models found or error fetching models.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      final isNvidia = AiService.isNvidiaBaseUrl(baseUrl);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isNvidia ? 'Select a Free NVIDIA Model' : 'Select a Model',
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(models[index]),
                  onTap: () {
                    setState(() {
                      _modelController.text = models[index];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.8,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryManager() {
    if (_memoryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasMemories = _memories.isNotEmpty || _savedSkills.isNotEmpty;
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatic memory'),
          subtitle: Text(
            _automaticMemoryEnabled
                ? 'Use approved memories when relevant in enabled conversations.'
                : 'New memories are not used by the chat pipeline.',
          ),
          value: _automaticMemoryEnabled,
          onChanged: _setAutomaticMemoryEnabled,
        ),
        const Divider(),
        if (!hasMemories)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.memory_outlined),
            title: Text('No saved memories'),
            subtitle: Text(
              'Memories appear here only when explicitly saved through the existing memory services.',
            ),
          ),
        ..._memories.map(
          (record) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline_rounded),
            title: Text(record.value),
            subtitle: Text(
              '${record.category.toUpperCase()}\nWhy saved: ${record.reason}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Delete memory',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _deleteMemoryRecord(record),
            ),
          ),
        ),
        ..._savedSkills.map(
          (skill) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_motion_outlined),
            title: Text(skill.task),
            subtitle: Text(
              'SAVED SKILL • ${skill.steps.length} steps • ${skill.successCount} successes\nWhy saved: Reusable workflow recorded by SkillMemoryService.',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Delete saved skill',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _deleteSavedSkill(skill),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: hasMemories ? _clearAllMemory : null,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear all memories and saved skills'),
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sensitive values such as API keys, passwords, tokens, and credentials are rejected before persistence and are never shown here.',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilityAvailabilityTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Chip(label: Text('Existing runtime')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _buildCategoryHeader(
            title: 'GENERAL',
            subtitle: 'Appearance, branding, language, and app behavior',
            icon: Icons.tune_rounded,
          ),
          // Appearance and theme use the live app-level themeNotifier.
          _buildSettingsCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Choose your preferred color theme',
            isDark: isDark,
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: const Text(
                            'System',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.brightness_auto, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: const Text(
                            'Light',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.light_mode, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: const Text(
                            'Dark',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.dark_mode, size: 16),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) async {
                        final mode = newSelection.first;
                        themeNotifier.value = mode;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('themeMode', mode.name);
                      },
                    ),
                  );
                },
              ),
            ],
          ),

          _buildSettingsCard(
            icon: Icons.tune_outlined,
            title: 'App behavior',
            subtitle:
                'Current runtime defaults for language, haptics, and notifications',
            isDark: isDark,
            children: [
              _buildCapabilityAvailabilityTile(
                icon: Icons.language_rounded,
                title: 'Language',
                description: 'The app currently follows the device language.',
              ),
              _buildCapabilityAvailabilityTile(
                icon: Icons.vibration_rounded,
                title: 'Haptic feedback',
                description: 'Uses platform/runtime defaults where supported.',
              ),
              _buildCapabilityAvailabilityTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                description:
                    'Notification permission and delivery are managed by Android.',
              ),
            ],
          ),

          _buildCategoryHeader(
            title: 'AI',
            subtitle:
                'Provider, model, credentials, routing, and generation limits',
            icon: Icons.psychology_rounded,
          ),
          // AI configuration remains backed by AiService and ProviderManager.
          _buildSettingsCard(
            icon: Icons.psychology_outlined,
            title: 'AI Engine Configuration',
            subtitle: 'Supports any OpenAI-compatible API endpoint',
            isDark: isDark,
            children: [
              TextField(
                controller: _apiKeyController,
                decoration: _buildInputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                obscureText: _obscureKey,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                decoration: _buildInputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.deepseek.com',
                  prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text(
                      'Local Server',
                      style: TextStyle(fontSize: 11),
                    ),
                    tooltip: 'For local Llama.cpp or LM Studio',
                    onPressed: () =>
                        _baseUrlController.text = 'http://192.168.1.X:8080/v1',
                  ),
                  ActionChip(
                    label: const Text(
                      'Ollama Cloud',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      _baseUrlController.text = 'https://ollama.com/v1';
                      _modelController.text = 'gemma3:4b';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'DeepSeek',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () =>
                        _baseUrlController.text = 'https://api.deepseek.com',
                  ),
                  ActionChip(
                    label: const Text('Groq', style: TextStyle(fontSize: 11)),
                    onPressed: () => _baseUrlController.text =
                        'https://api.groq.com/openai/v1',
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.memory_rounded, size: 16),
                    label: const Text('NVIDIA', style: TextStyle(fontSize: 11)),
                    tooltip: 'NVIDIA NIM free endpoints',
                    onPressed: () {
                      _baseUrlController.text = AiService.nvidiaBaseUrl;
                      _modelController.text = AiService.nvidiaDefaultModel;
                    },
                  ),
                  ActionChip(
                    label: const Text('Custom', style: TextStyle(fontSize: 11)),
                    tooltip: 'Clear fields',
                    onPressed: () {
                      _baseUrlController.clear();
                      _apiKeyController.clear();
                      _modelController.clear();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: _buildInputDecoration(
                        labelText: 'Model',
                        hintText: 'deepseek-chat',
                        prefixIcon: const Icon(
                          Icons.smart_toy_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _fetchModels,
                    icon: const Icon(
                      Icons.cloud_download,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Fetch',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          _buildSettingsCard(
            icon: Icons.alt_route_rounded,
            title: 'Capability Routing',
            subtitle: 'Use the current model first, then compatible fallbacks',
            isDark: isDark,
            children: [
              if (_providerConfigurations.isEmpty)
                const Text(
                  'No capability profiles yet. Existing settings remain active; add a profile to enable image generation or other specialized capabilities.',
                ),
              ..._providerConfigurations.map(
                (configuration) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${configuration.name} · ${configuration.model}'),
                  subtitle: Text(
                    configuration.capabilities
                        .map(ProviderCapabilities.label)
                        .join(', '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showProviderEditor(existing: configuration),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _providerManager.deleteProvider(
                            configuration.id,
                          );
                          if (mounted) {
                            setState(() {
                              _providerConfigurations =
                                  _providerManager.configurations;
                              _activeProviderId =
                                  _providerManager.activeProviderId;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_providerConfigurations.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue:
                      _providerConfigurations.any(
                        (configuration) =>
                            configuration.id == _activeProviderId,
                      )
                      ? _activeProviderId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Active provider',
                    helperText:
                        'Chat and agent requests use the compatible active profile first.',
                  ),
                  items: _providerConfigurations
                      .map(
                        (configuration) => DropdownMenuItem<String>(
                          value: configuration.id,
                          child: Text(
                            '${configuration.name} · ${configuration.model}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (providerId) async {
                    if (providerId == null) return;
                    await _providerManager.setActiveProvider(providerId);
                    if (mounted) setState(() => _activeProviderId = providerId);
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _showProviderEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add provider capability profile'),
                ),
              ),
            ],
          ),

          _buildSettingsCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Capability surface',
            subtitle:
                'Capabilities are selected through the existing provider profiles',
            isDark: isDark,
            children: [
              _buildCapabilityAvailabilityTile(
                icon: Icons.stream_rounded,
                title: 'Streaming',
                description: 'Enabled by the current chat request pipeline.',
              ),
              _buildCapabilityAvailabilityTile(
                icon: Icons.visibility_rounded,
                title: 'Vision and tool use',
                description:
                    'Available only when the active provider profile advertises support.',
              ),
            ],
          ),

          // Parameters are part of the AI category and persist through AiService.
          _buildSettingsCard(
            icon: Icons.tune_outlined,
            title: 'Tuning & Boundaries',
            subtitle: 'Configure LLM agent parameters',
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Disable Maximum Steps'),
                subtitle: const Text(
                  '⚠️ Can cause infinite loops.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                value: _disableMaxSteps,
                onChanged: (bool value) {
                  setState(() {
                    _disableMaxSteps = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (!_disableMaxSteps) ...[
                const SizedBox(height: 8),
                Text(
                  'Maximum Steps Per Task: ${_maxSteps.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Slider(
                  value: _maxSteps,
                  min: 5,
                  max: 50,
                  divisions: 45,
                  label: _maxSteps.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _maxSteps = value;
                    });
                  },
                  onChangeEnd: (value) {
                    _autoSave();
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _maxTokensController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  labelText: 'Context Limit (Max Tokens)',
                  hintText: '1024',
                  prefixIcon: const Icon(Icons.token_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Temperature: ${_temperature.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Slider(
                value: _temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                label: _temperature.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    _temperature = value;
                  });
                },
                onChangeEnd: (value) {
                  _autoSave();
                },
              ),
            ],
          ),

          _buildCategoryHeader(
            title: 'AGENT',
            subtitle:
                'Execution boundaries, context handling, verification, and recovery',
            icon: Icons.smart_toy_rounded,
          ),
          // Agent behavior uses existing AiService and task-execution settings.
          _buildSettingsCard(
            icon: Icons.extension_outlined,
            title: 'Behavior & Extensions',
            subtitle: 'Additional feature flags and overlay options',
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Use Screen Compression'),
                subtitle: const Text(
                  'Removes duplicate elements to save tokens',
                ),
                value: _useScreenCompression,
                onChanged: (bool value) {
                  setState(() {
                    _useScreenCompression = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Send System Prompt'),
                subtitle: const Text('Turn off for custom LoRA fine-tunes'),
                value: _useSystemPrompt,
                onChanged: (bool value) {
                  setState(() {
                    _useSystemPrompt = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (FeatureFlags.floatingOverlayEnabled)
                SwitchListTile(
                  title: const Text('Enable Floating Agent Icon'),
                  subtitle: const Text('Assign tasks without opening the app'),
                  value: _floatingIconEnabled,
                  onChanged: (val) async {
                    if (val) {
                      bool? isGranted =
                          await FlutterOverlayWindow.isPermissionGranted();
                      if (isGranted != true) {
                        final result = await _requestOverlayPermission();
                        if (result != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Permission to draw over other apps is required.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                      }
                      if (await FlutterOverlayWindow.isActive() == false) {
                        await FlutterOverlayWindow.showOverlay(
                          enableDrag: true,
                          overlayTitle: "Agent Cypher",
                          overlayContent: "Floating Assistant",
                          flag: OverlayFlag.focusPointer,
                          alignment: OverlayAlignment.centerRight,
                          visibility: NotificationVisibility.visibilitySecret,
                          positionGravity: PositionGravity.auto,
                          startPosition: const OverlayPosition(0, 200),
                          width: 56,
                          height: 56,
                        );
                      }
                    } else {
                      if (await FlutterOverlayWindow.isActive() == true) {
                        await FlutterOverlayWindow.closeOverlay();
                      }
                    }
                    setState(() => _floatingIconEnabled = val);
                    _autoSave();
                  },
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),

          _buildCategoryHeader(
            title: 'VOICE',
            subtitle:
                'Speech recognition and text-to-speech runtime capabilities',
            icon: Icons.mic_none_rounded,
          ),
          _buildSettingsCard(
            icon: Icons.record_voice_over_rounded,
            title: 'Voice runtime',
            subtitle:
                'Voice actions remain connected to the existing VoiceService',
            isDark: isDark,
            children: [
              _buildCapabilityAvailabilityTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Speech recognition',
                description:
                    'Available from the chat composer microphone action.',
              ),
              _buildCapabilityAvailabilityTile(
                icon: Icons.volume_up_rounded,
                title: 'Text-to-speech',
                description:
                    'Available through the existing voice response runtime.',
              ),
              _buildWakeWordTile(),
            ],
          ),

          _buildCategoryHeader(
            title: 'AUTOMATION',
            subtitle:
                'Accessibility, overlay, Shizuku, and Android permissions',
            icon: Icons.touch_app_rounded,
          ),
          // Accessibility Screen Control Card
          _buildSettingsCard(
            icon: Icons.visibility_outlined,
            title: 'Screen Control (Accessibility)',
            subtitle: 'Required to read screen and perform automated clicks',
            isDark: isDark,
            children: [_buildAccessibilityCard()],
          ),

          // 7. Shizuku bridge card
          _buildSettingsCard(
            icon: Icons.terminal_rounded,
            title: 'Shizuku bridge',
            subtitle:
                'Optional privileged commands through user-approved Shizuku',
            isDark: isDark,
            children: [_buildShizukuCard()],
          ),

          // 8. System Permissions Card
          _buildSettingsCard(
            icon: Icons.security_outlined,
            title: 'App Permissions',
            subtitle: 'Required for automation, microphone, and contacts',
            isDark: isDark,
            children: _buildPermissionTiles(),
          ),

          _buildCategoryHeader(
            title: 'PRIVACY',
            subtitle:
                'History, credentials, telemetry, and diagnostic visibility',
            icon: Icons.shield_outlined,
          ),
          _buildSettingsCard(
            icon: Icons.lock_outline_rounded,
            title: 'Data and credentials',
            subtitle:
                'Privacy controls use existing storage and diagnostic services',
            isDark: isDark,
            children: [
              _buildCapabilityAvailabilityTile(
                icon: Icons.key_outlined,
                title: 'Credential management',
                description:
                    'Provider keys remain in the existing secure credential path.',
              ),
              _buildMemoryManager(),
              _buildCapabilityAvailabilityTile(
                icon: Icons.history_rounded,
                title: 'Chat history',
                description:
                    'Conversation persistence remains controlled by ChatHistoryService and is separate from editable memories.',
              ),
              _buildCapabilityAvailabilityTile(
                icon: Icons.analytics_outlined,
                title: 'Telemetry and diagnostic data',
                description:
                    'Developer diagnostics are privacy-sanitized by the existing services.',
              ),
            ],
          ),
          // Task history is the existing persisted execution-log surface.
          _buildSettingsCard(
            icon: Icons.history_outlined,
            title: 'Execution logs',
            subtitle: 'View history of tasks and token analytics',
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('View Task History'),
                subtitle: const Text(
                  'Access complete trace of execution steps',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TaskHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          _buildCategoryHeader(
            title: 'DEVELOPER',
            subtitle:
                'Live execution diagnostics and controlled self-development tools',
            icon: Icons.developer_mode_rounded,
          ),
          // Live Developer Mode Card
          _buildSettingsCard(
            icon: Icons.developer_mode_outlined,
            title: 'Developer Mode',
            subtitle: 'Live, privacy-sanitized task execution diagnostics',
            isDark: isDark,
            children: [_buildDeveloperModeCard()],
          ),

          _buildCategoryHeader(
            title: 'ABOUT',
            subtitle: 'Version, build information, credits, and project links',
            icon: Icons.info_outline_rounded,
          ),
          // About / Links Card
          _buildSettingsCard(
            icon: Icons.info_outline_rounded,
            title: 'About Agent Cypher',
            subtitle: 'Version 1.0.0 - An Assistant for Sumair',
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Project Repository'),
                subtitle: const Text('View source code on GitHub'),
                leading: const Icon(Icons.code_rounded),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/cypherghost/agent-cypher'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Made by Sumair (Cypher Ghost)'),
                subtitle: const Text('Personal AI assistant - Open Source'),
                leading: const Icon(Icons.person_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _identifyUpgrade() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.identifyAndPropose(
        repoPath: _upgradeRepoController.text.trim(),
        problem: _upgradeProblemController.text,
        task: _upgradeTaskController.text,
        allowedFiles: _upgradeFilesController.text
            .split(RegExp(r'[,\n]'))
            .map((file) => file.trim())
            .where((file) => file.isNotEmpty)
            .toList(),
      );
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _applyUpgrade() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.applyValidateAndKeepOrRollback();
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _prepareNextUpgradeStage() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.prepareNextStage();
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _rollbackUpgrade() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.rollbackLastChange();
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _undoMultipleChanges() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.undoChanges(2);
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _rollbackToCheckpoint(UpgradeHistoryEntry checkpoint) async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.rollbackTo(checkpoint.id);
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Future<void> _restoreLastKnownWorking() async {
    if (_upgradeBusy) return;
    setState(() => _upgradeBusy = true);
    try {
      await _upgradeService.restoreLastKnownWorking();
    } finally {
      if (mounted) setState(() => _upgradeBusy = false);
    }
  }

  Widget _buildControlledUpgradePanel(
    TaskDeveloperSnapshot snapshot,
    BuildContext context,
  ) {
    final inputDecoration = InputDecoration(
      isDense: true,
      border: const OutlineInputBorder(),
      labelStyle: Theme.of(context).textTheme.bodySmall,
    );
    Widget upgradeRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text(value.isEmpty ? '—' : value)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Controlled self-upgrade',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Development-only: IDENTIFY → PROPOSE → REVIEW → APPLY → VALIDATE. A failed validation is rolled back automatically.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _upgradeRepoController,
          decoration: inputDecoration.copyWith(
            labelText: 'Existing project root',
            hintText: '/path/to/agent-cypher project',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _upgradeProblemController,
          decoration: inputDecoration.copyWith(
            labelText: 'Problem to investigate',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _upgradeTaskController,
          maxLines: 2,
          decoration: inputDecoration.copyWith(labelText: 'Proposed task'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _upgradeFilesController,
          maxLines: 2,
          decoration: inputDecoration.copyWith(
            labelText: 'Allowed existing files',
            hintText: 'One relative path per line',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _upgradeBusy ? null : _identifyUpgrade,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Propose change'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _upgradeBusy || !snapshot.upgradeCanApply
                  ? null
                  : _applyUpgrade,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Apply & validate'),
            ),
            if (snapshot.upgradePlan != null &&
                snapshot.upgradePlan!.status == 'stage_validated')
              OutlinedButton.icon(
                onPressed: _upgradeBusy ? null : _prepareNextUpgradeStage,
                icon: const Icon(Icons.navigate_next_rounded),
                label: const Text('Prepare next stage'),
              ),
          ],
        ),
        if (snapshot.upgradePlan != null) ...[
          const SizedBox(height: 10),
          Text(
            'Implementation plan',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Stages are dependency-aware and bounded. Each patch must be reviewed and validated before the next stage is prepared.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          ...snapshot.upgradePlan!.stages.asMap().entries.map((entry) {
            final stage = entry.value;
            final marker = entry.key == snapshot.upgradePlan!.currentStageIndex
                ? '→ '
                : '';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                stage.status == 'validated' || stage.status == 'completed'
                    ? Icons.check_circle_outline_rounded
                    : stage.status == 'failed' || stage.status == 'blocked'
                    ? Icons.error_outline_rounded
                    : stage.status == 'awaiting_approval'
                    ? Icons.rate_review_outlined
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text('$marker${entry.key + 1}. ${stage.title}'),
              subtitle: Text(
                '${stage.status} • ${stage.files.isEmpty ? 'No direct file patch' : stage.files.join(', ')}${stage.error.isEmpty ? '' : '\\nError: ${stage.error}'}',
              ),
            );
          }),
          Text(
            'Selected tests: ${snapshot.upgradePlan!.selectedTests.isEmpty ? 'none found' : snapshot.upgradePlan!.selectedTests.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text('Undo Changes', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Every applied edit is checkpointed before modification. Checkpoints contain the actual previous source state and are retained until a newer state is validated.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _upgradeBusy || snapshot.upgradeHistory.isEmpty
                  ? null
                  : _rollbackUpgrade,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Undo latest'),
            ),
            OutlinedButton.icon(
              onPressed: _upgradeBusy || snapshot.upgradeHistory.length < 2
                  ? null
                  : _undoMultipleChanges,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Undo 2 changes'),
            ),
            OutlinedButton.icon(
              onPressed: _upgradeBusy || snapshot.upgradeHistory.isEmpty
                  ? null
                  : _restoreLastKnownWorking,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore working state'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (snapshot.upgradeHistory.isEmpty)
          Text(
            'No source checkpoints yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...snapshot.upgradeHistory.reversed.map(
            (checkpoint) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ExpansionTile(
                dense: true,
                leading: Icon(
                  checkpoint.status == 'validated'
                      ? Icons.verified_rounded
                      : checkpoint.status == 'undone'
                      ? Icons.undo_rounded
                      : Icons.pending_actions_rounded,
                ),
                title: Text(checkpoint.changeSummary),
                subtitle: Text(
                  '${checkpoint.status} • ${checkpoint.createdAt.toLocal().toIso8601String()}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Files: ${checkpoint.files.join(', ')}'),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Validation: ${checkpoint.validationEvidence}'),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Result: ${checkpoint.finalResult}'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _upgradeBusy
                          ? null
                          : () => _rollbackToCheckpoint(checkpoint),
                      icon: const Icon(Icons.restore_page_rounded),
                      label: const Text('Restore this source state'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        upgradeRow('Upgrade stage', snapshot.upgradeStage),
        upgradeRow('Problem', snapshot.upgradeProblem),
        upgradeRow('Files', snapshot.upgradeFiles),
        upgradeRow('Reason', snapshot.upgradeReason),
        upgradeRow('Evidence', snapshot.upgradeEvidence),
        upgradeRow('Final result', snapshot.upgradeFinalResult),
        Text(
          'The worker may propose only one exact patch to an explicitly allowed existing file. It cannot create, delete, or silently modify unrelated files. Credentials and tokens are redacted.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDeveloperModeCard() {
    return ValueListenableBuilder<TaskDeveloperSnapshot>(
      valueListenable: TaskTelemetryService.shared.developerState,
      builder: (context, snapshot, _) {
        Widget diagnosticRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(child: Text(value.isEmpty ? '—' : value)),
              ],
            ),
          );
        }

        Widget sectionTitle(String title, IconData icon) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          );
        }

        final confidence = snapshot.confidence == null
            ? '—'
            : '${(snapshot.confidence! * 100).toStringAsFixed(0)}%';
        final lastObservation =
            _accessibilityDiagnostics['last_observation_at']?.toString() ?? '—';
        final providerConfigured = widget.aiService.isConfigured;
        final providerLatency =
            snapshot.actionTimings['ai_request'] ??
            snapshot.actionTimings['ai_response'];
        final providerCapabilities = _providerConfigurations.isEmpty
            ? 'No provider capability metadata loaded'
            : _providerConfigurations
                  .expand((configuration) => configuration.capabilities)
                  .toSet()
                  .join(', ');

        if (_developerLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        if (!_developerModeEnabled) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Developer Mode'),
                subtitle: const Text(
                  'Disabled by default. Shows live, privacy-sanitized diagnostics only when explicitly enabled.',
                ),
                value: false,
                onChanged: _setDeveloperModeEnabled,
              ),
              const Text(
                'Developer Mode does not expose API keys, credentials, private tokens, or hidden model reasoning.',
              ),
            ],
          );
        }

        final errors = snapshot.errors.isEmpty
            ? 'None'
            : snapshot.errors.take(5).join('\n');
        final eventWidgets = snapshot.events.isEmpty
            ? [const Text('No live execution events recorded yet.')]
            : snapshot.events.reversed
                  .take(8)
                  .map(
                    (event) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bolt_outlined, size: 18),
                      title: Text(event.stage),
                      subtitle: Text(event.detail),
                      trailing: Text(
                        '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  )
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Developer Mode enabled'),
              subtitle: const Text(
                'Live events and diagnostics are privacy-sanitized and sourced from the actual execution pipeline.',
              ),
              value: true,
              onChanged: _setDeveloperModeEnabled,
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _developerRefreshing
                      ? null
                      : _refreshDeveloperDiagnostics,
                  icon: _developerRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _exportDeveloperDiagnostics,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Export sanitized report'),
                ),
              ],
            ),
            if (_developerDiagnosticsAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Last system refresh: ${_developerDiagnosticsAt!.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            sectionTitle('System diagnostics', Icons.phone_android_rounded),
            diagnosticRow('Flutter', _flutterVersion),
            diagnosticRow('Android', _androidVersion),
            diagnosticRow('App version', _appVersion),
            diagnosticRow(
              'Accessibility',
              (_accessibilityDiagnostics['service_enabled'] == true)
                  ? 'Enabled'
                  : 'Disabled',
            ),
            diagnosticRow(
              'Overlay',
              _isOverlayPermissionGranted ? 'Granted' : 'Unavailable',
            ),
            diagnosticRow(
              'Shizuku',
              _shizukuAvailable
                  ? (_shizukuPermission
                        ? 'Running / permitted'
                        : 'Running / permission missing')
                  : 'Unavailable',
            ),
            diagnosticRow(
              'Microphone',
              _permissions["Microphone"]?.name ?? 'Unknown',
            ),
            diagnosticRow(
              'Notifications',
              _permissions['Notifications']?.name ?? 'Unknown',
            ),
            diagnosticRow(
              'Provider',
              providerConfigured ? 'Configured' : 'Not configured',
            ),
            sectionTitle('Agent diagnostics', Icons.smart_toy_outlined),
            diagnosticRow('Current task', snapshot.rootGoal),
            diagnosticRow('Current stage', snapshot.executionStage),
            diagnosticRow('Current step', snapshot.currentSubGoal),
            diagnosticRow('Action count', '${snapshot.actionCount}'),
            diagnosticRow(
              'Observation count',
              '${snapshot.screenObservations}',
            ),
            diagnosticRow('AI call count', '${snapshot.aiCalls}'),
            diagnosticRow('Retry count', '${snapshot.recoveryAttempts}'),
            diagnosticRow('Recovery count', '${snapshot.recoveryAttempts}'),
            diagnosticRow('Verification', snapshot.verificationResult),
            diagnosticRow(
              'Total task duration',
              snapshot.totalTaskDurationMs == 0
                  ? (snapshot.isRunning ? 'Running' : '—')
                  : '${snapshot.totalTaskDurationMs} ms',
            ),
            diagnosticRow('Confidence', confidence),
            sectionTitle('Provider diagnostics', Icons.cloud_outlined),
            diagnosticRow(
              'Configured provider',
              providerConfigured ? 'Existing AiService configuration' : 'None',
            ),
            diagnosticRow('Model', widget.aiService.model),
            diagnosticRow(
              'Endpoint status',
              providerConfigured
                  ? 'Configured; live connectivity not probed'
                  : 'Not configured',
            ),
            diagnosticRow('Capabilities', providerCapabilities),
            diagnosticRow(
              'Latency',
              providerLatency == null ? 'Not measured' : '$providerLatency ms',
            ),
            sectionTitle(
              'Accessibility diagnostics',
              Icons.accessibility_new_rounded,
            ),
            diagnosticRow(
              'Service installed',
              _accessibilityDiagnostics['service_installed'] == true
                  ? 'Yes'
                  : 'Unknown',
            ),
            diagnosticRow(
              'Service enabled',
              _accessibilityDiagnostics['service_enabled'] == true
                  ? 'Yes'
                  : 'No',
            ),
            diagnosticRow(
              'Service responding',
              _accessibilityDiagnostics['service_responding'] == true
                  ? 'Yes'
                  : 'No',
            ),
            diagnosticRow(
              'Current package',
              _accessibilityDiagnostics['current_package']?.toString() ?? '—',
            ),
            diagnosticRow(
              'Node count',
              _accessibilityDiagnostics['node_count']?.toString() ?? '0',
            ),
            diagnosticRow('Last observation', lastObservation),
            sectionTitle(
              'Live execution monitor',
              Icons.monitor_heart_outlined,
            ),
            Text(
              snapshot.isRunning
                  ? 'Live task telemetry'
                  : 'No task currently running',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ...eventWidgets,
            const UnifiedTaskWorkspace(),
            sectionTitle('Terminal / Workspace', Icons.terminal_rounded),
            Text(
              'Shows real commands executed by the controlled development workflow. Arbitrary shell execution is not exposed here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            if (snapshot.workspaceCommands.isEmpty)
              const Text('No workspace commands recorded yet.')
            else
              ...snapshot.workspaceCommands.reversed
                  .take(8)
                  .map(
                    (command) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ExpansionTile(
                        dense: true,
                        leading: Icon(
                          command.succeeded
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: command.succeeded ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          command.command,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'exit ${command.exitCode} • ${command.elapsedMs} ms • ${command.workingDirectory}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              command.output.isEmpty
                                  ? 'No command output.'
                                  : command.output,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            sectionTitle(
              'Workspace Files & Artifacts',
              Icons.folder_open_rounded,
            ),
            Text(
              'Controlled project context from the active upgrade plan. Only explicitly allowed existing files are shown; no source is silently created or deleted.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            if (snapshot.upgradePlan == null)
              const Text('No active workspace plan.')
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      diagnosticRow(
                        'Plan status',
                        snapshot.upgradePlan!.status,
                      ),
                      diagnosticRow(
                        'Rollback checkpoints',
                        snapshot.upgradeHistory.isEmpty
                            ? 'None recorded'
                            : '${snapshot.upgradeHistory.length} checkpoint(s) available in Undo Changes',
                      ),
                      diagnosticRow('Request', snapshot.upgradePlan!.request),
                      diagnosticRow(
                        'Current stage',
                        '${snapshot.upgradePlan!.currentStageIndex + 1} / ${snapshot.upgradePlan!.stages.length}',
                      ),
                      diagnosticRow(
                        'Selected tests',
                        snapshot.upgradePlan!.selectedTests.isEmpty
                            ? 'None selected'
                            : snapshot.upgradePlan!.selectedTests.join(', '),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Impacted files',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      if (snapshot.upgradePlan!.impactedFiles.isEmpty)
                        const Text('No impacted files recorded.')
                      else
                        ...snapshot.upgradePlan!.impactedFiles.map(
                          (file) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: SelectableText(file),
                            subtitle: Text(
                              snapshot
                                          .upgradePlan!
                                          .dependencies[file]
                                          ?.isEmpty ??
                                      true
                                  ? 'No known dependency edges'
                                  : 'Depends on: ${snapshot.upgradePlan!.dependencies[file]!.join(', ')}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ...snapshot.upgradePlan!.stages.asMap().entries.map((entry) {
                final stage = entry.value;
                final active =
                    entry.key == snapshot.upgradePlan!.currentStageIndex;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ExpansionTile(
                    dense: true,
                    leading: Icon(
                      stage.status == 'validated' || stage.status == 'completed'
                          ? Icons.verified_outlined
                          : stage.status == 'failed' ||
                                stage.status == 'blocked'
                          ? Icons.error_outline_rounded
                          : active
                          ? Icons.play_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    title: Text('${entry.key + 1}. ${stage.title}'),
                    subtitle: Text(
                      '${stage.status} • ${stage.files.length} file(s)',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Expected result: ${stage.expectedResult}'),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Files: ${stage.files.isEmpty ? 'None' : stage.files.join(', ')}',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tests: ${stage.selectedTests.isEmpty ? 'None' : stage.selectedTests.join(', ')}',
                        ),
                      ),
                      if (stage.error.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Error: ${stage.error}'),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            sectionTitle('Error inspector', Icons.error_outline_rounded),
            diagnosticRow('Error category', snapshot.failureCategory),
            diagnosticRow('Affected subsystem', snapshot.diagnosisLikelyCause),
            diagnosticRow(
              'Timestamp',
              snapshot.lastEventAt?.toLocal().toString() ?? '—',
            ),
            diagnosticRow(
              'Recoverability',
              snapshot.recoveryAttempts < 5
                  ? 'Bounded recovery available'
                  : 'Recovery limit reached',
            ),
            diagnosticRow(
              'Suggested action',
              snapshot.diagnosisFinalResult.isEmpty
                  ? snapshot.diagnosisEvidence
                  : snapshot.diagnosisFinalResult,
            ),
            diagnosticRow('Detected errors', errors),
            const Divider(height: 18),
            _buildControlledUpgradePanel(snapshot, context),
            const SizedBox(height: 8),
            Text(
              'Secrets, API keys, credentials, passwords, authentication headers, private tokens, and sensitive user content are removed from exported reports.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  Future<bool> _requestOverlayPermission() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
        data: 'package:com.cypherghost.agentcypher',
      );
      await intent.launch();
      return false;
    } catch (_) {
      final fallback = AndroidIntent(
        action: 'android.settings.MANAGE_OVERLAY_PERMISSION',
      );
      await fallback.launch();
      return false;
    }
  }

  List<Widget> _buildPermissionTiles() {
    final permissionMap = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    final icons = {
      'Microphone': Icons.mic,
      'Contacts': Icons.contacts,
      'Phone': Icons.phone,
      'SMS': Icons.sms,
      'Notifications': Icons.notifications,
    };

    final list = permissionMap.entries.map((entry) {
      final status = _permissions[entry.key];
      final isGranted = status?.isGranted ?? false;

      return ListTile(
        leading: Icon(icons[entry.key]),
        title: Text(entry.key),
        trailing: isGranted
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : TextButton(
                onPressed: () => _requestPermission(entry.key, entry.value),
                child: const Text('Grant'),
              ),
        subtitle: Text(
          isGranted
              ? 'Granted'
              : (status?.isDenied ?? true
                    ? 'Not granted'
                    : 'Denied permanently'),
          style: TextStyle(
            color: isGranted
                ? Theme.of(context).colorScheme.primary
                : Colors.orange,
            fontSize: 12,
          ),
        ),
      );
    }).toList();

    if (FeatureFlags.floatingOverlayEnabled) {
      list.add(
        ListTile(
          leading: const Icon(Icons.layers),
          title: const Text('Display Over Other Apps (Floating Bubble)'),
          trailing: _isOverlayPermissionGranted
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              : TextButton(
                  onPressed: () async {
                    await FlutterOverlayWindow.requestPermission();
                    final granted =
                        await FlutterOverlayWindow.isPermissionGranted();
                    setState(() {
                      _isOverlayPermissionGranted = granted;
                    });
                  },
                  child: const Text('Grant'),
                ),
          subtitle: Text(
            _isOverlayPermissionGranted ? 'Granted' : 'Not granted',
            style: TextStyle(
              color: _isOverlayPermissionGranted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return list;
  }

  Widget _buildShizukuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.shizukuService.isAvailable
                      ? Icons.link
                      : Icons.link_off,
                  color: widget.shizukuService.isAvailable
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.shizukuService.isAvailable
                      ? 'Shizuku is running'
                      : 'Shizuku not detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: widget.shizukuService.isAvailable
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!widget.shizukuService.isAvailable) ...[
              const Text(
                '1. Install Shizuku from Play Store\n'
                '2. Open Shizuku and start it via Wireless Debugging\n'
                '3. Come back here and tap "Check Again"',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.checkAvailability();
                  if (mounted) setState(() {});
                },
                child: const Text('Check Again'),
              ),
            ] else if (!widget.shizukuService.hasPermission) ...[
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.requestPermission();
                  if (mounted) setState(() {});
                },
                child: const Text('Grant Shizuku Permission'),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Permission granted — ADB commands available',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return FutureBuilder<bool>(
      future: widget.screenAutomationService.isServiceRunning(),
      builder: (context, snapshot) {
        final isRunning = snapshot.data ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRunning ? Icons.visibility : Icons.visibility_off,
                      color: isRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning
                          ? 'Screen Control is active'
                          : 'Screen Control is disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isRunning ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isRunning) ...[
                  const Text(
                    'Tap below to open Accessibility Settings, then find "Agent Cypher Screen Control" and enable it.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.screenAutomationService
                          .openAccessibilitySettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Accessibility Settings'),
                  ),
                ] else ...[
                  Text(
                    'Can read screen, tap, scroll, and type in other apps',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
