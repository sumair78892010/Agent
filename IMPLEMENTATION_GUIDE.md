# Agent Cypher - Implementation Guide

## Project Overview

Agent Cypher is a premium JARVIS-style Android AI assistant built with Flutter. It's designed to provide seamless natural language control of Android devices with multi-provider AI support, voice integration, and sophisticated task execution.

## Architecture Layers

### 1. UI Layer
- **Screens**: HomeScreen (chat), OnboardingScreen, SettingsScreen, TaskHistoryScreen  
- **Widgets**: MessageBubble for chat display
- **Theme**: AgentCypherTheme with warm black/cream color palette
- **Overlay**: Floating bubble for background access

### 2. Agent Core (`agent_core.dart`)
Central orchestration system that handles:
- Intent interpretation
- Task planning
- Permission/safety checks
- Action routing
- Execution verification
- Retry logic with exponential backoff

### 3. AI Provider System
Located in `lib/services/provider/`:
- **AIProvider** (abstract): Base class defining provider interface
- **OpenAICompatibleProvider**: Generic implementation for OpenAI-like APIs
- **ProviderManager**: Manages multiple providers and provider switching

Currently supports:
- Custom OpenAI-compatible endpoints
- NVIDIA (NIM endpoints)
- DeepSeek, Groq, Ollama, etc.

### 4. Device Control Layer
Services for Android device interaction:
- **ScreenAutomationService**: Accessibility-based UI automation
- **AppLauncherService**: App package resolution and launching
- **SystemControlService**: Device settings (brightness, volume, etc.)
- **CommunicationService**: Calls, SMS, contacts
- **AlarmService**: Alarm management
- **ShizukuService**: Privileged operations (optional)
- **NotificationService**: Notifications management

### 5. Supporting Services
- **VoiceService**: Speech recognition and text-to-speech
- **ActionHandler**: Orchestrates device actions
- **TaskExecutor**: Executes multi-step tasks with AI guidance
- **TaskHistoryLogger**: Tracks executed tasks
- **SkillMemoryService**: Stores and replays successful task sequences
- **ChatHistoryService**: Chat session persistence
- **RecoveryEngine**: Task failure recovery

## Key Components and How They Connect

```
User Input (Text/Voice)
    ↓
[HomeScreen] → [AgentCore.interpretIntent]
    ↓
[ProviderManager] → [ActiveProvider (e.g., NVIDIA)]
    ↓
[Agent Core] Plans Task → [TaskExecutor.executeTask]
    ↓
[ActionHandler] → [Device Services] (Accessibility, App Launcher, etc.)
    ↓
[ScreenAutomationService] Observes Results
    ↓
[AgentCore] Verifies & Retries if Needed
    ↓
Response to User (Chat + Notifications)
```

## Critical Implementation Checklist

### ✅ Completed
1. Rebranding (PrivateAgent → Agent Cypher)
2. Telegram removal
3. Provider architecture foundation
4. Agent Core foundation
5. Premium theme system
6. All service integrations preserved

### 🔄 In Progress / High Priority
1. **Voice Pipeline** - Integrate wake word, STT, TTS
2. **Floating Bubble** - Premium UI with state animations
3. **Task Planning** - Enhanced multi-step action planning
4. **Device Control** - Improved Accessibility integration
5. **Memory System** - User preferences and recurring information

### ⏳ Remaining
1. Security/Biometric authentication
2. Automation/Routines system
3. Web browsing and downloads
4. Full testing suite
5. Performance optimization
6. APK build and release

## Configuration and Secrets Management

### Current Implementation
- Uses `SharedPreferences` for storing:
  - API keys (should be migrated to `EncryptedSharedPreferences`)
  - Base URLs
  - Model selections
  - User preferences

### Required Migration
```dart
// Current (INSECURE)
final prefs = await SharedPreferences.getInstance();
prefs.setString('api_key', apiKey);

// TODO: Use encrypted storage
// Use flutter_secure_storage or encrypted_shared_preferences
```

## Environment Setup

### Dependencies Required
All major dependencies are in `pubspec.yaml`:
- flutter (core framework)
- http (API requests)
- speech_to_text, flutter_tts (voice)
- shared_preferences (storage)
- permission_handler (Android permissions)
- flutter_contacts (contacts)
- flutter_overlay_window (floating bubble)
- flutter_local_notifications (notifications)
- volume_controller, screen_brightness (system control)
- shizuku_api (optional privileged access)

### Android Configuration
- **minSdk**: 26
- **targetSdk**: 34+
- **Package**: com.cypherghost.agentcypher
- **Permissions**: Defined in AndroidManifest.xml
- **Services**:
  - MainActivity: Main app entry
  - AgentAccessibilityService: Screen automation

### Fonts (To Be Added)
- Body/UI: DM Sans
- Headings: Cormorant Garamond  
- Code: JetBrains Mono

## Building and Testing

### Debug Build
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### Release Build
```bash
# Requires keystore setup
flutter build apk --release
```

### Testing
```bash
# Run tests
flutter test

# Run specific test file
flutter test test/ai_service_test.dart
```

## Provider Configuration Examples

### NVIDIA NIM
```json
{
  "provider": "NVIDIA",
  "base_url": "https://integrate.api.nvidia.com/v1",
  "api_key": "nvapi-...",
  "model": "z-ai/glm-5.2"
}
```

### Custom OpenAI-Compatible
```json
{
  "provider": "Custom",
  "base_url": "https://api.openai.com/v1",
  "api_key": "sk-...",
  "model": "gpt-4-turbo"
}
```

### DeepSeek
```json
{
  "provider": "DeepSeek",
  "base_url": "https://api.deepseek.com",
  "api_key": "sk-...",
  "model": "deepseek-chat"
}
```

## Common Development Tasks

### Adding a New Action Type
1. Define action in `AgentAction` model
2. Add case in `ActionHandler.execute()`
3. Implement in appropriate device service
4. Add to AI system prompt in `AIService`

### Adding a New Provider
1. Create class extending `AIProvider`
2. Implement all required methods
3. Add to `ProviderManager`
4. Update Settings UI to expose configuration

### Enhancing Task Execution
1. Modify `AgentCore.planTask()` for better planning
2. Enhance `TaskExecutor` for complex scenarios
3. Improve `RecoveryEngine` for better failure handling
4. Add task verification in `AgentCore.verifyCompletion()`

## File Structure

```
lib/
├── main.dart                           # App entry, theme setup
├── overlay_main.dart                   # Floating bubble overlay
├── config/
│   ├── app_theme.dart                 # Premium design system
│   └── feature_flags.dart              # Feature toggles
├── models/
│   ├── agent_action.dart               # Action definitions
│   ├── chat_message.dart               # Chat data structure
│   └── saved_skill.dart                # Learned task sequences
├── screens/
│   ├── home_screen.dart                # Main chat UI
│   ├── onboarding_screen.dart          # Setup wizard
│   ├── settings_screen.dart            # Configuration
│   └── task_history_screen.dart        # Execution logs
├── services/
│   ├── agent_core.dart                 # ⭐ Core orchestration
│   ├── ai_service.dart                 # AI interaction
│   ├── action_handler.dart             # Action execution
│   ├── task_executor.dart              # Multi-step execution
│   ├── screen_automation_service.dart  # Accessibility
│   ├── app_launcher_service.dart       # App management
│   ├── system_control_service.dart     # Device settings
│   ├── voice_service.dart              # Speech & TTS
│   ├── notification_service.dart       # Notifications
│   ├── recovery_engine.dart            # Failure recovery
│   ├── skill_memory_service.dart       # Task memory
│   ├── chat_history_service.dart       # Chat persistence
│   ├── shizuku_service.dart            # Privileged access
│   ├── contacts_service.dart           # Contacts access
│   ├── communication_service.dart      # Calls & SMS
│   ├── alarm_service.dart              # Alarms
│   └── provider/
│       ├── ai_provider.dart            # Provider interface
│       ├── openai_compatible_provider.dart  # Generic provider
│       └── provider_manager.dart       # Multi-provider management
└── widgets/
    └── message_bubble.dart             # Chat message UI
```

## Git Workflow

### Current Branch
- `main`: Latest development (CI/CD ready)

### Recent Commits
- Phase 2-7: Rebrand, remove Telegram, implement providers
- Earlier: Initial PrivateAgent implementation

### Pushing Changes
```bash
git add -A
git commit -m "Meaningful commit message"
git push origin main
```

## Known Limitations & Platform Restrictions

### Android OS Restrictions
1. **Background Execution**: Limited by Doze mode (mitigated with foreground services)
2. **Microphone Access**: Only active when app is in foreground (by design for privacy)
3. **Screen Recording**: Limited to what MediaProjection allows
4. **Accessibility Service**: Requires user permission from Settings
5. **Overlay Permission**: May be blocked by device policies

### Implementation Constraints
1. No custom face recognition (use BiometricPrompt instead)
2. Bluetooth/WiFi: Can suggest settings but not toggle directly (most cases)
3. Screen unlock: Cannot programmatically unlock (use Accessibility + UI)

## Next Steps for Contributors

1. **Review IMPLEMENTATION_STATUS.md** for detailed progress
2. **Test build locally** - `flutter build apk --debug`
3. **Set up IDE** - VS Code + Flutter extension or Android Studio
4. **Review the spec** - MASTER_PROMPT.md for all requirements
5. **Start with high-impact features**:
   - Voice integration improvements
   - Floating bubble UI
   - Task planning enhancements
6. **Test thoroughly** before committing

## Support & Resources

- **Flutter Docs**: https://flutter.dev/docs
- **Android Accessibility**: https://developer.android.com/guide/topics/accessibility
- **Material Design**: https://material.io/design
- **Provider Docs**: Check individual AI provider API documentation

## License & Attribution

- Original: PrivateAgent by OrailNoor
- Current: Agent Cypher by Cypher Ghost
- Created for: Sumair
- Open source with modifications
