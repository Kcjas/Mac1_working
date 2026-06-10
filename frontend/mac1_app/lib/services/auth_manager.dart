import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Global navigator key so auth flows can reset navigation without a
/// BuildContext (used by [AuthManager.handleUnauthorized]).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Single source of truth for client-side auth state.
///
/// The JWT lives in the OS secure store (Keychain / Keystore / wincrypt) via
/// [FlutterSecureStorage]; an in-memory copy is kept for fast header injection.
class AuthManager {
  AuthManager._();
  static final AuthManager instance = AuthManager._();

  static const _tokenKey = 'auth_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? token;
  int? userId;
  String? role;

  bool get isLoggedIn => token != null && userId != null;

  /// Load any persisted token on startup and validate it against the backend.
  /// A 200 from `/auth/me` confirms the token is still valid (not expired or
  /// revoked); anything else clears it so we fall back to the login screen.
  Future<void> init() async {
    final stored = await _storage.read(key: _tokenKey);
    if (stored == null || stored.isEmpty) return;
    token = stored;
    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $stored'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        userId = data['user_id'];
        role = data['role'];
      } else {
        // Expired / tampered / revoked -> drop it.
        await _clear();
      }
    } catch (_) {
      // Offline at startup: keep the stored token for a later retry, but treat
      // this session as logged out (userId stays null) so we show login.
      userId = null;
      role = null;
    }
  }

  /// Persist a freshly issued token and set the in-memory session.
  Future<void> login({
    required String token,
    required int userId,
    required String role,
  }) async {
    this.token = token;
    this.userId = userId;
    this.role = role;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> _clear() async {
    token = null;
    userId = null;
    role = null;
    await _storage.delete(key: _tokenKey);
  }

  /// Clear auth state and hard-reset navigation to the login screen. Called by
  /// [AuthHttp] on any 401 and by the explicit logout action.
  Future<void> handleUnauthorized() async {
    await _clear();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> logout() => handleUnauthorized();
}
