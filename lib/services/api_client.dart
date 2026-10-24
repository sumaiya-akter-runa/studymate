/// FILE: lib/services/api_client.dart
/// PURPOSE: Every request to the Django backend goes through this class.
///
/// What it does for us:
///  1. Adds the "Authorization: Bearer <token>" header automatically.
///  2. If the server answers 401 (access token expired), it uses the refresh
///     token to get a new access token and repeats the request ONCE.
///     The user never notices. This is why short-lived access tokens are safe.
///  3. Turns every failure into an ApiException with a readable message.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._tokens);

  final TokenStore _tokens;
  static const _timeout = Duration(seconds: 300); // AI answers can take a while

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  /// NOTE: paths of list endpoints need a trailing slash:
  /// '/api/chat/', '/api/documents/', '/api/quiz/'
  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Uploads a file as multipart/form-data (used for PDF upload).
  /// [filePath] is the local path, [field] the form field name the backend
  /// expects, [fields] any extra text fields (e.g. {'title': 'My notes'}).
  Future<dynamic> postFile(
      String path, {
        required String filePath,
        String field = 'file',
        String? fileName,
        Map<String, String>? fields,
        bool auth = true,
        bool retried = false,
      }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (fields != null) request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(field, filePath, filename: fileName),
    );
    if (auth) {
      final token = await _tokens.access;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }

    http.Response res;
    try {
      final streamed = await request.send().timeout(_timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Please try again.');
    } on SocketException {
      throw ApiException(_unreachable);
    } on http.ClientException {
      throw ApiException(_unreachable);
    }

    // A MultipartRequest can only be sent once, so on 401 we build a new one.
    if (res.statusCode == 401 && auth && !retried && await _refreshAccessToken()) {
      return postFile(path,
          filePath: filePath,
          field: field,
          fileName: fileName,
          fields: fields,
          auth: auth,
          retried: true);
    }

    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(_errorMessage(data, res.statusCode), statusCode: res.statusCode);
  }

  /// Sends one HTTP request and turns network problems into friendly errors.
  Future<http.Response> _request(
      String method,
      String path,
      Map<String, String> headers,
      String? body,
      ) async {
    final uri = _uri(path);
    try {
      switch (method) {
        case 'GET':
          return await http.get(uri, headers: headers).timeout(_timeout);
        case 'DELETE':
          return await http.delete(uri, headers: headers).timeout(_timeout);
        case 'PATCH':
          return await http.patch(uri, headers: headers, body: body).timeout(_timeout);
        default:
          return await http.post(uri, headers: headers, body: body).timeout(_timeout);
      }
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Please try again.');
    } on SocketException {
      throw ApiException(_unreachable);
    } on http.ClientException {
      throw ApiException(_unreachable);
    }
  }

  static const _unreachable =
      'Cannot reach the server. Is the backend running, and is the address in lib/config.dart correct?';

  Future<dynamic> _send(
      String method,
      String path, {
        Map<String, dynamic>? body,
        bool auth = true,
        bool retried = false,
      }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _tokens.access;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final res = await _request(method, path, headers, body == null ? null : jsonEncode(body));

    // Access token expired? Refresh it once and repeat the request.
    if (res.statusCode == 401 && auth && !retried && await _refreshAccessToken()) {
      return _send(method, path, body: body, auth: auth, retried: true);
    }

    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null; // the server sent something that is not JSON
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(_errorMessage(data, res.statusCode), statusCode: res.statusCode);
  }

  /// Asks the server for a new access token. Returns true if it worked.
  Future<bool> _refreshAccessToken() async {
    final refresh = await _tokens.refresh;
    if (refresh == null) return false;
    try {
      final res = await http
          .post(
        _uri('/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        await _tokens.clear(); // refresh token expired too: the user must log in again
        return false;
      }
      final data = jsonDecode(res.body);
      await _tokens.save(access: data['access'] as String, refresh: data['refresh'] as String?);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Django sends errors in a few shapes. Turn all of them into one sentence.
  String _errorMessage(dynamic data, int status) {
    if (data is Map) {
      if (data['error'] is String) return data['error'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      final parts = <String>[]; // field errors, e.g. {"email": ["already exists"]}
      data.forEach((key, value) {
        parts.add('$key: ${value is List ? value.join(' ') : value}');
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return 'Request failed (HTTP $status).';
  }
}