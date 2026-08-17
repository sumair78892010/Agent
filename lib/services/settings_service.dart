import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Settings and preferences management service
/// Per spec: User preferences, AI model settings, notification preferences, etc.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  late SharedPreferences _prefs;

  /// Setting categories
  static const String aiSettings = 'ai_';
  static const String voiceSettings = 'voice_';
  static const String notificationSettings = 'notif_';
  static const String uiSettings = 'ui_';
  static const String privacySettings = 'privacy_';
  static const String accessibilitySettings = 'a11y_';
  static const String developerSettings = 'developer_';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ensureDefaults();
  }

  void _ensureDefaults() {
    // AI Settings defaults
    if (!_prefs.containsKey('${aiSettings}provider')) {
      setAiProvider('openai');
    }
    if (!_prefs.containsKey('${aiSettings}model')) {
      setAiModel('gpt-4');
    }

    // Voice Settings defaults
    if (!_prefs.containsKey('${voiceSettings}enabled')) {
      setVoiceEnabled(true);
    }
    if (!_prefs.containsKey('${voiceSettings}language')) {
      setVoiceLanguage('en-US');
    }

    // Notification defaults
    if (!_prefs.containsKey('${notificationSettings}enabled')) {
      setNotificationsEnabled(true);
    }

    // Privacy defaults
    if (!_prefs.containsKey('${privacySettings}analytics')) {
      setAnalyticsEnabled(false);
    }
  }

  // ─── AI Settings ───────────────────

  Future<void> setAiProvider(String provider) async {
    await _prefs.setString('${aiSettings}provider', provider);
  }

  String getAiProvider() {
    return _prefs.getString('${aiSettings}provider') ?? 'openai';
  }

  Future<void> setAiModel(String model) async {
    await _prefs.setString('${aiSettings}model', model);
  }

  String getAiModel() {
    return _prefs.getString('${aiSettings}model') ?? 'gpt-4';
  }

  Future<void> setAiTemperature(double temperature) async {
    await _prefs.setDouble('${aiSettings}temperature', temperature);
  }

  double getAiTemperature() {
    return _prefs.getDouble('${aiSettings}temperature') ?? 0.7;
  }

  Future<void> setAiMaxTokens(int tokens) async {
    await _prefs.setInt('${aiSettings}max_tokens', tokens);
  }

  int getAiMaxTokens() {
    return _prefs.getInt('${aiSettings}max_tokens') ?? 1000;
  }

  Future<void> setAiApiKey(String key) async {
    // In production, store in secure storage
    await _prefs.setString('${aiSettings}api_key', key);
  }

  String? getAiApiKey() {
    return _prefs.getString('${aiSettings}api_key');
  }

  // ─── Voice Settings ───────────────────

  Future<void> setVoiceEnabled(bool enabled) async {
    await _prefs.setBool('${voiceSettings}enabled', enabled);
  }

  bool isVoiceEnabled() {
    return _prefs.getBool('${voiceSettings}enabled') ?? true;
  }

  Future<void> setVoiceLanguage(String language) async {
    await _prefs.setString('${voiceSettings}language', language);
  }

  String getVoiceLanguage() {
    return _prefs.getString('${voiceSettings}language') ?? 'en-US';
  }

  Future<void> setVoiceSpeed(double speed) async {
    await _prefs.setDouble('${voiceSettings}speed', speed);
  }

  double getVoiceSpeed() {
    return _prefs.getDouble('${voiceSettings}speed') ?? 1.0;
  }

  Future<void> setWakeWordEnabled(bool enabled) async {
    await _prefs.setBool('${voiceSettings}wake_word', enabled);
  }

  bool isWakeWordEnabled() {
    return _prefs.getBool('${voiceSettings}wake_word') ?? false;
  }

  Future<void> setWakeWord(String word) async {
    await _prefs.setString('${voiceSettings}wake_word_text', word);
  }

  String getWakeWord() {
    return _prefs.getString('${voiceSettings}wake_word_text') ?? 'Hey Cypher';
  }

  // ─── Notification Settings ───────────────────

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('${notificationSettings}enabled', enabled);
  }

  bool areNotificationsEnabled() {
    return _prefs.getBool('${notificationSettings}enabled') ?? true;
  }

  Future<void> setNotificationSound(bool enabled) async {
    await _prefs.setBool('${notificationSettings}sound', enabled);
  }

  bool isNotificationSoundEnabled() {
    return _prefs.getBool('${notificationSettings}sound') ?? true;
  }

  Future<void> setNotificationVibration(bool enabled) async {
    await _prefs.setBool('${notificationSettings}vibration', enabled);
  }

  bool isNotificationVibrationEnabled() {
    return _prefs.getBool('${notificationSettings}vibration') ?? true;
  }

  // ─── UI Settings ───────────────────

  Future<void> setThemeMode(String mode) async {
    // 'light', 'dark', 'system'
    await _prefs.setString('${uiSettings}theme', mode);
  }

  String getThemeMode() {
    return _prefs.getString('${uiSettings}theme') ?? 'system';
  }

  Future<void> setBubbleSize(double size) async {
    await _prefs.setDouble('${uiSettings}bubble_size', size);
  }

  double getBubbleSize() {
    return _prefs.getDouble('${uiSettings}bubble_size') ?? 56.0;
  }

  Future<void> setCompactMode(bool enabled) async {
    await _prefs.setBool('${uiSettings}compact', enabled);
  }

  bool isCompactMode() {
    return _prefs.getBool('${uiSettings}compact') ?? false;
  }

  // ─── Privacy Settings ───────────────────

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _prefs.setBool('${privacySettings}analytics', enabled);
  }

  bool isAnalyticsEnabled() {
    return _prefs.getBool('${privacySettings}analytics') ?? false;
  }

  Future<void> setCrashReportsEnabled(bool enabled) async {
    await _prefs.setBool('${privacySettings}crash_reports', enabled);
  }

  bool areCrashReportsEnabled() {
    return _prefs.getBool('${privacySettings}crash_reports') ?? false;
  }

  Future<void> setHistoryRetentionDays(int days) async {
    await _prefs.setInt('${privacySettings}history_retention', days);
  }

  int getHistoryRetentionDays() {
    return _prefs.getInt('${privacySettings}history_retention') ?? 90;
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    await _prefs.setBool('${privacySettings}logging', enabled);
  }

  bool isLoggingEnabled() {
    return _prefs.getBool('${privacySettings}logging') ?? true;
  }

  // ─── Accessibility Settings ───────────────────

  Future<void> setFontSize(double size) async {
    await _prefs.setDouble('${accessibilitySettings}font_size', size);
  }

  double getFontSize() {
    return _prefs.getDouble('${accessibilitySettings}font_size') ?? 1.0;
  }

  Future<void> setScreenReaderEnabled(bool enabled) async {
    await _prefs.setBool('${accessibilitySettings}screen_reader', enabled);
  }

  bool isScreenReaderEnabled() {
    return _prefs.getBool('${accessibilitySettings}screen_reader') ?? false;
  }

  Future<void> setHighContrastEnabled(bool enabled) async {
    await _prefs.setBool('${accessibilitySettings}high_contrast', enabled);
  }

  bool isHighContrastEnabled() {
    return _prefs.getBool('${accessibilitySettings}high_contrast') ?? false;
  }

  // ─── Developer Settings ───────────────────

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    await _prefs.setBool('${developerSettings}mode', enabled);
  }

  bool isDeveloperModeEnabled() {
    return _prefs.getBool('${developerSettings}mode') ?? false;
  }

  // ─── General Settings ───────────────────

  /// Get all settings as a dictionary
  Map<String, dynamic> getAllSettings() {
    return {
      'ai': {
        'provider': getAiProvider(),
        'model': getAiModel(),
        'temperature': getAiTemperature(),
        'max_tokens': getAiMaxTokens(),
      },
      'voice': {
        'enabled': isVoiceEnabled(),
        'language': getVoiceLanguage(),
        'speed': getVoiceSpeed(),
        'wake_word_enabled': isWakeWordEnabled(),
        'wake_word': getWakeWord(),
      },
      'notifications': {
        'enabled': areNotificationsEnabled(),
        'sound': isNotificationSoundEnabled(),
        'vibration': isNotificationVibrationEnabled(),
      },
      'ui': {
        'theme': getThemeMode(),
        'bubble_size': getBubbleSize(),
        'compact_mode': isCompactMode(),
      },
      'privacy': {
        'analytics': isAnalyticsEnabled(),
        'crash_reports': areCrashReportsEnabled(),
        'history_retention_days': getHistoryRetentionDays(),
        'logging': isLoggingEnabled(),
      },
      'accessibility': {
        'font_size': getFontSize(),
        'screen_reader': isScreenReaderEnabled(),
        'high_contrast': isHighContrastEnabled(),
      },
      'developer': {
        'mode': isDeveloperModeEnabled(),
      },
    };
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.clear();
    _ensureDefaults();
  }

  /// Export settings as JSON string
  String exportSettings() {
    return jsonEncode(getAllSettings());
  }

  /// Import settings from JSON string
  Future<void> importSettings(String jsonString) async {
    try {
      final settings = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Import AI settings
      if (settings.containsKey('ai')) {
        final ai = settings['ai'] as Map<String, dynamic>;
        if (ai.containsKey('provider')) await setAiProvider(ai['provider']);
        if (ai.containsKey('model')) await setAiModel(ai['model']);
        if (ai.containsKey('temperature')) await setAiTemperature(ai['temperature']);
        if (ai.containsKey('max_tokens')) await setAiMaxTokens(ai['max_tokens']);
      }

      // Import voice settings
      if (settings.containsKey('voice')) {
        final voice = settings['voice'] as Map<String, dynamic>;
        if (voice.containsKey('enabled')) await setVoiceEnabled(voice['enabled']);
        if (voice.containsKey('language')) await setVoiceLanguage(voice['language']);
        if (voice.containsKey('speed')) await setVoiceSpeed(voice['speed']);
        if (voice.containsKey('wake_word_enabled')) await setWakeWordEnabled(voice['wake_word_enabled']);
        if (voice.containsKey('wake_word')) await setWakeWord(voice['wake_word']);
      }

      // Import notification settings
      if (settings.containsKey('notifications')) {
        final notif = settings['notifications'] as Map<String, dynamic>;
        if (notif.containsKey('enabled')) await setNotificationsEnabled(notif['enabled']);
        if (notif.containsKey('sound')) await setNotificationSound(notif['sound']);
        if (notif.containsKey('vibration')) await setNotificationVibration(notif['vibration']);
      }

      // Import UI settings
      if (settings.containsKey('ui')) {
        final ui = settings['ui'] as Map<String, dynamic>;
        if (ui.containsKey('theme')) await setThemeMode(ui['theme']);
        if (ui.containsKey('bubble_size')) await setBubbleSize(ui['bubble_size'].toDouble());
        if (ui.containsKey('compact_mode')) await setCompactMode(ui['compact_mode']);
      }

      // Import privacy settings
      if (settings.containsKey('privacy')) {
        final privacy = settings['privacy'] as Map<String, dynamic>;
        if (privacy.containsKey('analytics')) await setAnalyticsEnabled(privacy['analytics']);
        if (privacy.containsKey('crash_reports')) await setCrashReportsEnabled(privacy['crash_reports']);
        if (privacy.containsKey('history_retention_days')) await setHistoryRetentionDays(privacy['history_retention_days']);
        if (privacy.containsKey('logging')) await setLoggingEnabled(privacy['logging']);
      }

      // Import accessibility settings
      if (settings.containsKey('accessibility')) {
        final a11y = settings['accessibility'] as Map<String, dynamic>;
        if (a11y.containsKey('font_size')) await setFontSize(a11y['font_size'].toDouble());
        if (a11y.containsKey('screen_reader')) await setScreenReaderEnabled(a11y['screen_reader']);
        if (a11y.containsKey('high_contrast')) await setHighContrastEnabled(a11y['high_contrast']);
      }
    } catch (e) {
      // Import failed, keep existing settings
      rethrow;
    }
  }
}
