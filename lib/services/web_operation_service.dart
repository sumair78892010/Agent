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
  Future<bool> refreshPage() async {
    try {
      // On Android, we can press the refresh button if visible
      // Otherwise, we can use F5 key equivalent
      return await _screenService.pressEnter();
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

  /// Common web operations
  /// Search for something and open first result
  Future<bool> searchAndOpenFirst(
    String query, {
    String engine = 'google',
  }) async {
    try {
      // First, do the search
      if (!await search(query, engine: engine)) return false;

      // Wait for results to load
      await Future.delayed(const Duration(seconds: 2));

      // Click first result
      return await clickElement('h2') || await clickElement('a');
    } catch (e) {
      return false;
    }
  }
}
