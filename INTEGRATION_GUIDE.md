# Agent Cypher - Integration Guide

## Quick Start

### 1. Basic Setup in main()

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Agent Cypher
  final agent = AgentSetup();
  await agent.initialize();
  
  runApp(MyApp());
}
```

### 2. Using ExecutionPipeline in HomeScreen

```dart
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ExecutionPipeline _pipeline;
  List<ExecutionEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _pipeline = AgentSetup().executionPipeline;
  }

  // Send a user message through the agent
  void _handleUserMessage(String text) async {
    // Show thinking state
    setState(() => _isThinking = true);

    // Execute through the full pipeline
    final result = await _pipeline.executeCommand(
      text,
      onEvent: (event) {
        // Real-time event updates
        setState(() => _events.add(event));
        print('${event.type}: ${event.message}');
      },
    );

    setState(() => _isThinking = false);

    if (result.success) {
      _showMessage('✓ ${result.result}', isSuccess: true);
    } else {
      _showMessage('✗ ${result.errorMessage}', isSuccess: false);
    }
  }
}
```

### 3. Using Voice Input

```dart
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late VoiceService _voice;

  @override
  void initState() {
    super.initState();
    _voice = AgentSetup().voiceService;
    
    // Listen to voice events
    _voice.eventStream.listen((event) {
      switch (event.type) {
        case 'listening_started':
          setState(() => _isListening = true);
          break;
        case 'recognized':
          _handleUserMessage(event.content ?? '');
          break;
        case 'speaking_started':
          setState(() => _isSpeaking = true);
          break;
        case 'speaking_completed':
          setState(() => _isSpeaking = false);
          break;
        case 'error':
          _showError(event.message);
          break;
      }
    });
  }

  void _startListening() async {
    await _voice.startListening(
      onResult: (text) => _handleUserMessage(text),
      onDone: () => setState(() => _isListening = false),
    );
  }

  void _respondToUser(String message) async {
    await _voice.speak(message);
  }
}
```

### 4. Displaying Diagnostics in Settings

```dart
class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<DiagnosticResult>? _diagnostics;
  bool _isChecking = false;

  void _runDiagnostics() async {
    setState(() => _isChecking = true);
    
    final diag = AgentSetup().diagnosticsService;
    final results = await diag.runAllDiagnostics();
    
    setState(() {
      _diagnostics = results;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : _diagnostics == null
              ? Center(
                  child: ElevatedButton(
                    onPressed: _runDiagnostics,
                    child: const Text('Run Diagnostics'),
                  ),
                )
              : ListView.builder(
                  itemCount: _diagnostics!.length,
                  itemBuilder: (context, index) {
                    final result = _diagnostics![index];
                    return _buildDiagnosticTile(result);
                  },
                ),
    );
  }

  Widget _buildDiagnosticTile(DiagnosticResult result) {
    return ListTile(
      leading: Text(
        result.statusIcon,
        style: const TextStyle(fontSize: 20),
      ),
      title: Text(result.component),
      subtitle: Text(result.message),
      trailing: Icon(
        result.status == DiagnosticStatus.pass
            ? Icons.check_circle
            : result.status == DiagnosticStatus.warning
                ? Icons.warning
                : Icons.error,
        color: result.status == DiagnosticStatus.pass
            ? Colors.green
            : result.status == DiagnosticStatus.warning
                ? Colors.orange
                : Colors.red,
      ),
      onTap: result.remediation != null
          ? () => _showRemediationDialog(result)
          : null,
    );
  }

  void _showRemediationDialog(DiagnosticResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fix: ${result.component}'),
        content: Text(result.remediation ?? result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

### 5. Using User Memory

```dart
class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserMemoryService _memory;
  Map<String, dynamic> _preferences = {};
  List<String> _facts = [];
  List<String> _instructions = [];

  @override
  void initState() {
    super.initState();
    _memory = AgentSetup().userMemory;
    _loadMemory();
  }

  void _loadMemory() async {
    _preferences = await _memory.getPreferences();
    _facts = await _memory.getFacts();
    _instructions = await _memory.getInstructions();
    setState(() {});
  }

  void _addPreference(String key, String value) async {
    await _memory.rememberPreference(key, value);
    await _loadMemory();
  }

  void _addFact(String fact) async {
    await _memory.rememberFact(fact);
    await _loadMemory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text('Preferences'),
            children: [
              ..._preferences.entries.map((entry) => ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value.toString()),
                  )),
              ListTile(
                title: const Text('+ Add Preference'),
                onTap: () => _showAddPreferenceDialog(),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Facts'),
            children: [
              ..._facts.map((fact) => ListTile(
                    title: Text(fact),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _memory.forgetFact(fact),
                    ),
                  )),
              ListTile(
                title: const Text('+ Add Fact'),
                onTap: () => _showAddFactDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 6. Handling Permissions

```dart
class OnboardingScreen extends StatefulWidget {
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PermissionService _permissions;
  bool _allGranted = false;

  @override
  void initState() {
    super.initState();
    _permissions = AgentSetup().permissionService;
    _checkPermissions();
  }

  void _checkPermissions() async {
    final statuses = await _permissions.getAllPermissionsStatus();
    bool allGranted = true;
    
    for (final entry in statuses.entries) {
      if (entry.value.required && 
          entry.value.status != PermissionStatus.granted) {
        allGranted = false;
        break;
      }
    }
    
    setState(() => _allGranted = allGranted);
  }

  void _requestPermission(String permissionType) async {
    final explanation = _permissions.getPermissionExplanation(permissionType);
    
    // Show explanation dialog
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(permissionType.replaceAll('_', ' ')),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    ) ?? false;

    if (shouldContinue) {
      bool granted = false;
      switch (permissionType) {
        case 'microphone':
          granted = await _permissions.requestMicrophone();
          break;
        case 'notification':
          granted = await _permissions.requestNotification();
          break;
        case 'overlay':
          granted = await _permissions.requestOverlay();
          break;
      }

      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$permissionType permission granted!')),
        );
        _checkPermissions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Agent Cypher Setup'),
            const SizedBox(height: 20),
            if (_allGranted)
              ElevatedButton(
                onPressed: _completeOnboarding,
                child: const Text('Complete Setup'),
              )
            else
              ElevatedButton(
                onPressed: () => _requestPermission('microphone'),
                child: const Text('Enable Permissions'),
              ),
          ],
        ),
      ),
    );
  }
}
```

### 7. Displaying Live Execution Status

```dart
class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ExecutionEvent> _eventLog = [];
  late ExecutionPipeline _pipeline;

  @override
  void initState() {
    super.initState();
    _pipeline = AgentSetup().executionPipeline;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _eventLog.length,
            itemBuilder: (context, index) {
              final event = _eventLog[index];
              return _buildEventTile(event);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventTile(ExecutionEvent event) {
    final statusColor = {
      'STARTED': Colors.blue,
      'UNDERSTANDING': Colors.blue,
      'UNDERSTOOD': Colors.blue,
      'EXECUTING': Colors.purple,
      'VERIFYING': Colors.orange,
      'VERIFIED': Colors.green,
      'COMPLETED': Colors.green,
      'ERROR': Colors.red,
    }[event.type] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                event.type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                '${event.timestamp.hour}:${event.timestamp.minute}:${event.timestamp.second}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(event.message),
          if (event.details.isNotEmpty)
            Text(
              event.details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
```

## Common Patterns

### Pattern 1: Text Input → Agent → Response

```dart
final pipeline = AgentSetup().executionPipeline;
final result = await pipeline.executeCommand(userText);
if (result.success) {
  // Show result to user
} else {
  // Show error
}
```

### Pattern 2: Voice → Agent → Voice Response

```dart
final voice = AgentSetup().voiceService;
final pipeline = AgentSetup().executionPipeline;

voice.startListening(
  onResult: (text) async {
    final result = await pipeline.executeCommand(text);
    if (result.success) {
      await voice.speak(result.result ?? 'Done');
    }
  },
  onDone: () => setState(() => _isListening = false),
);
```

### Pattern 3: Memory-Aware Response

```dart
final memory = AgentSetup().userMemory;
final summary = await memory.getMemorySummary();
final preferences = await memory.getPreferences();

// Include in AI context
final aiPrompt = '''
$summary

User preferences: $preferences

User request: $userInput
''';
```

### Pattern 4: Permission-Gated Action

```dart
final perms = AgentSetup().permissionService;
final status = await perms.checkMicrophone();

if (!status.isGranted) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Microphone Required'),
      content: Text(perms.getPermissionExplanation('microphone')),
      actions: [
        TextButton(
          onPressed: () => perms.requestMicrophone(),
          child: const Text('Enable'),
        ),
      ],
    ),
  );
  return;
}

// Proceed with voice input
```

## Testing Integration

```dart
void main() {
  test('Full execution pipeline', () async {
    final agent = AgentSetup();
    await agent.initialize();
    
    final result = await agent.executionPipeline.executeCommand('Read screen');
    expect(result.success, true);
    expect(result.result, isNotEmpty);
  });

  test('Voice integration', () async {
    final voice = AgentSetup().voiceService;
    
    final recognized = <String>[];
    voice.eventStream
        .where((e) => e.type == 'recognized')
        .listen((e) => recognized.add(e.content ?? ''));
    
    await voice.startListening(
      onResult: (text) => recognized.add(text),
      onDone: () {},
    );
    
    await Future.delayed(const Duration(seconds: 3));
    expect(recognized, isNotEmpty);
  });

  test('Memory persistence', () async {
    final memory = AgentSetup().userMemory;
    
    await memory.rememberFact('Test fact');
    final facts = await memory.getFacts();
    
    expect(facts, contains('Test fact'));
  });
}
```

## Troubleshooting

### Issue: ExecutionPipeline not initialized
**Solution:** Call `AgentSetup().initialize()` before using the pipeline

### Issue: Microphone not working
**Solution:** Check permissions via `PermissionService` and request if needed

### Issue: Actions not executing
**Solution:** Check diagnostics to verify AI provider is connected

### Issue: Memory not persisting
**Solution:** Ensure `UserMemoryService.load()` is called during initialization

### Issue: Events not streaming
**Solution:** Subscribe to `ExecutionPipeline.eventStream` or use `onEvent` callback

## Next Steps

1. Integrate into HomeScreen
2. Add floating bubble UI
3. Implement file operations
4. Add web automation
5. Create advanced task templates
6. Build and test APK
