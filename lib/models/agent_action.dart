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
    'launch_package',
    'make_call',
    'send_sms',
    'search_contact',
    'send_email',
    'set_alarm',
    'set_timer',
    'set_volume',
    'set_brightness',
    'read_screen',
    'click_element',
    'type_on_screen',
    'scroll_screen',
    'press_back',
    'execute_task',
    'read_file',
    'write_file',
    'list_directory',
    'create_directory',
    'copy_file',
    'move_file',
    'delete_file',
    'search_files',
    'run_adb_command',
    'search',
    'open_url',
    'get_page_content',
    'navigate_back',
    'general_query',
  ];
}
