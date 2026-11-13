import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _booksKey = 'books';
  static const String _bookmarksKey = 'bookmarks';
  static const String _darkModeKey = 'darkMode';
  static const String _fontSizeKey = 'fontSize';
  static const String _gridViewKey = 'gridView';
  static const String _languageKey = 'language';
  static const String _themeColorKey = 'themeColor';
  static const String _lastSplashDateKey = 'lastSplashDate';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // Kitapları kaydet
  Future<void> saveBooks(List<Book> books) async {
    await init();
    final booksJson = books.map((b) => b.toJson()).toList();
    await _prefs.setString(_booksKey, jsonEncode(booksJson));
    notifyListeners();
  }

  // Kitapları yükle
  Future<List<Book>> loadBooks() async {
    await init();
    final String? booksString = _prefs.getString(_booksKey);
    if (booksString == null) return [];

    final List<dynamic> booksJson = jsonDecode(booksString);
    return booksJson.map((json) => Book.fromJson(json)).toList();
  }

  // Yer imlerini kaydet
  Future<void> saveBookmarks(String bookPath, List<int> bookmarks) async {
    await init();
    final key = '${_bookmarksKey}_$bookPath';
    await _prefs.setString(key, jsonEncode(bookmarks));
    notifyListeners();
  }

  // Yer imlerini yükle
  Future<List<int>> loadBookmarks(String bookPath) async {
    await init();
    final key = '${_bookmarksKey}_$bookPath';
    final String? bookmarksString = _prefs.getString(key);
    if (bookmarksString == null) return [];

    final List<dynamic> bookmarksJson = jsonDecode(bookmarksString);
    return bookmarksJson.cast<int>();
  }

  Future<bool> shouldShowSplash() async {
    await init();
    final String? lastDate = _prefs.getString(_lastSplashDateKey);
    final String today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate == today) {
      return false;
    }

    await _prefs.setString(_lastSplashDateKey, today);
    return true;
  }

  // Gece modu
  Future<void> setDarkMode(bool value) async {
    await init();
    await _prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<bool> getDarkMode() async {
    await init();
    return _prefs.getBool(_darkModeKey) ?? false;
  }

  // Font boyutu
  Future<void> setFontSize(double value) async {
    await init();
    await _prefs.setDouble(_fontSizeKey, value);
    notifyListeners();
  }

  Future<double> getFontSize() async {
    await init();
    return _prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  // Grid görünümü
  Future<void> setGridView(bool value) async {
    await init();
    await _prefs.setBool(_gridViewKey, value);
    notifyListeners();
  }

  Future<bool> getGridView() async {
    await init();
    return _prefs.getBool(_gridViewKey) ?? true;
  }

  // Dil
  Future<void> setLanguage(String value) async {
    await init();
    await _prefs.setString(_languageKey, value);
    notifyListeners();
  }

  Future<String> getLanguage() async {
    await init();
    String? savedLang = _prefs.getString(_languageKey);
    if (savedLang != null) return savedLang;

    // Default to device language
    try {
      String deviceLocale = Platform.localeName.split('_')[0].toLowerCase();
      if (deviceLocale == 'tr' || deviceLocale == 'de') {
        return deviceLocale;
      }
    } catch (e) {
      debugPrint('Error getting device locale: $e');
    }

    return 'en'; // Standard language is English
  }

  // Tema Rengi
  Future<void> setThemeColor(int value) async {
    await init();
    await _prefs.setInt(_themeColorKey, value);
    notifyListeners();
  }

  Future<int> getThemeColor() async {
    await init();
    return _prefs.getInt(_themeColorKey) ?? Colors.green.value;
  }

  // Google Play Puanlama / Oy Verme Takibi
  static const String _hasRatedKey = 'has_rated';
  static const String _openCountKey = 'app_open_count';

  Future<int> incrementOpenCount() async {
    await init();
    final count = (_prefs.getInt(_openCountKey) ?? 0) + 1;
    await _prefs.setInt(_openCountKey, count);
    return count;
  }

  Future<bool> hasRated() async {
    await init();
    return _prefs.getBool(_hasRatedKey) ?? false;
  }

  Future<void> setHasRated(bool value) async {
    await init();
    await _prefs.setBool(_hasRatedKey, value);
  }

  Future<bool> shouldPromptRating() async {
    await init();
    if (await hasRated()) return false;
    final count = _prefs.getInt(_openCountKey) ?? 0;
    // 2-3 kez kullanıldıktan sonra teşvik et
    return count >= 2;
  }

  // Tüm verileri temizle
  Future<void> clearAll() async {
    await init();
    await _prefs.clear();
    notifyListeners();
  }
}
