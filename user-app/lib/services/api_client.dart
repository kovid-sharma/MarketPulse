import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';

// ── Base URL ──────────────────────────────────────────────────────────────────
// Change this to your Render backend URL in production.
const String _kBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

// ── Provider ──────────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// ── API Client ────────────────────────────────────────────────────────────────

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Attach JWT token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 401 — token expired, clear locally
        if (error.response?.statusCode == 401) {
          SharedPreferences.getInstance()
              .then((p) => p.remove('auth_token'));
        }
        return handler.next(error);
      },
    ));
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final resp = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ── Feed ───────────────────────────────────────────────────────────────────

  Future<List<Article>> getFeed({
    String? geography,
    String? sentiment,
    String? sector,
    String? credibility,
    int limit = 30,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (geography != null) 'geography': geography,
      if (sentiment != null) 'sentiment': sentiment,
      if (sector != null) 'sector': sector,
      if (credibility != null) 'credibility': credibility,
    };
    final resp = await _dio.get('/users/feed', queryParameters: params);
    return (resp.data as List).map((j) => Article.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Article> getArticle(String id) async {
    final resp = await _dio.get('/articles/$id');
    return Article.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── User ───────────────────────────────────────────────────────────────────

  Future<void> savePreferences(Map<String, dynamic> prefs) async {
    await _dio.post('/users/preferences', data: prefs);
  }

  Future<void> registerDeviceToken(String token) async {
    await _dio.post('/users/device-token', data: {'token': token});
  }
}
