import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:neptun2/storage.dart';

/// Secure ELTE IIG / Caesar credentials for the in-app BIS campus map WebView.
///
/// Never stored in SharedPreferences plaintext. Keys live only in
/// [FlutterSecureStorage] (Keychain / Keystore).
class BisIigCredentials {
  BisIigCredentials._();

  static const _secure = FlutterSecureStorage();
  static const _userKey = 'bis_iig_username';
  static const _passKey = 'bis_iig_password';

  /// Default **on** once the user has opted to save (sheet checkbox defaults on).
  /// When the toggle is turned off, credentials are cleared.
  static bool getRememberEnabled() {
    return DataCache.getRememberBisIigCredentials() ?? true;
  }

  static Future<void> setRememberEnabled(bool enabled) async {
    await DataCache.setRememberBisIigCredentials(enabled ? 1 : 0);
    if (!enabled) {
      await clear();
    }
  }

  static Future<({String username, String password})?> read() async {
    if (!getRememberEnabled()) return null;
    final u = await _secure.read(key: _userKey);
    final p = await _secure.read(key: _passKey);
    if (u == null || u.isEmpty || p == null || p.isEmpty) return null;
    return (username: u, password: p);
  }

  static Future<bool> hasSaved() async => await read() != null;

  /// Persist IIG username + password. No-op if [remember] is false (clears instead).
  static Future<void> save({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final u = username.trim();
    if (!remember || u.isEmpty || password.isEmpty) {
      await clear();
      await DataCache.setRememberBisIigCredentials(remember ? 1 : 0);
      return;
    }
    await DataCache.setRememberBisIigCredentials(1);
    await _secure.write(key: _userKey, value: u);
    await _secure.write(key: _passKey, value: password);
  }

  static Future<void> clear() async {
    await _secure.delete(key: _userKey);
    await _secure.delete(key: _passKey);
  }
}
