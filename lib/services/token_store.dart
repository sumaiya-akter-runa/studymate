/// FILE: lib/services/token_store.dart
/// PURPOSE: Saves the login tokens on the phone so the user stays logged in
///          after closing the app.
///
/// Tokens are kept in flutter_secure_storage (Android Keystore / iOS Keychain),
/// not in plain text. Old tokens saved by earlier versions in SharedPreferences
/// are moved over once, so nobody gets logged out by this update.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  Future<void>? _migration;

  Future<void> _ready() => _migration ??= _migrateOldTokens();

  Future<void> _migrateOldTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldAccess = prefs.getString(_accessKey);
      final oldRefresh = prefs.getString(_refreshKey);
      if (oldAccess == null && oldRefresh == null) return;
      if (oldAccess != null && await _read(_accessKey) == null) {
        await _secure.write(key: _accessKey, value: oldAccess);
      }
      if (oldRefresh != null && await _read(_refreshKey) == null) {
        await _secure.write(key: _refreshKey, value: oldRefresh);
      }
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (_) {
      // If migration fails the user just has to log in again.
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null; // unreadable keystore entry: treat as logged out
    }
  }

  Future<String?> get access async {
    await _ready();
    return _read(_accessKey);
  }

  Future<String?> get refresh async {
    await _ready();
    return _read(_refreshKey);
  }

  Future<void> save({required String access, String? refresh}) async {
    await _ready();
    await _secure.write(key: _accessKey, value: access);
    if (refresh != null) {
      await _secure.write(key: _refreshKey, value: refresh);
    }
  }

  Future<void> clear() async {
    await _ready();
    try {
      await _secure.delete(key: _accessKey);
      await _secure.delete(key: _refreshKey);
    } catch (_) {}
  }
}