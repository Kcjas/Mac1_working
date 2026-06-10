import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Default backend URL (fallback)
  static const String _defaultBaseUrl = 'http://192.168.100.203:8000';
  static const String _baseUrlKey = 'backend_url';
  
  /// Get the current backend URL.
  /// NOTE: temporarily ignores any saved override and always uses the
  /// hardcoded LAN URL, because a stale saved value was pointing the app at
  /// the wrong server. Also clears that stale value so it can't come back.
  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_baseUrlKey);
    } catch (e) {
      print('Error clearing backend URL: $e');
    }
    return _defaultBaseUrl;
  }
  
  /// Set a new backend URL
  static Future<bool> setBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_baseUrlKey, url);
    } catch (e) {
      print('Error setting backend URL: $e');
      return false;
    }
  }
  
  /// Reset to default URL
  static Future<bool> resetToDefault() async {
    return await setBaseUrl(_defaultBaseUrl);
  }
  
  /// Check if URL is valid format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
