import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Persistent memory for user preferences, facts, and instructions
/// Per spec section 17: Support remembering user preferences and facts
class UserMemoryService {
  static const String _memoryFile = 'user_memory.json';
  
  Map<String, dynamic> _memory = {
    'preferences': {},
    'facts': [],
    'instructions': [],
    'device_preferences': {},
  };
  
  bool _isLoaded = false;
  bool _automaticMemoryEnabled = true;

  Future<File> get _memoryFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_memoryFile');
  }

  /// Load memory from disk
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _memoryFilePath;
      if (await file.exists()) {
        final content = await file.readAsString();
        _memory = jsonDecode(content) as Map<String, dynamic>;
        _automaticMemoryEnabled = _memory['_automatic_memory_enabled'] != false;
      }
      _isLoaded = true;
    } catch (e) {
      print('Error loading memory: $e');
      _isLoaded = true;
    }
  }

  /// Save memory to disk
  Future<void> _save() async {
    try {
      _memory['_automatic_memory_enabled'] = _automaticMemoryEnabled;
      final file = await _memoryFilePath;
      await file.writeAsString(jsonEncode(_memory));
    } catch (e) {
      print('Error saving memory: $e');
    }
  }

  /// Remember a preference
  /// Example: "Remember that I prefer concise answers"
  Future<void> rememberPreference(String key, String value) async {
    await load();
    _memory['preferences'] ??= {};
    _memory['preferences'][key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _save();
  }

  /// Remember a fact
  /// Example: "My favorite food is pizza"
  Future<void> rememberFact(String fact) async {
    await load();
    _memory['facts'] ??= [];
    
    // Check for duplicates
    final facts = _memory['facts'] as List;
    if (!facts.any((f) => f['fact'] == fact)) {
      facts.add({
        'fact': fact,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _save();
    }
  }

  /// Remember a user instruction
  /// Example: "Always ask before making calls"
  Future<void> rememberInstruction(String instruction) async {
    await load();
    _memory['instructions'] ??= [];
    
    // Check for duplicates
    final instructions = _memory['instructions'] as List;
    if (!instructions.any((i) => i['instruction'] == instruction)) {
      instructions.add({
        'instruction': instruction,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _save();
    }
  }

  /// Remember device preference
  /// Example: {brightness: 50, theme: dark}
  Future<void> rememberDevicePreference(String key, dynamic value) async {
    await load();
    _memory['device_preferences'] ??= {};
    _memory['device_preferences'][key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _save();
  }

  /// Get all user preferences
  Future<Map<String, dynamic>> getPreferences() async {
    await load();
    final prefs = _memory['preferences'] as Map? ?? {};
    return prefs.map((k, v) => MapEntry(k, v is Map ? v['value'] : v));
  }

  /// Get a specific preference
  Future<String?> getPreference(String key) async {
    await load();
    final prefs = _memory['preferences'] as Map? ?? {};
    if (prefs.containsKey(key)) {
      final val = prefs[key];
      return val is Map ? val['value'] as String? : val as String?;
    }
    return null;
  }

  /// Get all facts
  Future<List<String>> getFacts() async {
    await load();
    final facts = _memory['facts'] as List? ?? [];
    return facts.map((f) => f is Map ? f['fact'] as String : f as String).toList();
  }

  /// Get all instructions
  Future<List<String>> getInstructions() async {
    await load();
    final instructions = _memory['instructions'] as List? ?? [];
    return instructions.map((i) => i is Map ? i['instruction'] as String : i as String).toList();
  }

  /// Get all device preferences
  Future<Map<String, dynamic>> getDevicePreferences() async {
    await load();
    final prefs = _memory['device_preferences'] as Map? ?? {};
    return prefs.map((k, v) => MapEntry(k, v is Map ? v['value'] : v));
  }

  /// Forget a specific memory
  Future<void> forgetFact(String fact) async {
    await load();
    final facts = _memory['facts'] as List? ?? [];
    facts.removeWhere((f) => f is Map ? f['fact'] == fact : f == fact);
    await _save();
  }

  /// Forget a specific instruction
  Future<void> forgetInstruction(String instruction) async {
    await load();
    final instructions = _memory['instructions'] as List? ?? [];
    instructions.removeWhere((i) => i is Map ? i['instruction'] == instruction : i == instruction);
    await _save();
  }

  /// Whether automatic memory capture is enabled.
  Future<bool> getAutomaticMemoryEnabled() async {
    await load();
    return _automaticMemoryEnabled;
  }

  /// Enable or disable automatic memory capture without deleting existing data.
  Future<void> setAutomaticMemoryEnabled(bool enabled) async {
    await load();
    _automaticMemoryEnabled = enabled;
    await _save();
  }

  /// Return editable, categorized records from the existing memory schema.
  Future<List<MemoryRecord>> getMemories() async {
    await load();
    final records = <MemoryRecord>[];
    final preferences = _memory['preferences'] as Map? ?? {};
    for (final entry in preferences.entries) {
      final raw = entry.value;
      records.add(MemoryRecord(
        id: 'preference:${entry.key}',
        category: 'preferences',
        value: raw is Map ? '${raw['value'] ?? ''}' : '$raw',
        reason: 'Saved as a user preference',
        timestamp: raw is Map
            ? DateTime.tryParse('${raw['timestamp'] ?? ''}')
            : null,
      ));
    }
    final facts = _memory['facts'] as List? ?? [];
    for (final item in facts) {
      final value = item is Map ? '${item['fact'] ?? ''}' : '$item';
      records.add(MemoryRecord(
        id: 'fact:$value',
        category: 'facts',
        value: value,
        reason: 'Saved as a user fact',
        timestamp: item is Map
            ? DateTime.tryParse('${item['timestamp'] ?? ''}')
            : null,
      ));
    }
    final instructions = _memory['instructions'] as List? ?? [];
    for (final item in instructions) {
      final value = item is Map ? '${item['instruction'] ?? ''}' : '$item';
      records.add(MemoryRecord(
        id: 'instruction:$value',
        category: 'instructions',
        value: value,
        reason: 'Saved as an agent instruction',
        timestamp: item is Map
            ? DateTime.tryParse('${item['timestamp'] ?? ''}')
            : null,
      ));
    }
    final device = _memory['device_preferences'] as Map? ?? {};
    for (final entry in device.entries) {
      final raw = entry.value;
      records.add(MemoryRecord(
        id: 'device:${entry.key}',
        category: 'device preferences',
        value: '${entry.key}: ${raw is Map ? raw['value'] ?? '' : raw}',
        reason: 'Saved as a device preference',
        timestamp: raw is Map
            ? DateTime.tryParse('${raw['timestamp'] ?? ''}')
            : null,
      ));
    }
    return List.unmodifiable(records);
  }

  /// Delete one record returned by getMemories.
  Future<void> deleteMemory(String id) async {
    await load();
    final separator = id.indexOf(':');
    if (separator <= 0) return;
    final kind = id.substring(0, separator);
    final value = id.substring(separator + 1);
    switch (kind) {
      case 'preference':
        (_memory['preferences'] as Map?)?.remove(value);
        break;
      case 'fact':
        (_memory['facts'] as List?)?.removeWhere((item) {
          final candidate = item is Map ? item['fact'] : item;
          return '$candidate' == value;
        });
        break;
      case 'instruction':
        (_memory['instructions'] as List?)?.removeWhere((item) {
          final candidate = item is Map ? item['instruction'] : item;
          return '$candidate' == value;
        });
        break;
      case 'device':
        (_memory['device_preferences'] as Map?)?.remove(value);
        break;
    }
    await _save();
  }

  /// Clear all user memory
  Future<void> clearAll() async {
    _memory = {
      'preferences': {},
      'facts': [],
      'instructions': [],
      'device_preferences': {},
    };
    await _save();
  }

  /// Get memory summary for context
  /// Returns a formatted string of all memory to include in AI context
  Future<String> getMemorySummary() async {
    await load();
    final buffer = StringBuffer();
    
    final prefs = await getPreferences();
    if (prefs.isNotEmpty) {
      buffer.writeln('User Preferences:');
      prefs.forEach((k, v) {
        buffer.writeln('  - $k: $v');
      });
    }
    
    final facts = await getFacts();
    if (facts.isNotEmpty) {
      buffer.writeln('User Facts:');
      facts.forEach((f) {
        buffer.writeln('  - $f');
      });
    }
    
    final instructions = await getInstructions();
    if (instructions.isNotEmpty) {
      buffer.writeln('User Instructions:');
      instructions.forEach((i) {
        buffer.writeln('  - $i');
      });
    }
    
    return buffer.toString();
  }
}


class MemoryRecord {
  final String id;
  final String category;
  final String value;
  final String reason;
  final DateTime? timestamp;

  const MemoryRecord({
    required this.id,
    required this.category,
    required this.value,
    required this.reason,
    this.timestamp,
  });
}
