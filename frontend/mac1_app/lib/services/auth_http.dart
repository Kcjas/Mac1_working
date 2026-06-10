import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_manager.dart';

/// Drop-in replacement for the `http` top-level functions that automatically
/// attaches the `Authorization: Bearer <token>` header and centralises 401
/// handling (clear session + reset navigation to login).
///
/// Usage: replace `http.get(uri)` with `AuthHttp.get(uri)`, etc. Any caller
/// supplied headers/body are passed through unchanged.
class AuthHttp {
  static Map<String, String> _merge(Map<String, String>? headers) {
    final token = AuthManager.instance.token;
    return {
      if (headers != null) ...headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _handle(http.Response res) async {
    if (res.statusCode == 401) {
      await AuthManager.instance.handleUnauthorized();
    }
    return res;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _handle(await http.get(url, headers: _merge(headers)));
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _handle(
        await http.post(url, headers: _merge(headers), body: body, encoding: encoding));
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _handle(
        await http.put(url, headers: _merge(headers), body: body, encoding: encoding));
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _handle(
        await http.patch(url, headers: _merge(headers), body: body, encoding: encoding));
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _handle(
        await http.delete(url, headers: _merge(headers), body: body, encoding: encoding));
  }
}
