import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../lib/services/research_report_service.dart';
import '../lib/services/web_research_service.dart';

class _ResearchClient extends http.BaseClient {
  final int statusCode;
  final String body;

  _ResearchClient({this.statusCode = 200, this.body = _html});

  static const _html = '''
  <a class="result__a" href="https://example.com/one">First result</a>
  <div class="result__snippet">A bounded source snippet.</div>
  <a class="result__a" href="https://example.com/two">Second result</a>
  <div class="result__snippet">Another bounded source snippet.</div>
  ''';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(body.codeUnits),
      statusCode,
      request: request,
    );
  }
}

void main() {
  test(
    'research report bounds queries and preserves source citations',
    () async {
      final service = ResearchReportService(
        webResearchService: WebResearchService(client: _ResearchClient()),
      );

      final report = await service.createReport(
        goal: 'Compare reliable tools',
        queries: const ['one', 'two', 'three', 'four', 'five'],
      );

      expect(report.status, 'complete');
      expect(report.researchResults.length, 3);
      expect(report.sourceCount, 6);
      expect(report.toMarkdown(), contains('https://example.com/one'));
      expect(report.toMarkdown(), contains('Important claims'));
    },
  );

  test(
    'research report fails safely and states no-evidence limitations',
    () async {
      final service = ResearchReportService(
        webResearchService: WebResearchService(
          client: _ResearchClient(statusCode: 503, body: ''),
        ),
      );

      final report = await service.createReport(goal: 'Unavailable sources');

      expect(report.status, 'no_evidence');
      expect(report.sourceCount, 0);
      expect(report.toMarkdown(), contains('No verified public sources'));
      expect(report.toMarkdown(), contains('Limitations'));
    },
  );

  test('comparison collapses duplicates and flags opposing evidence', () async {
    final service = ResearchReportService(
      webResearchService: WebResearchService(
        client: _ResearchClient(
          body: '''
          <a class="result__a" href="https://example.com/fact">Service is supported today</a>
          <div class="result__snippet">Service is supported today.</div>
          <a class="result__a" href="https://example.com/other">Service is not supported today</a>
          <div class="result__snippet">Service is not supported today.</div>
          ''',
        ),
      ),
    );

    final report = await service.createReport(
      goal: 'Compare service support',
      queries: const ['support one', 'support two'],
    );

    expect(report.duplicateSourceCount, 2);
    expect(report.evidenceGroups, hasLength(1));
    expect(
      report.evidenceGroups.single.disposition,
      EvidenceDisposition.conflicting,
    );
    expect(report.evidenceGroups.single.confidence, EvidenceConfidence.medium);
    expect(report.toMarkdown(), contains('conflicting'));
    expect(report.toMarkdown(), contains('verify the original pages'));
  });

  test('report markdown redacts secrets and unsafe URLs', () {
    final report = ResearchReport(
      goal: 'api_key=do-not-show',
      researchResults: [
        WebResearchResult(
          query: 'token=private',
          sources: const [
            WebResearchSource(
              title: 'Safe title',
              url: 'javascript:private',
              snippet: 'Bearer private-token',
            ),
          ],
          fetchedAt: DateTime.utc(2026, 8, 16),
        ),
      ],
      attachmentInspections: const [],
      createdAt: DateTime.utc(2026, 8, 16),
      status: 'complete',
      limitations: const [],
    );

    final markdown = report.toMarkdown();

    expect(markdown, contains('[REDACTED_SECRET]'));
    expect(markdown, isNot(contains('private-token')));
    expect(markdown, contains('[UNSAFE_URL_REDACTED]'));
  });
}
