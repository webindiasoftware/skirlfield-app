import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/device.dart';
import '../core/storage.dart';
import '../models.dart';
import '../tracking/point_queue.dart';
import '../tracking/tracker.dart';

enum AuthStatus { loading, signedOut, needsPassword, signedIn }

class AuthState extends ChangeNotifier {
  AuthStatus status = AuthStatus.loading;
  Me? me;

  /// Shown on the login screen after the session ended (e.g. phone replaced, account disabled).
  String? message;

  /// True when the profile came from the phone's cache because the server could not be reached.
  bool offline = false;

  Future<void> init() async {
    await TokenStore.load();
    Api.instance.onSessionEnded = (msg) {
      if (status == AuthStatus.signedOut) return;
      me = null;
      message = msg;
      status = AuthStatus.signedOut;
      notifyListeners();
    };
    if (!TokenStore.hasSession) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    await loadMe();
  }

  Future<void> loadMe() async {
    try {
      final j = await Api.instance.get('/auth/me') as Map;
      me = Me(Map<String, dynamic>.from(j));
      offline = false;
      await PointQueue.setMeta('me_cache', jsonEncode(j));
    } on ApiException catch (e) {
      if (e.isNetwork) {
        // no network at launch: carry on with the last known profile so duty keeps working
        final cached = await PointQueue.getMeta('me_cache');
        if (cached != null) {
          me = Me(Map<String, dynamic>.from(jsonDecode(cached) as Map));
          offline = true;
        } else {
          rethrow;
        }
      } else if (e.status == 401) {
        await TokenStore.clear();
        status = AuthStatus.signedOut;
        notifyListeners();
        return;
      } else {
        rethrow;
      }
    }
    status = me!.mustChangePassword ? AuthStatus.needsPassword : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    message = null;
    final device = await DeviceSnapshot.read();
    final d = await Api.instance.post('/auth/login', {
      'login': login.trim(),
      'password': password,
      'device': device.toJson(),
    }, null, false) as Map;
    await TokenStore.save(d['access_token'] as String, d['refresh_token'] as String);
    await TokenStore.setLastLogin(login.trim());
    await loadMe();
  }

  Future<void> forgotPassword(String login) => Api.instance.post('/auth/forgot-password', {'login': login.trim()}, null, false);

  Future<void> changePassword(String current, String next) async {
    final d = await Api.instance.post('/auth/change-password', {'current_password': current, 'new_password': next}) as Map;
    if (d['access_token'] is String && d['refresh_token'] is String) {
      await TokenStore.save(d['access_token'] as String, d['refresh_token'] as String);
    }
    await loadMe();
  }

  /// Sign out of this phone. The caller must make sure duty is ended first.
  Future<void> logout() async {
    try {
      await Tracker.instance.flush();
      await Api.instance.post('/auth/logout', {'refresh_token': TokenStore.refresh});
    } catch (_) {
      // signing out locally is what matters
    }
    await TokenStore.clear();
    await PointQueue.setMeta('me_cache', null);
    me = null;
    message = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
