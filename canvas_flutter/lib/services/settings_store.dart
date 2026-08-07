import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, user-facing app settings.
///
/// The OpenAI API key is entered by the user inside the app and stored with
/// `shared_preferences`. It is never hardcoded, never logged, and never
/// embedded in error messages.
///
/// Register once near the root of the widget tree and call [load] at startup:
///
/// ```dart
/// final settings = SettingsStore();
/// await settings.load();
/// runApp(ChangeNotifierProvider.value(value: settings, child: const App()));
/// ```
class SettingsStore extends ChangeNotifier {
  /// Creates an unloaded store. Call [load] before reading persisted values.
  SettingsStore();

  static const String _keyApiKey = 'openai_api_key';
  static const String _keyHasSeenWelcome = 'has_seen_welcome';

  SharedPreferences? _prefs;
  String? _apiKey;
  bool _hasSeenWelcome = false;
  bool _isLoaded = false;

  /// The stored OpenAI API key, or `null` when unset.
  String? get apiKey => _apiKey;

  /// Whether a non-blank API key is available for requests.
  bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  /// Whether the one-time welcome screen has already been dismissed.
  bool get hasSeenWelcome => _hasSeenWelcome;

  /// Whether [load] has completed. Values are defaults until this is `true`.
  bool get isLoaded => _isLoaded;

  /// Reads all persisted settings from disk. Safe to call more than once.
  Future<void> load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyApiKey)?.trim();
    _apiKey = (stored == null || stored.isEmpty) ? null : stored;
    _hasSeenWelcome = prefs.getBool(_keyHasSeenWelcome) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  /// Stores [value] after trimming it. An empty value clears the key.
  Future<void> setApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, trimmed);
    _apiKey = trimmed;
    notifyListeners();
  }

  /// Removes the stored API key.
  Future<void> clearApiKey() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(_keyApiKey);
    _apiKey = null;
    notifyListeners();
  }

  /// Records that the welcome screen has been shown.
  Future<void> markWelcomeSeen() async {
    if (_hasSeenWelcome) return;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenWelcome, true);
    _hasSeenWelcome = true;
    notifyListeners();
  }

  /// Cheap shape check for inline form validation only.
  ///
  /// Returns `true` when the trimmed [v] starts with `sk-` and is at least
  /// 20 characters long. This is a hint for the user, not a hard gate — only
  /// the OpenAI API can decide whether a key is actually valid.
  static bool looksLikeApiKey(String v) {
    final trimmed = v.trim();
    return trimmed.startsWith('sk-') && trimmed.length >= 20;
  }
}
