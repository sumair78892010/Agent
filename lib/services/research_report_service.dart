import 'attachment_service.dart';
import 'artifact_service.dart';
import 'web_research_service.dart';

/// A bounded source-grounded report assembled from existing research results
/// and attachment summaries. It does not claim conclusions beyond its evidence.
enum EvidenceDisposition { supporting, conflicting, unresolved }

enum EvidenceConfidence { high, medium, low }

class _EvidenceItem {
  final WebResearchSource source;
  final DateTime fetchedAt;

  const _EvidenceItem(this.source, this.fetchedAt);
}

class ResearchEvidenceGroup {
  final String topic;
  final List<WebResearchSource> sources;
  final EvidenceDisposition disposition;
  final EvidenceConfidence confidence;
  final bool fresh;

  const ResearchEvidenceGroup({
    required this.topic,
    required this.sources,
    required this.disposition,
    required this.confidence,
    required this.fresh,
  });

  String get dispositionLabel => disposition.name;
  String get confidenceLabel => confidence.name;
}

class ResearchReport {
  final String goal;
  final List<WebResearchResult> researchResults;
  final List<AttachmentInspection> attachmentInspections;
  final DateTime createdAt;
  final String status;
  final List<String> limitations;
  final List<ResearchEvidenceGroup> evidenceGroups;
  final int duplicateSourceCount;

  const ResearchReport({
    required this.goal,
    required this.researchResults,
    required this.attachmentInspections,
    required this.createdAt,
    required this.status,
    required this.limitations,
    this.evidenceGroups = const [],
    this.duplicateSourceCount = 0,
  });

  bool get hasEvidence =>
      researchResults.any((result) => result.sources.isNotEmpty) ||
      attachmentInspections.isNotEmpty;

  int get sourceCount => researchResults.fold<int>(
    0,
    (total, result) => total + result.sources.length,
  );

  String toMarkdown() {
    final output = StringBuffer()
      ..writeln('# Research Report')
      ..writeln()
      ..writeln('**Goal:** ${_clean(goal)}')
      ..writeln('**Status:** $status')
      ..writeln('**Created:** ${createdAt.toUtc().toIso8601String()}')
      ..writeln();

    if (researchResults.isNotEmpty) {
      output
        ..writeln('## Public-source evidence')
        ..writeln();
      var citation = 1;
      for (final result in researchResults) {
        output
          ..writeln('### Query: ${_clean(result.query)}')
          ..writeln();
        if (result.sources.isEmpty) {
          output.writeln(
            '- No verified public sources returned${result.error == null ? '.' : ': ${_clean(result.error!)}'}',
          );
          output.writeln();
          continue;
        }
        for (final source in result.sources) {
          output
            ..writeln('$citation. **${_clean(source.title)}**')
            ..writeln('   - ${_clean(source.snippet)}')
            ..writeln('   - Source: ${_safeUrl(source.url)}');
          citation++;
        }
        output.writeln();
      }
    }

    if (evidenceGroups.isNotEmpty) {
      output
        ..writeln('## Evidence comparison')
        ..writeln()
        ..writeln(
          'Comparison is deterministic and based only on retrieved snippets, source URLs, and retrieval time; it is not a claim of human-level fact checking.',
        )
        ..writeln();
      if (duplicateSourceCount > 0) {
        output.writeln(
          '- Removed $duplicateSourceCount duplicate or near-duplicate source result(s).',
        );
      }
      for (final group in evidenceGroups.take(12)) {
        output..writeln(
          '- **${_clean(group.topic)}** — ${group.dispositionLabel}, ${group.confidenceLabel} confidence, ${group.fresh ? 'fresh' : 'older'} evidence (${group.sources.length} source(s)).',
        );
      }
      output.writeln();
    }

    if (attachmentInspections.isNotEmpty) {
      output
        ..writeln('## Local attachment evidence')
        ..writeln();
      for (final inspection in attachmentInspections) {
        output.writeln(
          '- **${_clean(inspection.attachment.name)}:** ${_clean(inspection.summary)}',
        );
        final summary = inspection.dataSummary;
        if (summary != null) {
          output.writeln('  - ${_clean(summary.promptDescription)}');
        }
      }
      output.writeln();
    }

    output
      ..writeln('## Limitations')
      ..writeln();
    if (limitations.isEmpty) {
      output.writeln(
        '- Results are bounded excerpts and are not a substitute for reading the linked sources.',
      );
    } else {
      for (final limitation in limitations.take(8)) {
        output.writeln('- ${_clean(limitation)}');
      }
    }
    return _bounded(output.toString());
  }

  static String _clean(String value) => ArtifactService.sanitize(value).trim();

  static String _safeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '[UNSAFE_URL_REDACTED]';
    }
    return _clean(value);
  }

  static String _bounded(String value) => value.length <= 24000
      ? value
      : '${value.substring(0, 24000)}\n\n[REPORT_TRUNCATED]';
}

class ResearchReportService {
  static const int maxQueries = 3;
  static const int maxAttachments = 5;

  final WebResearchService webResearchService;
  final AttachmentService attachmentService;
  final ArtifactService artifactService;

  ResearchReportService({
    WebResearchService? webResearchService,
    AttachmentService? attachmentService,
    ArtifactService? artifactService,
  }) : webResearchService = webResearchService ?? WebResearchService(),
       attachmentService = attachmentService ?? AttachmentService(),
       artifactService = artifactService ?? ArtifactService.shared;

  Future<ResearchReport> createReport({
    required String goal,
    List<String> queries = const [],
    List<AttachmentReference> attachments = const [],
  }) async {
    final cleanGoal = ArtifactService.sanitize(goal.trim());
    if (cleanGoal.isEmpty) {
      return ResearchReport(
        goal: '',
        researchResults: const [],
        attachmentInspections: const [],
        createdAt: DateTime.now().toUtc(),
        status: 'failed',
        limitations: const ['A non-empty research goal is required.'],
      );
    }

    final normalizedQueries = <String>[];
    for (final query in [if (queries.isEmpty) cleanGoal, ...queries]) {
      final cleanQuery = ArtifactService.sanitize(query.trim());
      if (cleanQuery.isEmpty || normalizedQueries.contains(cleanQuery))
        continue;
      normalizedQueries.add(cleanQuery);
      if (normalizedQueries.length >= maxQueries) break;
    }

    final results = <WebResearchResult>[];
    for (final query in normalizedQueries) {
      try {
        results.add(await webResearchService.search(query));
      } catch (error) {
        results.add(
          WebResearchResult(
            query: query,
            sources: const [],
            fetchedAt: DateTime.now(),
            error: 'Research query failed safely: ${_safeError(error)}',
          ),
        );
      }
    }

    final inspections = <AttachmentInspection>[];
    for (final attachment in attachments.take(maxAttachments)) {
      try {
        inspections.add(await attachmentService.inspect(attachment));
      } catch (_) {
        // A single unavailable attachment must not cancel public research.
      }
    }

    final sourceCount = results.fold<int>(
      0,
      (total, result) => total + result.sources.length,
    );
    final hasErrors = results.any((result) => result.error != null);
    final status = sourceCount > 0 || inspections.isNotEmpty
        ? (hasErrors ? 'partial' : 'complete')
        : 'no_evidence';
    final evidenceGroups = _compareEvidence(results);
    final duplicateSourceCount = _countDuplicateSources(results);
    final limitations = <String>[
      'Only bounded public-source snippets were retrieved; full pages were not retained.',
      if (duplicateSourceCount > 0)
        'Duplicate source URLs were collapsed before comparison.',
      if (evidenceGroups.any(
        (group) => group.disposition == EvidenceDisposition.conflicting,
      ))
        'Some sources contain explicit opposing language; verify the original pages before acting.',
      if (hasErrors)
        'One or more research queries failed or returned no sources.',
      if (attachments.isNotEmpty)
        'Attachment evidence is limited to safe inspection summaries and previews.',
      'Important claims should be checked against the linked sources.',
    ];

    return ResearchReport(
      goal: cleanGoal,
      researchResults: List.unmodifiable(results),
      attachmentInspections: List.unmodifiable(inspections),
      createdAt: DateTime.now().toUtc(),
      status: status,
      limitations: List.unmodifiable(limitations),
      evidenceGroups: List.unmodifiable(evidenceGroups),
      duplicateSourceCount: duplicateSourceCount,
    );
  }

  List<ResearchEvidenceGroup> _compareEvidence(
    List<WebResearchResult> results,
  ) {
    final unique = <String, _EvidenceItem>{};
    for (final result in results) {
      for (final source in result.sources) {
        final key = _canonicalUrl(source.url);
        final existing = unique[key];
        if (existing == null ||
            source.snippet.length > existing.source.snippet.length) {
          unique[key] = _EvidenceItem(source, result.fetchedAt.toUtc());
        }
      }
    }
    final groups = <ResearchEvidenceGroup>[];
    final freshnessCutoff = DateTime.now().toUtc().subtract(
      const Duration(hours: 24),
    );
    for (final item in unique.values) {
      final source = item.source;
      final topic = _topicKey(source);
      final index = groups.indexWhere((group) => group.topic == topic);
      if (index == -1) {
        groups.add(
          ResearchEvidenceGroup(
            topic: topic,
            sources: [source],
            disposition: _disposition(source.snippet),
            confidence: EvidenceConfidence.low,
            fresh: item.fetchedAt.isAfter(freshnessCutoff),
          ),
        );
        continue;
      }
      final current = groups[index];
      final sources = [...current.sources, source];
      final hasOpposing =
          current.disposition == EvidenceDisposition.conflicting ||
          _hasOpposingPolarity(current.sources.first.snippet, source.snippet);
      groups[index] = ResearchEvidenceGroup(
        topic: current.topic,
        sources: List.unmodifiable(sources),
        disposition: hasOpposing
            ? EvidenceDisposition.conflicting
            : EvidenceDisposition.supporting,
        confidence: sources.length >= 3
            ? EvidenceConfidence.high
            : EvidenceConfidence.medium,
        fresh: current.fresh || item.fetchedAt.isAfter(freshnessCutoff),
      );
    }
    return groups;
  }

  int _countDuplicateSources(List<WebResearchResult> results) {
    final total = results.fold<int>(
      0,
      (sum, result) => sum + result.sources.length,
    );
    final keys = <String>{
      for (final result in results)
        for (final source in result.sources) _canonicalUrl(source.url),
    };
    return total - keys.length;
  }

  String _canonicalUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return value.trim().toLowerCase();
    final path = uri.path.isEmpty ? '/' : uri.path;
    return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$path';
  }

  String _topicKey(WebResearchSource source) {
    final words = source.snippet
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .take(8)
        .toList();
    return words.isEmpty ? source.title.trim() : words.join(' ');
  }

  EvidenceDisposition _disposition(String snippet) =>
      _negativePattern.hasMatch(snippet)
      ? EvidenceDisposition.unresolved
      : EvidenceDisposition.supporting;

  bool _hasOpposingPolarity(String first, String second) {
    final firstNegative = _negativePattern.hasMatch(first);
    final secondNegative = _negativePattern.hasMatch(second);
    return firstNegative != secondNegative &&
        _positivePattern.hasMatch(first) &&
        _positivePattern.hasMatch(second);
  }

  static final _negativePattern = RegExp(
    r'\b(no|not|never|false|denied|unsupported|cannot|failed)\b',
    caseSensitive: false,
  );
  static final _positivePattern = RegExp(
    r'\b(is|are|true|confirmed|supported|available|successful)\b',
    caseSensitive: false,
  );

  Future<ArtifactRecord?> exportReport(ResearchReport report) {
    return artifactService.exportText(
      name: 'research_report.md',
      kind: 'markdown',
      content: report.toMarkdown(),
      sourceTask: report.goal,
      validationState: report.status,
    );
  }

  Future<ArtifactRecord?> createAndExport({
    required String goal,
    List<String> queries = const [],
    List<AttachmentReference> attachments = const [],
  }) async {
    final report = await createReport(
      goal: goal,
      queries: queries,
      attachments: attachments,
    );
    return exportReport(report);
  }

  String _safeError(Object error) {
    final sanitized = ArtifactService.sanitize(error.toString());
    return sanitized.length <= 180 ? sanitized : sanitized.substring(0, 180);
  }
}
