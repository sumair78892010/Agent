import 'package:flutter/material.dart';

import '../services/attachment_service.dart';

/// Renders bounded, already-sanitized structured-data metadata.
/// It intentionally does not display raw rows, paths, or file contents.
class DataSummaryCard extends StatelessWidget {
  final AttachmentDataSummary summary;
  final String? attachmentName;

  const DataSummaryCard({
    super.key,
    required this.summary,
    this.attachmentName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numeric = summary.numericColumns.entries.toList(growable: false);
    final maxAverage = numeric.fold<double>(
      0,
      (max, entry) =>
          entry.value.average.abs() > max ? entry.value.average.abs() : max,
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  attachmentName == null
                      ? '${summary.format} analysis'
                      : '$attachmentName · ${summary.format} analysis',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatChip(label: 'Rows', value: '${summary.rowCount}'),
              _StatChip(label: 'Columns', value: '${summary.columnCount}'),
              if (numeric.isNotEmpty)
                _StatChip(label: 'Numeric', value: '${numeric.length}'),
            ],
          ),
          if (summary.columns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Columns',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary.columns.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (numeric.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Numeric summary',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            ...numeric.map(
              (entry) => _NumericRow(
                name: entry.key,
                value: entry.value,
                scale: maxAverage == 0
                    ? 0
                    : entry.value.average.abs() / maxAverage,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      '$label $value',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
    ),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
  );
}

class _NumericRow extends StatelessWidget {
  final String name;
  final NumericSummary value;
  final double scale;

  const _NumericRow({
    required this.name,
    required this.value,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'avg ${_format(value.average)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: scale.clamp(0, 1),
              minHeight: 5,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.08,
              ),
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            'min ${_format(value.minimum)} · max ${_format(value.maximum)} · n ${value.count}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
