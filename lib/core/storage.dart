import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Tokens and the phone's id, kept in the Android Keystore / iOS Keychain.
class TokenStore {
  static const _s = FlutterSecureStorage();
  static const _kAccess = 'sf.access';
  static const _kRefresh = 'sf.refresh';
  static const _kDevice = 'sf.device_uid';
  static const _kLogin = 'sf.last_login';

  static String? _access;
  static String? _refresh;

  static Future<void> load() async {
    _access = await _s.read(key: _kAccess);
    _refresh = await _s.read(key: _kRefresh);
  }

  static String? get access => _access;
  static String? get refresh => _refresh;
  static bool get hasSession => _refresh != null;

  static Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  static Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }

  /// Stable id for this phone install. The server binds a field employee to one phone by this id,
  /// so reinstalling the app looks like a new phone (HR approves it once).
  static Future<String> deviceUid() async {
    var id = await _s.read(key: _kDevice);
    if (id == null || id.length < 8) {
      id = 'app-${const Uuid().v4()}';
      await _s.write(key: _kDevice, value: id);
    }
    return id;
  }

  static Future<String?> lastLogin() => _s.read(key: _kLogin);
  static Future<void> setLastLogin(String v) => _s.write(key: _kLogin, value: v);
}
