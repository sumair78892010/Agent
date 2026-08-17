# Agent Cypher - Architecture & Implementation

## Overview

Agent Cypher is a complete Android AI assistant that combines natural language understanding with real device automation. The architecture ensures REAL execution with REAL verification, not mocks or stubs.

## Core Architecture

### 1. Service Layer

#### AgentSetup (Singleton)
Central initialization point for all services. Initializes in dependency order.
```dart
final agent = AgentSetup();
await agent.initialize();
```

Services available after init:
- `agentCore` - AI understanding and planning
- `executionPipeline` - Command execution orchestration
- `actionHandler` - Device action execution
- `aiService` - AI provider integration
- `voiceService` - Speech recognition and TTS
- `userMemory` - Persistent user memory
- `permissionService` - Permission management
- `diagnosticsService` - System health checks
- `screenService` - Accessibility automation

#### ExecutionPipeline (Main Flow)
The heart of Agent Cypher. Handles the complete flow from user input to verified result.

**Flow:**
```
User Input (text/voice)
    ↓
AgentCore.interpretIntent()
    ↓
Safety Check
    ↓
ActionHandler.execute()
    ↓
VerificationService.verify*()
    ↓
Retry Logic (exponential backoff)
    ↓
Return verified result
```

**Event Stream:**
- `STARTED` - Execution beginning
- `UNDERSTANDING` - Parsing user input
- `UNDERSTOOD` - Intent extracted
- `PERMISSION_CHECK` - Verifying permissions
- `EXECUTING` - Running action
- `PROGRESS` - Live execution updates
- `VERIFYING` - Checking actual device state
- `VERIFIED` - Action confirmed successful
- `COMPLETED` - Task finished
- `ERROR` - Execution failed

**Usage:**
```dart
final pipeline = AgentSetup().executionPipeline;
final result = await pipeline.executeCommand(
  'Open YouTube',
  onEvent: (event) {
    print('${event.type}: ${event.message}');
  },
);

if (result.success) {
  print('Success: ${result.result}');
} else {
  print('Failed: ${result.errorMessage}');
}
```

#### AgentCore
Handles AI understanding and decision-making.

**Key Methods:**
- `interpretIntent(userInput)` - Parse user request into AgentAction
- `checkSafety(action)` - Verify action is permitted
- `planTask(goal)` - Create multi-step plan
- `getConversationHistory()` - Access chat history

**Action Parsing:**
The system expects AI responses in structured JSON:
```json
{
  "action": "open_app",
  "params": {"app_name": "YouTube"},
  "response": "Opening YouTube for you."
}
```

#### ActionHandler
Executes all device actions.

**Supported Actions:**
- `open_app` - Launch application by name
- `launch_package` - Launch app by package name
- `make_call` - Initiate phone call
- `send_sms` - Send text message
- `set_brightness` - Adjust screen brightness
- `set_volume` - Adjust system volume
- `read_screen` - Get current UI description
- `click_element` - Tap UI element by text
- `type_on_screen` - Type text into field
- `scroll_screen` - Scroll up/down
- `press_back` - Press back button
- `execute_task` - Multi-step UI automation

**Returns:**
```dart
AgentActionResult(
  actionType: 'open_app',
  success: true,
  details: 'Successfully opened YouTube',
)
```

#### VerificationService
REAL device state verification - the key innovation per spec section 5.

**Verification Methods:**
- `verifyAppOpened(package, appName)` - Checks foreground app
- `verifyScreenAction(action, expectedChange)` - Verifies UI changed
- `verifyTextTyped(text)` - Checks text appears in field
- `verifyElementClicked(text)` - Verifies element interaction

**Why it matters:**
- Never assume success from "no exception"
- Verify YouTube is actually foreground after open_app
- Verify text actually appears after typing
- Verify UI changed after tapping

#### UserMemoryService
Persistent user memory and preferences.

**Storage Categories:**
- `preferences` - User preferences (e.g., "prefer concise answers")
- `facts` - Facts about user (e.g., "favorite food is pizza")
- `instructions` - User rules (e.g., "always ask before calls")
- `device_preferences` - Device settings (e.g., brightness, theme)

**Usage:**
```dart
final memory = AgentSetup().userMemory;
await memory.rememberPreference('tone', 'concise');
await memory.rememberFact('I love pizza');
final facts = await memory.getFacts();
```

#### VoiceService
Speech recognition and text-to-speech.

**Events:**
- `initialized` - Service ready
- `listening_started` - Listening for input
- `partial_result` - Intermediate speech recognition
- `recognized` - Final speech recognized
- `speaking_started` - TTS beginning
- `speaking_completed` - TTS finished
- `error` - Voice operation failed

**Usage:**
```dart
final voice = AgentSetup().voiceService;
voice.eventStream.listen((event) {
  print('${event.type}: ${event.message}');
});

await voice.startListening(
  onResult: (text) => print('Heard: $text'),
  onDone: () => print('Done listening'),
);

await voice.speak('Hello, I am Cypher.');
```

#### PermissionService
Centralized permission checking and requesting.

**Status Values:**
- `granted` - Permission approved
- `denied` - Permission rejected
- `permanentlyDenied` - Can't request again, must open Settings
- `restricted` - System restricted
- `limited` - Partial permission

**Critical Permissions:**
- Microphone - Voice input
- Accessibility Service - UI automation
- Notification Access - Notification reading
- Overlay - Floating bubble display

**Usage:**
```dart
final perms = AgentSetup().permissionService;
final status = await perms.checkMicrophone();
if (!status.isGranted) {
  print(perms.getPermissionExplanation('microphone'));
  await perms.requestMicrophone();
}
```

#### DiagnosticsService
System health and readiness checks.

**Checks:**
- AI provider connectivity
- Network availability
- Microphone access
- TTS engine availability
- Overlay permission
- Accessibility service
- Notification access
- Storage availability

**Usage:**
```dart
final diag = AgentSetup().diagnosticsService;
final results = await diag.runAllDiagnostics();
for (final result in results) {
  print('${result.statusIcon} ${result.component}: ${result.statusText}');
  if (result.remediation != null) {
    print('  → ${result.remediation}');
  }
}
```

### 2. Data Models

#### AgentAction
Represents a parsed user intent.
```dart
AgentAction(
  id: 'action_12345',
  action: 'open_app',
  params: {'app_name': 'YouTube'},
  response: 'Opening YouTube',
)
```

#### AgentActionResult
Result of executing an action.
```dart
AgentActionResult(
  actionType: 'open_app',
  success: true,
  details: 'YouTube is now foreground',
)
```

#### ExecutionEvent
Live event during execution.
```dart
ExecutionEvent(
  timestamp: DateTime.now(),
  type: 'VERIFYING',
  message: 'Verifying action completion',
  details: 'open_app',
)
```

#### ChatMessage
Persisted conversation message.
```dart
ChatMessage(
  role: 'user',
  content: 'Open YouTube',
  timestamp: DateTime.now(),
  actionResult: result,
)
```

#### VoiceEvent
Live voice service event.
```dart
VoiceEvent(
  type: 'recognized',
  message: 'Speech recognized',
  content: 'open youtube',
)
```

### 3. Integration Points

#### In HomeScreen
```dart
// Initialize
@override
void initState() {
  super.initState();
  final agent = AgentSetup();
  agent.initialize().then((_) {
    // Ready to use
    _executionPipeline = agent.executionPipeline;
  });
}

// Execute command
_sendMessage(String text) async {
  final result = await _executionPipeline.executeCommand(
    text,
    onEvent: (event) {
      setState(() => _eventLog.add(event));
    },
  );
  
  if (result.success) {
    // Show success message
  } else {
    // Show error message
  }
}

// Voice input
_startVoice() {
  voiceService.startListening(
    onResult: (text) => _sendMessage(text),
    onDone: () => setState(() => _isListening = false),
  );
}
```

#### In FloatingBubble (Overlay)
```dart
// Minimal integration - just send task to main app
FlutterOverlayWindow.shareData('Open settings');

// Listen for completion
FlutterOverlayWindow.overlayListener.listen((event) {
  if (event == 'TASK_COMPLETE') {
    _showCompletionAnimation();
  }
});
```

## Retry and Recovery Strategy

**Exponential Backoff:**
- Attempt 1: Wait 500ms before retry
- Attempt 2: Wait 1000ms before retry
- Attempt 3: Wait 2000ms before retry
- Max 3 attempts total

**When Retry Happens:**
- Action execution fails (returns false/error)
- Verification fails (device state not as expected)
- Screen didn't respond as expected

**Example:**
```
User: "Open YouTube"
Attempt 1: App launch command sent → Verification failed (YouTube not foreground)
Wait 500ms...
Attempt 2: App launch command sent → Verification failed
Wait 1000ms...
Attempt 3: App launch command sent → Verification succeeded!
Result: SUCCESS
```

## Error Handling

### Provider-Specific Errors
Errors clearly identify which provider failed:
```
"NVIDIA API connection failed: timeout"
NOT
"API not configured"
```

### Never Show Secrets
No API keys in error messages, logs, crash reports.

### Actionable Remediation
Always provide how to fix:
```
Error: Accessibility service not enabled
Fix: Go to Settings > Accessibility > Agent Cypher and enable the service
```

## Real Execution vs Mocks

### REAL Examples
- ✅ `open_app` - Actually launches the app, verifies foreground
- ✅ `click_element` - Actually taps the screen element
- ✅ `type_text` - Actually types and verifies text appears
- ✅ `read_screen` - Reads actual accessibility tree

### NOT Acceptable
- ❌ `open_app` - Just returns success string
- ❌ `click_element` - Returns "clicked" without verifying
- ❌ `read_screen` - Returns mock data
- ❌ Retry without actually checking state

## File Structure

```
lib/
├── services/
│   ├── agent_setup.dart          # Main initialization
│   ├── agent_core.dart           # AI understanding
│   ├── execution_pipeline.dart   # Command flow
│   ├── action_handler.dart       # Action execution
│   ├── verification_service.dart # Real verification
│   ├── ai_service.dart           # AI provider
│   ├── voice_service.dart        # STT/TTS
│   ├── user_memory_service.dart  # Persistent memory
│   ├── permission_service.dart   # Permission management
│   ├── diagnostics_service.dart  # System checks
│   └── [other services]
├── models/
│   ├── agent_action.dart
│   ├── chat_message.dart
│   └── saved_skill.dart
├── screens/
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   └── [other screens]
└── main.dart

android/
└── app/
    └── src/
        └── main/
            ├── AndroidManifest.xml
            ├── res/
            │   └── xml/
            │       └── accessibility_service_config.xml
            └── kotlin/
                └── [native code]
```

## Testing Integration

```dart
// Example: Verify the pipeline works end-to-end
test('Execute command through full pipeline', () async {
  final agent = AgentSetup();
  await agent.initialize();
  
  final result = await agent.executionPipeline.executeCommand(
    'Read the screen',
  );
  
  expect(result.success, true);
  expect(result.result, contains('Current app'));
});
```

## Performance Considerations

- Verify operations are cached when possible
- Retry backoff prevents excessive repeated attempts
- Event stream allows UI to update live without blocking
- User memory is loaded once and kept in memory
- Diagnostic checks are async to avoid ANR

## Security Considerations

- No API keys logged or shown
- No secrets in crash reports
- Permissions clearly explained before requesting
- User memory encrypted in SharedPreferences (future)
- All network calls over HTTPS
- Accessibility service runs in protected context

## Next Steps for Developers

1. Initialize AgentSetup() early in app startup
2. Hook ExecutionPipeline into chat UI
3. Add voice input via VoiceService events
4. Display diagnostics in Settings screen
5. Integrate UserMemory into AI context
6. Create floating bubble using overlay widgets
7. Add task history view
8. Implement file operations
9. Add web automation capabilities
10. Test with real devices
