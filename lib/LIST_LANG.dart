import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  static AppStrings? _instance;
  late String currentLang;
  late Map<String, String> _translations;

  AppStrings._(this.currentLang, this._translations);

  static Future<void> setLanguage(String lang) async {
    if (_instance != null && _instance!.currentLang == lang) {
      print('[AppStrings] Using cached translations for "$lang"');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final langKey = 'app_language_map_$lang';
    final cachedTranslations = prefs.getString(langKey);

    if (cachedTranslations != null) {
      print('[AppStrings] Using stored translations from local storage for "$lang"');
      try {
        final Map<String, dynamic> translationsMap = json.decode(cachedTranslations);
        final translations = translationsMap.map((k, v) => MapEntry(k, v.toString()));
        _instance = AppStrings._(lang, translations);
        await prefs.setString('app_language', lang); // Always save the current language
        return;
      } catch (e) {
        print('[AppStrings] Failed to parse cached translations, will fetch from backend.');
      }
    }

    // Otherwise, fetch from backend
    final authKey = prefs.getString("auth_token");
    if (authKey == null || authKey.isEmpty) {
      throw Exception("[AppStrings] Auth key missing. Cannot fetch translations.");
    }

    final url = 'http://account.galaxyex.xyz/v1/user/api/setting/get-language/$lang';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      },
    );
    print('[AppStrings] Raw backend response for "$lang": ${response.body}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (jsonResponse.containsKey('meta') &&
          jsonResponse['meta'] is Map &&
          jsonResponse['meta']['status'] == false) {
        print('[AppStrings] Backend error: ${jsonResponse['meta']['msg']}');
        throw Exception('Translation API error: ${jsonResponse['meta']['msg']}');
      }

      Map<String, dynamic> translationsJson;
      if (jsonResponse.containsKey('data')) {
        translationsJson = (jsonResponse['data'] as Map<String, dynamic>);
      } else {
        translationsJson = jsonResponse;
      }
      final Map<String, dynamic> translationsMap =
          translationsJson['translations'] ?? translationsJson;

      if (translationsMap is! Map || translationsMap.isEmpty) {
        print('[AppStrings] No valid translations found in API response!');
        throw Exception('No valid translations in API response');
      }

      print('[AppStrings] Extracted translations map for "$lang": $translationsMap');
      Map<String, String> translations = {};
      translationsMap.forEach((key, value) {
        if (value is String) {
          translations[key] = value;
        }
      });

      // Save to local storage for this language for future
      await prefs.setString('app_language', lang);
      await prefs.setString(langKey, json.encode(translations));

      _instance = AppStrings._(lang, translations);
      print('[AppStrings] Loaded ${translations.length} translations for "$lang" from backend.');
    } else {
      throw Exception("Failed to load translations from backend (status ${response.statusCode})");
    }
  }

  static AppStrings get instance {
    if (_instance == null) {
      throw Exception("AppStrings is not initialized. Call setLanguage first.");
    }
    return _instance!;
  }

  String get(String key) => _translations[key] ?? key;
  static String getString(String key) => instance.get(key);
  String get lang => currentLang;
}