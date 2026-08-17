import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLauncherService {
  List<AppInfo>? _cachedApps;

  /// Get all installed apps (cached), including system apps!
  Future<List<AppInfo>> getInstalledApps() async {
    _cachedApps ??= await InstalledApps.getInstalledApps(false, false);
    return _cachedApps!;
  }

  /// Clear app cache
  void clearCache() {
    _cachedApps = null;
  }

  /// Find apps matching a query.
  Future<List<AppInfo>> searchApps(String query) async {
    final apps = await getInstalledApps();
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return const <AppInfo>[];
    return apps.where((app) {
      return app.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Resolve the best installed-app match without launching it.
  Future<AppInfo?> resolveApp(String appName) async {
    final matches = await searchApps(appName);
    if (matches.isEmpty) return null;

    final query = appName.trim().toLowerCase();
    for (final app in matches) {
      if (app.name.trim().toLowerCase() == query) return app;
    }
    return matches.first;
  }

  /// Open an app by name (fuzzy match).
  Future<String> openApp(String appName) async {
    final target = await resolveApp(appName);

    if (target == null) {
      return 'Could not find app "$appName". Try being more specific.';
    }

    try {
      await InstalledApps.startApp(target.packageName);
      return 'Opened ${target.name}';
    } catch (e) {
      return 'Error opening ${target.name}: $e';
    }
  }

  /// Open an app by exact package name.
  Future<String> openPackage(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
      return 'Launched $packageName';
    } catch (e) {
      return 'Error launching $packageName: $e';
    }
  }

  /// Open a URL.
  Future<String> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened $url';
      }
      return 'Cannot open $url';
    } catch (e) {
      return 'Error opening URL: $e';
    }
  }
}
