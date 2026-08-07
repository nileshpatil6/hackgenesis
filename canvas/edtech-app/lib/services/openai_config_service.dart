import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's own OpenAI API key locally on-device (SharedPreferences).
/// The key is entered by the user in-app (Profile > OpenAI API Key) and is
/// never hardcoded in source.
class OpenAIConfigService {
  static const String _prefsKey = 'openai_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefsKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  static Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, apiKey.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<bool> hasApiKey() async {
    return (await getApiKey()) != null;
  }
}
