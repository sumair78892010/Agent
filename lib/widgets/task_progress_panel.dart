import 'package:flutter/material.dart';
import '../services/task_telemetry_service.dart';

class TaskProgressPanel extends StatelessWidget {
  final bool isDark;
  final VoidCallback onStop;

  const TaskProgressPanel({
    super.key,
    required this.isDark,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TaskDeveloperSnapshot>(
      valueListenable: TaskTelemetryService.shared.developerState,
      builder: (context, snapshot, _) {
        if (!snapshot.isRunning && snapshot.status == 'idle') {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Processing your request…')),
                TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_rounded, size: 16),
                  label: const Text('Stop'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          );
        }

        const phases = <MapEntry<String, String>>[
          MapEntry('understanding', 'Understand'),
          MapEntry('planning', 'Plan'),
          MapEntry('screen_observation', 'Observe'),
          MapEntry('target_selection', 'Select target'),
          MapEntry('action', 'Perform action'),
          MapEntry('verification', 'Verify'),
          MapEntry('recovery', 'Recover'),
          MapEntry('complete', 'Complete'),
        ];
        final activeStage = switch (snapshot.executionStage) {
          'starting' => 'understanding',
          'ai_request' => 'planning',
          'fast_path' => 'action',
          _ => snapshot.executionStage,
        };
        final activeIndex = phases.indexWhere(
          (phase) => phase.key == activeStage,
        );
        final isFailure =
            snapshot.status == 'failed' ||
            activeStage == 'error' ||
            snapshot.failureCategory.isNotEmpty;
        final currentLabel = activeIndex >= 0
            ? phases[activeIndex].value
            : (isFailure ? 'Execution issue' : activeStage);
        final accent = isFailure ? Colors.orangeAccent : Colors.indigoAccent;

        Widget phaseIcon(int index) {
          final complete = activeIndex >= 0 && index < activeIndex;
          final current = activeIndex == index;
          return Icon(
            complete
                ? Icons.check_circle_rounded
                : current
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: complete || current ? accent : Colors.grey,
          );
        }

        Widget detailRow(String label, String value) {
          if (value.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              leading: Icon(Icons.route_rounded, color: accent),
              title: Text(
                snapshot.rootGoal.isEmpty ? currentLabel : snapshot.rootGoal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                isFailure
                    ? 'Issue detected · $currentLabel'
                    : 'Observable execution · $currentLabel',
                style: TextStyle(color: accent, fontSize: 11),
              ),
              trailing: TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_rounded, size: 16),
                label: const Text('Stop'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      for (var index = 0; index < phases.length; index++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            phaseIcon(index),
                            const SizedBox(width: 4),
                            Text(
                              phases[index].value,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Observable execution details',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                detailRow('Sub-goal', snapshot.currentSubGoal),
                detailRow('App', snapshot.currentAppPackage),
                detailRow('Action', snapshot.plannedAction),
                detailRow('Target', snapshot.selectedTarget),
                detailRow('Expected', snapshot.expectedResult),
                detailRow('Verification', snapshot.verificationResult),
                if (snapshot.recoveryAttempts > 0)
                  detailRow(
                    'Recovery attempts',
                    '${snapshot.recoveryAttempts}',
                  ),
                if (isFailure) ...[
                  detailRow('What failed', snapshot.diagnosisObserved),
                  detailRow('Detected', snapshot.diagnosisEvidence),
                  detailRow(
                    'Retry/recovery',
                    snapshot.diagnosisRecoveryAttempt,
                  ),
                  detailRow(
                    'Final result',
                    snapshot.diagnosisFinalResult.isEmpty
                        ? snapshot.finalResult
                        : snapshot.diagnosisFinalResult,
                  ),
                ],
                if (snapshot.errors.isNotEmpty)
                  detailRow('Recent error', snapshot.errors.last),
                const SizedBox(height: 6),
                Text(
                  'Open Developer Mode for Terminal/Workspace, artifacts, and full telemetry.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
