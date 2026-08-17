import 'package:flutter/material.dart';

import '../services/artifact_service.dart';
import '../services/task_telemetry_service.dart';

/// A compact, expandable request-to-result workspace backed by the existing
/// TaskTelemetryService. It never renders raw prompts, file contents, or
/// credentials; all values arrive through the telemetry sanitizer.
class UnifiedTaskWorkspace extends StatelessWidget {
  final bool initiallyExpanded;

  const UnifiedTaskWorkspace({super.key, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ArtifactService.shared.init(),
      builder: (context, _) => ValueListenableBuilder<TaskDeveloperSnapshot>(
        valueListenable: TaskTelemetryService.shared.developerState,
        builder: (context, snapshot, _) {
          final accent = Theme.of(context).colorScheme.secondary;
          final hasWorkspaceData =
              snapshot.rootGoal.isNotEmpty ||
              snapshot.isRunning ||
              snapshot.upgradePlan != null ||
              snapshot.attachments.isNotEmpty ||
              snapshot.workspaceCommands.isNotEmpty;

          return Card(
            margin: const EdgeInsets.only(top: 12),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded || snapshot.isRunning,
              leading: Icon(Icons.account_tree_rounded, color: accent),
              title: const Text(
                'Unified Task Workspace',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                hasWorkspaceData
                    ? '${_label(snapshot.executionStage)} · ${_label(snapshot.status)}'
                    : 'Request-to-result context will appear here',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                _goalSection(context, snapshot),
                _executionSection(context, snapshot),
                _attachmentsSection(context, snapshot),
                _eventsSection(context, snapshot),
                _commandsSection(context, snapshot),
                _artifactsSection(context, snapshot),
                _artifactActionsSection(context),
                _validationSection(context, snapshot),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _artifactActionsSection(BuildContext context) {
    return ValueListenableBuilder<List<ArtifactRecord>>(
      valueListenable: ArtifactService.shared.artifacts,
      builder: (context, artifacts, _) {
        if (artifacts.isEmpty) return const SizedBox.shrink();
        return _section(
          context,
          icon: Icons.description_outlined,
          title: 'Generated artifacts',
          children: artifacts.take(8).map((artifact) {
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                artifact.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${artifact.kind} · ${artifact.size} bytes · ${artifact.validationState}',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    artifact.preview.isEmpty
                        ? 'Preview unavailable'
                        : artifact.preview,
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
                ButtonBar(
                  alignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final copied = await ArtifactService.shared.copy(
                          artifact,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              copied ? 'Artifact copied' : 'Nothing to copy',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final shared = await ArtifactService.shared.share(
                          artifact,
                        );
                        if (!context.mounted || shared) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sharing is unavailable'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _goalSection(BuildContext context, TaskDeveloperSnapshot snapshot) {
    return _section(
      context,
      icon: Icons.flag_outlined,
      title: 'Goal and plan',
      children: [
        _row('Root goal', _orUnknown(snapshot.rootGoal)),
        _row('Current sub-goal', _orUnknown(snapshot.currentSubGoal)),
        _row('Expected result', _orUnknown(snapshot.expectedResult)),
        _row('Current app/package', _orUnknown(snapshot.currentAppPackage)),
        _row('Execution stage', _orUnknown(snapshot.executionStage)),
      ],
    );
  }

  Widget _executionSection(
    BuildContext context,
    TaskDeveloperSnapshot snapshot,
  ) {
    final confidence = snapshot.confidence == null
        ? 'Not recorded'
        : '${(snapshot.confidence! * 100).toStringAsFixed(0)}%';
    final verification = snapshot.verificationPassed == null
        ? _orUnknown(snapshot.verificationResult)
        : '${snapshot.verificationPassed! ? 'Passed' : 'Not passed'} · ${_orUnknown(snapshot.verificationResult)}';

    return _section(
      context,
      icon: Icons.play_circle_outline_rounded,
      title: 'Live execution',
      children: [
        _row('Planned action', _orUnknown(snapshot.plannedAction)),
        _row('Selected target', _orUnknown(snapshot.selectedTarget)),
        _row('Confidence', confidence),
        _row('Verification', verification),
        _row(
          'Actions / observations',
          '${snapshot.actionCount} / ${snapshot.screenObservations}',
        ),
        _row(
          'AI calls / retries',
          '${snapshot.aiCalls} / ${snapshot.recoveryAttempts}',
        ),
        _row('Duration', '${snapshot.totalTaskDurationMs} ms'),
        if (snapshot.fastPathUsed)
          _row(
            'Fast path',
            '${_orUnknown(snapshot.fastPathName)} · ${snapshot.fastPathActions} actions · ${snapshot.aiCallsAvoided} AI call(s) avoided',
          ),
        if (snapshot.finalResult.isNotEmpty)
          _row('Final result', snapshot.finalResult),
      ],
    );
  }

  Widget _attachmentsSection(
    BuildContext context,
    TaskDeveloperSnapshot snapshot,
  ) {
    if (snapshot.attachments.isEmpty) return const SizedBox.shrink();
    return _section(
      context,
      icon: Icons.attach_file_rounded,
      title: 'Attached files',
      children: snapshot.attachments
          .map(
            (attachment) => _row(
              attachment.name,
              '${attachment.mimeType.isEmpty ? 'unknown type' : attachment.mimeType} · ${attachment.size} bytes\n${attachment.summary}',
            ),
          )
          .toList(),
    );
  }

  Widget _eventsSection(BuildContext context, TaskDeveloperSnapshot snapshot) {
    if (snapshot.events.isEmpty) return const SizedBox.shrink();
    final events = snapshot.events.reversed.take(12).toList();
    return _section(
      context,
      icon: Icons.timeline_rounded,
      title: 'Execution timeline',
      children: events
          .map(
            (event) => _row(
              _label(event.stage),
              '${_time(event.timestamp)} · ${event.detail}',
            ),
          )
          .toList(),
    );
  }

  Widget _commandsSection(
    BuildContext context,
    TaskDeveloperSnapshot snapshot,
  ) {
    if (snapshot.workspaceCommands.isEmpty) return const SizedBox.shrink();
    return _section(
      context,
      icon: Icons.terminal_rounded,
      title: 'Terminal and workspace activity',
      children: snapshot.workspaceCommands.reversed
          .take(8)
          .map(
            (command) => _row(
              '${command.succeeded ? 'Passed' : 'Failed'} · ${command.elapsedMs} ms',
              '${command.command}\n${command.workingDirectory}\n${command.output}',
            ),
          )
          .toList(),
    );
  }

  Widget _artifactsSection(
    BuildContext context,
    TaskDeveloperSnapshot snapshot,
  ) {
    final plan = snapshot.upgradePlan;
    if (plan == null && snapshot.upgradeHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    if (plan != null) {
      children.add(_row('Upgrade request', plan.request));
      children.add(
        _row(
          'Plan status',
          '${plan.status} · stage ${plan.currentStageIndex + 1}/${plan.stages.length}',
        ),
      );
      if (plan.impactedFiles.isNotEmpty) {
        children.add(_row('Impacted files', plan.impactedFiles.join(', ')));
      }
      for (final stage in plan.stages) {
        children.add(
          _row(
            '${stage.status} · ${stage.title}',
            '${stage.expectedResult}${stage.error.isEmpty ? '' : '\nError: ${stage.error}'}',
          ),
        );
      }
    }
    if (snapshot.upgradeHistory.isNotEmpty) {
      children.add(
        _row(
          'Rollback checkpoints',
          snapshot.upgradeHistory
              .take(6)
              .map(
                (entry) =>
                    '${entry.id} · ${entry.status} · ${entry.changeSummary}',
              )
              .join('\n'),
        ),
      );
    }
    return _section(
      context,
      icon: Icons.inventory_2_outlined,
      title: 'Artifacts and checkpoints',
      children: children,
    );
  }

  Widget _validationSection(
    BuildContext context,
    TaskDeveloperSnapshot snapshot,
  ) {
    final hasValidation =
        snapshot.upgradeStage.isNotEmpty ||
        snapshot.upgradeEvidence.isNotEmpty ||
        snapshot.errors.isNotEmpty ||
        snapshot.failureCategory.isNotEmpty;
    if (!hasValidation) return const SizedBox.shrink();
    final children = <Widget>[
      _row('Validation state', _orUnknown(snapshot.upgradeStage)),
      _row('Evidence', _orUnknown(snapshot.upgradeEvidence)),
      _row('Validation result', _orUnknown(snapshot.upgradeFinalResult)),
    ];
    if (snapshot.failureCategory.isNotEmpty) {
      children.add(_row('Failure category', snapshot.failureCategory));
      children.add(_row('Observed', _orUnknown(snapshot.diagnosisObserved)));
      children.add(
        _row('Likely cause', _orUnknown(snapshot.diagnosisLikelyCause)),
      );
      children.add(
        _row('Recovery attempt', _orUnknown(snapshot.diagnosisRecoveryAttempt)),
      );
      children.add(
        _row(
          'Diagnostic final result',
          _orUnknown(snapshot.diagnosisFinalResult),
        ),
      );
    }
    if (snapshot.errors.isNotEmpty) {
      children.add(_row('Errors', snapshot.errors.join('\n')));
    }
    return _section(
      context,
      icon: Icons.fact_check_outlined,
      title: 'Validation and diagnostics',
      children: children,
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  static String _orUnknown(String value) =>
      value.trim().isEmpty ? 'Not recorded' : value.trim();

  static String _label(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'idle';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  static String _time(DateTime timestamp) {
    final local = timestamp.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.hour}:$minute:$second';
  }
}
