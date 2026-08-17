import 'dart:convert';

import 'package:http/http.dart' as http;

/// A bounded, source-grounded web result. Raw page bodies are never retained.
class WebResearchSource {
  final String title;
  final String url;
  final String snippet;

  const WebResearchSource({
    required this.title,
    required this.url,
    required this.snippet,
  });

  Map<String, String> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
  };
}

class WebResearchResult {
  final String query;
  final List<WebResearchSource> sources;
  final DateTime fetchedAt;
  final String? error;

  const WebResearchResult({
    required this.query,
    required this.sources,
    required this.fetchedAt,
    this.error,
  });

  bool get hasSources => sources.isNotEmpty;

  /// Backward-compatible bounded summary for chat surfaces that expect an
  /// abstract-like field. The service retains only parsed snippets.
  String? get abstractText {
    if (sources.isEmpty) return null;
    final summary = sources.first.snippet.trim();
    return summary.isEmpty ? null : summary;
  }

  String toPromptContext() {
    if (sources.isEmpty) {
      return error == null
          ? 'No verified web sources were found for: $query'
          : 'Web research unavailable for "$query": $error';
    }
    final lines = <String>[
      'Source-grounded web research for: $query',
      'Use only the following retrieved sources and clearly distinguish them from general knowledge:',
    ];
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      lines.add('${index + 1}. ${source.title} — ${source.url}');
      if (source.snippet.isNotEmpty) lines.add('   ${source.snippet}');
    }
    return lines.join('\n');
  }
}

/// Performs bounded public web retrieval for explicit research requests.
/// This service does not log credentials, execute page instructions, or retain
/// full HTML responses.
class WebResearchService {
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxResults = 5;
  static const int _maxFieldLength = 500;

  WebResearchService({http.Client? client}) : _client = client ?? http.Client();

  Future<WebResearchResult> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return WebResearchResult(
        query: cleanQuery,
        sources: const [],
        fetchedAt: DateTime.now(),
        error: 'A non-empty query is required.',
      );
    }

    try {
      final uri = Uri.https('html.duckduckgo.com', '/html/', <String, String>{
        'q': cleanQuery,
      });
      final response = await _client
          .get(uri, headers: const {'User-Agent': 'Agent-Cypher/1.0'})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return WebResearchResult(
          query: cleanQuery,
          sources: const [],
          fetchedAt: DateTime.now(),
          error: 'Research endpoint returned HTTP ${response.statusCode}.',
        );
      }
      return WebResearchResult(
        query: cleanQuery,
        sources: _parseSources(response.body),
        fetchedAt: DateTime.now(),
      );
    } catch (error) {
      return WebResearchResult(
        query: cleanQuery,
        sources: const [],
        fetchedAt: DateTime.now(),
        error: 'Research request failed safely: ${_safeError(error)}',
      );
    }
  }

  List<WebResearchSource> _parseSources(String html) {
    final resultPattern = RegExp(
      r'''<a[^>]*class=["']result__a["'][^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    final sources = <WebResearchSource>[];
    for (final match in resultPattern.allMatches(html)) {
      if (sources.length >= _maxResults) break;
      final rawHref = _decodeHtml(match.group(1) ?? '');
      final url = _unwrapRedirect(rawHref);
      final title = _cleanText(match.group(2) ?? '');
      if (url.isEmpty || title.isEmpty || !url.startsWith('http')) continue;
      final start = match.end;
      final end = (start + 1800) > html.length ? html.length : start + 1800;
      final remaining = html.substring(start, end);
      final snippetMatch = RegExp(
        r'''class=["']result__snippet["'][^>]*>(.*?)</''',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(remaining);
      sources.add(
        WebResearchSource(
          title: _limit(title),
          url: _limit(url),
          snippet: _limit(_cleanText(snippetMatch?.group(1) ?? '')),
        ),
      );
    }
    return List.unmodifiable(sources);
  }

  String _unwrapRedirect(String value) {
    final uri = Uri.tryParse(value);
    final redirected = uri?.queryParameters['uddg'];
    return redirected == null || redirected.isEmpty
        ? value
        : Uri.decodeComponent(redirected);
  }

  String _cleanText(String value) {
    final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return _decodeHtml(withoutTags).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _limit(String value) => value.length <= _maxFieldLength
      ? value
      : '${value.substring(0, _maxFieldLength)}…';

  String _safeError(Object error) {
    final text = error.toString().replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    return jsonEncode(text.length <= 180 ? text : text.substring(0, 180));
  }
}
