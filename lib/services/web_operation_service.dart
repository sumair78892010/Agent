import 'package:url_launcher/url_launcher.dart';
import 'screen_automation_service.dart';

/// Web automation and search service
/// Per spec section 22: Web operations with safety constraints
class WebOperationService {
  final ScreenAutomationService _screenService = ScreenAutomationService();

  // Supported search engines
  static const Map<String, String> searchEngines = {
    'google': 'https://www.google.com/search?q=',
    'bing': 'https://www.bing.com/search?q=',
    'duckduckgo': 'https://duckduckgo.com/?q=',
    'youtube': 'https://www.youtube.com/results?search_query=',
    'wikipedia':
        'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=',
  };

  /// Search using specified search engine
  /// Returns true if search was launched successfully
  Future<bool> search(String query, {String engine = 'google'}) async {
    try {
      final searchUrl = searchEngines[engine];
      if (searchUrl == null) return false;

      final encoded = Uri.encodeComponent(query);
      final url = '$searchUrl$encoded';

      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      return false;
    }
  }

  /// Search on Google
  Future<bool> googleSearch(String query) => search(query, engine: 'google');

  /// Search on YouTube
  Future<bool> youtubeSearch(String query) => search(query, engine: 'youtube');

  /// Search on Wikipedia
  Future<bool> wikipediaSearch(String query) =>
      search(query, engine: 'wikipedia');

  /// Open URL in browser
  Future<bool> openUrl(String url) async {
    try {
      // Ensure URL has scheme
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }

      return await launchUrl(
        Uri.parse(finalUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get current browser/web view URL
  /// This reads from screen automation if browser is open
  Future<String?> getCurrentUrl() async {
    try {
      final screenDesc = await _screenService.getScreenDescription();

      // Look for URL patterns in screen content
      final urlPattern = RegExp(r'https?://[^\s]+');
      final match = urlPattern.firstMatch(screenDesc);

      if (match != null) {
        return match.group(0);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Navigate to URL (tap on address bar and enter)
  Future<bool> navigateTo(String url) async {
    try {
      // This would require screen automation to click the address bar and type
      // For now, we use launchUrl which is the most reliable method
      return await openUrl(url);
    } catch (e) {
      return false;
    }
  }

  /// Refresh current page
  /// Uses Android's system-wide refresh gesture (pull-down from top)
  /// instead of pressing Enter, which is not a refresh action.
  Future<bool> refreshPage() async {
    try {
      // Swipe down from the top edge of the screen to trigger a refresh.
      return await _screenService.swipe(540, 200, 540, 800);
    } catch (e) {
      return false;
    }
  }

  /// Go back in browser history
  Future<bool> goBack() async {
    try {
      return await _screenService.pressBack();
    } catch (e) {
      return false;
    }
  }

  /// Scroll down on web page
  Future<bool> scrollDown({String direction = 'down'}) async {
    try {
      return await _screenService.scroll(direction);
    } catch (e) {
      return false;
    }
  }

  /// Click on web element (for interactive elements)
  Future<bool> clickElement(String elementText) async {
    try {
      return await _screenService.clickByText(elementText);
    } catch (e) {
      return false;
    }
  }

  /// Type into web form field
  Future<bool> typeInField(String text, {String? fieldHint}) async {
    try {
      return await _screenService.typeText(text, fieldHint: fieldHint);
    } catch (e) {
      return false;
    }
  }

  /// Submit form or search
  Future<bool> submitForm() async {
    try {
      return await _screenService.pressEnter();
    } catch (e) {
      return false;
    }
  }

  /// Get page content/text
  Future<String> getPageContent() async {
    try {
      return await _screenService.getScreenDescription();
    } catch (e) {
      return '';
    }
  }

  /// Check if page contains text
  Future<bool> pageContains(String text) async {
    try {
      final content = await getPageContent();
      return content.toLowerCase().contains(text.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Download file from URL (opens download in browser)
  Future<bool> downloadFile(String url) async {
    try {
      // This will trigger browser's download functionality
      return await openUrl(url);
    } catch (e) {
      return false;
    }
  }

  /// Extract links from current page
  Future<List<String>> extractLinks() async {
    try {
      final content = await getPageContent();
      final urlPattern = RegExp(r'https?://[^\s\)]+');

      return urlPattern
          .allMatches(content)
          .map((m) => m.group(0) ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all text content from current page (useful for reading articles)
  Future<String> getAllText() async {
    try {
      final content = await getPageContent();

      // Remove URLs and other noise
      final text = content
          .replaceAll(RegExp(r'https?://[^\s]+'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();

      return text;
    } catch (e) {
      return '';
    }
  }

  /// Wait for element to appear on page
  /// Useful for pages with dynamic content
  Future<bool> waitForElement(
    String elementText, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < timeout) {
        final content = await getPageContent();
        if (content.contains(elementText)) {
          return true;
        }

        // Wait a bit before checking again
        await Future.delayed(const Duration(seconds: 1));
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Search for something and open the first relevant result.
  /// Uses semantic text matching on the accessibility tree rather than
  /// generic HTML selectors (h2, a) which do not apply to Android's
  /// accessibility node tree.
  Future<bool> searchAndOpenFirst(
    String query, {
    String engine = 'google',
  }) async {
    try {
      if (!await search(query, engine: engine)) return false;

      // Wait for results to load.
      await Future.delayed(const Duration(seconds: 3));

      // Read the screen and look for meaningful result-like text.
      final screenContent = await _screenService.getScreenDescription();
      if (screenContent.contains('Could not read screen')) return false;

      // Strategy: look for lines that contain query terms and are not
      // the search bar, URL bar, or navigation elements.
      final lines = screenContent
          .split('\n')
          .where((line) => line.trim().length > 10)
          .toList();

      // Extract meaningful query terms.
      final queryTerms = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .toList();

      // Find the first line that matches a query term and looks like a
      // result title (not a URL, not a navigation element).
      for (final line in lines) {
        final lowered = line.toLowerCase();
        final hasQueryTerm = queryTerms.any(lowered.contains);
        final looksLikeUrl =
            lowered.startsWith('http') ||
            lowered.contains('google.com') ||
            lowered.contains('bing.com');
        if (hasQueryTerm && !looksLikeUrl) {
          // Try clicking the first meaningful portion of the line.
          final clickableText = line.trim().split(RegExp(r'\s{2,}')).first;
          if (clickableText.length >= 5) {
            return await clickElement(clickableText);
          }
        }
      }

      // Fallback: try the first non-URL line that isn't the search bar.
      for (final line in lines) {
        final lowered = line.toLowerCase();
        final looksLikeUrl = lowered.startsWith('http');
        final looksLikeSearchBar =
            lowered.contains('search') && lowered.length < 60;
        if (!looksLikeUrl && !looksLikeSearchBar) {
          final clickableText = line.trim().split(RegExp(r'\s{2,}')).first;
          if (clickableText.length >= 5) {
            return await clickElement(clickableText);
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
