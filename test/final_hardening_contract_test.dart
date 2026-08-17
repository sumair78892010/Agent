import 'package:flutter_test/flutter_test.dart';
import 'package:agent_cypher/models/agent_action.dart';
import 'package:agent_cypher/services/action_handler.dart';
import 'package:agent_cypher/services/task_executor.dart';

void main() {
  test('target confidence requires a bounded meaningful score', () {
    expect(hasSufficientTargetConfidence('click_text', null), isFalse);
    expect(hasSufficientTargetConfidence('click_text', 0.64), isFalse);
    expect(hasSufficientTargetConfidence('click_text', 0.65), isTrue);
    expect(hasSufficientTargetConfidence('click_at', 0.91), isTrue);
    expect(hasSufficientTargetConfidence('click_at', 1.01), isFalse);
    expect(hasSufficientTargetConfidence('press_back', null), isTrue);
  });

  test(
    'unsupported actions fail safely instead of being reported as success',
    () async {
      final result = await ActionHandler().execute(
        AgentAction(
          action: 'unknown_action',
          params: const {},
          response: 'unsupported',
        ),
      );

      expect(result.success, isFalse);
      expect(result.details, contains('Unsupported action'));
    },
  );
}
