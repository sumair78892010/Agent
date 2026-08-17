class AgentAction {
  final String id;
  final String action;
  final Map<String, dynamic> params;
  final String response;

  AgentAction({
    String? id,
    required this.action,
    required this.params,
    required this.response,
  }) : id = id ?? 'action_${DateTime.now().millisecondsSinceEpoch}';

  factory AgentAction.fromJson(Map<String, dynamic> json) {
    return AgentAction(
      id: json['id'] as String?,
      action: json['action'] as String? ?? 'general_query',
      params: json['params'] as Map<String, dynamic>? ?? {},
      response: json['response'] as String? ?? '',
    );
  }

  static const List<String> availableActions = [
    'open_app',
    'make_call',
    'send_sms',
    'search_contact',
    'set_alarm',
    'set_volume',
    'set_brightness',
    'read_notifications',
    'read_screen',
    'run_adb_command',
    'general_query',
  ];
}
