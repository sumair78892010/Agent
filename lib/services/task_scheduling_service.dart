import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Task scheduling and automation service
/// Per spec section 23: Scheduled tasks, reminders, routines
class TaskSchedulingService {
  static final TaskSchedulingService _instance = TaskSchedulingService._internal();

  factory TaskSchedulingService() {
    return _instance;
  }

  TaskSchedulingService._internal();

  final Map<String, ScheduledTask> _tasks = {};
  final Map<String, Timer> _timers = {};
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedTasks();
  }

  /// Schedule a one-time task
  Future<void> scheduleOnce(
    String taskId,
    String name,
    DateTime executionTime,
    Future<void> Function() onExecute,
  ) async {
    final task = ScheduledTask(
      id: taskId,
      name: name,
      type: ScheduleType.once,
      executionTime: executionTime,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    await _saveTask(task);
    _scheduleExecution(taskId, onExecute);
  }

  /// Schedule a recurring task
  Future<void> scheduleRecurring(
    String taskId,
    String name,
    RecurringSchedule schedule,
    Future<void> Function() onExecute,
  ) async {
    final task = ScheduledTask(
      id: taskId,
      name: name,
      type: ScheduleType.recurring,
      recurringSchedule: schedule,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    await _saveTask(task);
    _scheduleRecurring(taskId, schedule, onExecute);
  }

  /// Schedule a task with time-based trigger
  Future<void> scheduleByTime(
    String taskId,
    String name,
    int hour,
    int minute,
    Future<void> Function() onExecute, {
    List<String> daysOfWeek = const [],
  }) async {
    final schedule = RecurringSchedule(
      type: 'daily',
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
    );

    await scheduleRecurring(taskId, name, schedule, onExecute);
  }

  /// Schedule a task based on battery level
  Future<void> scheduleByBattery(
    String taskId,
    String name,
    int batteryThreshold,
    Future<void> Function() onExecute,
  ) async {
    final task = ScheduledTask(
      id: taskId,
      name: name,
      type: ScheduleType.battery,
      batteryThreshold: batteryThreshold,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    await _saveTask(task);
    // Battery monitoring would be implemented by app
  }

  /// Schedule a task based on app launch
  Future<void> scheduleByAppLaunch(
    String taskId,
    String name,
    String packageName,
    Future<void> Function() onExecute,
  ) async {
    final task = ScheduledTask(
      id: taskId,
      name: name,
      type: ScheduleType.appLaunch,
      triggerPackage: packageName,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    await _saveTask(task);
  }

  /// Cancel a scheduled task
  Future<void> cancel(String taskId) async {
    if (_timers.containsKey(taskId)) {
      _timers[taskId]?.cancel();
      _timers.remove(taskId);
    }

    _tasks.remove(taskId);
    
    final key = 'task_$taskId';
    await _prefs.remove(key);
  }

  /// Get a scheduled task
  ScheduledTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// Get all scheduled tasks
  List<ScheduledTask> getAllTasks() {
    return _tasks.values.toList();
  }

  /// Get upcoming tasks (next 24 hours)
  List<ScheduledTask> getUpcomingTasks() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return _tasks.values.where((task) {
      if (task.type == ScheduleType.once) {
        return task.executionTime != null &&
            task.executionTime!.isAfter(now) &&
            task.executionTime!.isBefore(tomorrow);
      }
      return false;
    }).toList();
  }

  /// Mark task as completed
  Future<void> markCompleted(String taskId) async {
    if (_tasks.containsKey(taskId)) {
      final task = _tasks[taskId]!;
      task.lastExecuted = DateTime.now();
      task.executionCount = (task.executionCount ?? 0) + 1;
      await _saveTask(task);
    }
  }

  /// Pause a task
  Future<void> pause(String taskId) async {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId]!.isPaused = true;
      await _saveTask(_tasks[taskId]!);
    }
  }

  /// Resume a paused task
  Future<void> resume(String taskId) async {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId]!.isPaused = false;
      await _saveTask(_tasks[taskId]!);
    }
  }

  // Private methods

  void _scheduleExecution(String taskId, Future<void> Function() onExecute) {
    final task = _tasks[taskId];
    if (task == null || task.type != ScheduleType.once || task.executionTime == null) {
      return;
    }

    final now = DateTime.now();
    final delay = task.executionTime!.difference(now);

    if (delay.isNegative) {
      // Time already passed, execute immediately
      _executeTask(taskId, onExecute);
    } else {
      // Schedule for future
      _timers[taskId] = Timer(delay, () => _executeTask(taskId, onExecute));
    }
  }

  void _scheduleRecurring(
    String taskId,
    RecurringSchedule schedule,
    Future<void> Function() onExecute,
  ) {
    // Calculate next execution time
    final nextTime = _calculateNextExecutionTime(schedule);
    final now = DateTime.now();
    final delay = nextTime.difference(now);

    // Schedule first execution
    _timers[taskId] = Timer(delay, () {
      _executeTask(taskId, onExecute);
      // Reschedule after execution
      _scheduleRecurring(taskId, schedule, onExecute);
    });
  }

  Future<void> _executeTask(String taskId, Future<void> Function() onExecute) async {
    final task = _tasks[taskId];
    if (task == null || task.isPaused) {
      return;
    }

    try {
      await onExecute();
      await markCompleted(taskId);
    } catch (e) {
      task.lastError = e.toString();
      await _saveTask(task);
    }
  }

  DateTime _calculateNextExecutionTime(RecurringSchedule schedule) {
    final now = DateTime.now();

    if (schedule.type == 'daily') {
      var nextTime = DateTime(now.year, now.month, now.day, schedule.hour ?? 0, schedule.minute ?? 0);

      // If time has already passed today, schedule for tomorrow
      if (nextTime.isBefore(now)) {
        nextTime = nextTime.add(const Duration(days: 1));
      }

      // Check if it should skip based on daysOfWeek
      if (schedule.daysOfWeek != null && schedule.daysOfWeek!.isNotEmpty) {
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        
        while (!schedule.daysOfWeek!.contains(dayNames[nextTime.weekday - 1])) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
      }

      return nextTime;
    } else if (schedule.type == 'hourly') {
      return now.add(Duration(hours: schedule.intervalHours ?? 1));
    } else if (schedule.type == 'weekly') {
      return now.add(Duration(days: 7));
    }

    return now.add(const Duration(days: 1));
  }

  Future<void> _saveTask(ScheduledTask task) async {
    final key = 'task_${task.id}';
    final json = task.toJson();
    await _prefs.setString(key, _jsonEncode(json));
  }

  Future<void> _loadSavedTasks() async {
    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('task_')) {
        final jsonStr = _prefs.getString(key);
        if (jsonStr != null) {
          try {
            final task = ScheduledTask.fromJson(_jsonDecode(jsonStr));
            _tasks[task.id] = task;
          } catch (e) {
            // Skip malformed tasks
          }
        }
      }
    }
  }

  String _jsonEncode(Map<String, dynamic> data) {
    // Use proper JSON encoding via dart:convert
    return jsonEncode(data);
  }

  Map<String, dynamic> _jsonDecode(String jsonStr) {
    // Use proper JSON decoding via dart:convert
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to decode JSON: $e');
    }
  }
}

/// Types of scheduled tasks
enum ScheduleType {
  once,
  recurring,
  battery,
  appLaunch,
  location,
}

/// Information about a scheduled task
class ScheduledTask {
  final String id;
  final String name;
  final ScheduleType type;
  
  // For one-time tasks
  DateTime? executionTime;
  
  // For recurring tasks
  RecurringSchedule? recurringSchedule;
  
  // For battery-based tasks
  int? batteryThreshold;
  
  // For app launch tasks
  String? triggerPackage;
  
  // Common fields
  final DateTime createdAt;
  DateTime? lastExecuted;
  int? executionCount;
  bool isPaused;
  String? lastError;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.type,
    this.executionTime,
    this.recurringSchedule,
    this.batteryThreshold,
    this.triggerPackage,
    required this.createdAt,
    this.lastExecuted,
    this.executionCount,
    this.isPaused = false,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString(),
    'executionTime': executionTime?.toIso8601String(),
    'recurringSchedule': recurringSchedule?.toJson(),
    'batteryThreshold': batteryThreshold,
    'triggerPackage': triggerPackage,
    'createdAt': createdAt.toIso8601String(),
    'lastExecuted': lastExecuted?.toIso8601String(),
    'executionCount': executionCount,
    'isPaused': isPaused,
    'lastError': lastError,
  };

  static ScheduledTask fromJson(Map<String, dynamic> json) {
    final recurringJson = json['recurringSchedule'] as Map<String, dynamic>?;
    final recurringSchedule = recurringJson != null
        ? RecurringSchedule.fromJson(recurringJson)
        : null;

    return ScheduledTask(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ScheduleType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ScheduleType.once,
      ),
      executionTime: json['executionTime'] != null
          ? DateTime.parse(json['executionTime'] as String)
          : null,
      recurringSchedule: recurringSchedule,
      batteryThreshold: json['batteryThreshold'] as int?,
      triggerPackage: json['triggerPackage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastExecuted: json['lastExecuted'] != null
          ? DateTime.parse(json['lastExecuted'] as String)
          : null,
      executionCount: json['executionCount'] as int?,
      isPaused: json['isPaused'] as bool? ?? false,
      lastError: json['lastError'] as String?,
    );
  }

  String get statusText {
    if (isPaused) return 'Paused';
    if (executionCount != null && executionCount! > 0) return 'Running';
    return 'Scheduled';
  }

  String get nextExecutionText {
    if (type == ScheduleType.once) {
      return executionTime?.toString() ?? 'Unknown';
    } else if (type == ScheduleType.recurring) {
      return recurringSchedule?.description ?? 'Daily';
    }
    return '-';
  }
}

/// Recurring schedule configuration
class RecurringSchedule {
  final String type; // 'daily', 'weekly', 'hourly'
  final int? hour;
  final int? minute;
  final int? intervalHours;
  final List<String>? daysOfWeek; // e.g., ['Monday', 'Friday']

  RecurringSchedule({
    required this.type,
    this.hour,
    this.minute,
    this.intervalHours,
    this.daysOfWeek,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'hour': hour,
    'minute': minute,
    'intervalHours': intervalHours,
    'daysOfWeek': daysOfWeek,
  };

  static RecurringSchedule fromJson(Map<String, dynamic> json) {
    return RecurringSchedule(
      type: json['type'] as String,
      hour: json['hour'] as int?,
      minute: json['minute'] as int?,
      intervalHours: json['intervalHours'] as int?,
      daysOfWeek: List<String>.from(json['daysOfWeek'] as List? ?? []),
    );
  }

  String get description {
    if (type == 'daily') {
      if (hour != null && minute != null) {
        return 'Daily at $hour:${minute.toString().padLeft(2, '0')}';
      }
    } else if (type == 'hourly') {
      return 'Every ${intervalHours ?? 1} hour(s)';
    } else if (type == 'weekly') {
      return 'Weekly';
    }
    return 'Recurring';
  }
}
