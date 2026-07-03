import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';

const String _kBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'https://marketpulse-mu5o.onrender.com');

final apiClientProvider = Provider<AdminApiClient>((ref) => AdminApiClient());

class AdminApiClient {
  late final Dio _dio;

  AdminApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('admin_auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
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

  // ── Admin endpoints ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHealth() async {
    final resp = await _dio.get('/admin/health');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<Article>> getReviewQueue({int limit = 50}) async {
    final resp = await _dio.get('/admin/articles/review',
        queryParameters: {'limit': limit});
    return (resp.data as List)
        .map((j) => Article.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> reviewArticle(String id, String action,
      {String? credibility}) async {
    await _dio.patch('/admin/articles/$id/review', queryParameters: {
      'action': action,
      if (credibility != null) 'credibility': credibility,
    });
  }

  Future<Map<String, dynamic>> submitManualArticle({
    required String headline,
    String? content,
    String? source,
    String? url,
  }) async {
    final resp = await _dio.post('/admin/articles/manual', data: {
      'headline': headline,
      if (content != null) 'content': content,
      if (source != null) 'source': source,
      if (url != null) 'url': url,
    });
    return resp.data as Map<String, dynamic>;
  }
}
