import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    TokenStorage? tokenStorage,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  static const String baseUrl = 'http://192.168.0.16:3000';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final TokenStorage _tokenStorage;

  Future<dynamic> get(String path) async {
    final response = await _send(
      method: 'GET',
      path: path,
    );

    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _send(
      method: 'POST',
      path: path,
      body: body,
    );

    return _handleResponse(response);
  }

  Future<dynamic> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _send(
      method: 'PATCH',
      path: path,
      body: body,
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _send(
      method: 'DELETE',
      path: path,
      body: body,
    );

    return _handleResponse(response);
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final accessToken = await _tokenStorage.getAccessToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;

        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(_timeout);
          break;

        case 'PATCH':
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(_timeout);
          break;

        case 'DELETE':
          response = await _client
              .delete(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
          break;

        default:
          throw Exception('Unsupported method: $method');
      }
    } on TimeoutException {
      throw Exception('Request timeout: $method $path');
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Request failed: $e');
    }

    if (response.statusCode == 401 && retryAfterRefresh) {
      final refreshed = await _tryRefreshToken();

      if (refreshed) {
        return _send(
          method: method,
          path: path,
          body: body,
          retryAfterRefresh: false,
        );
      }

      await _tokenStorage.clear();
    }

    return response;
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$baseUrl/auth/refresh');

    try {
      final response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'refreshToken': refreshToken,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final newAccessToken = decoded['accessToken']?.toString();
      final newRefreshToken =
          decoded['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        return false;
      }

      await _tokenStorage.saveTokens(
        newAccessToken,
        newRefreshToken,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _handleResponse(http.Response response) {
    final status = response.statusCode;
    final bodyText = response.body.trim();

    if (status < 200 || status >= 300) {
      throw Exception(
        'HTTP $status: ${bodyText.isEmpty ? '<empty body>' : bodyText}',
      );
    }

    if (bodyText.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(bodyText);
    } catch (_) {
      return bodyText;
    }
  }

  void dispose() {
    _client.close();
  }
}