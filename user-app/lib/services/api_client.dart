import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';
import '../models/stock_profile.dart';

// ── Base URL ──────────────────────────────────────────────────────────────────
const String _kBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'https://marketpulse-mu5o.onrender.com');

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
        if (error.response?.statusCode == 401) {
          SharedPreferences.getInstance().then((p) => p.remove('auth_token'));
        }
        return handler.next(error);
      },
    ));
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final resp = await _dio.post('/auth/register', data: {'email': email, 'password': password});
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

  // ── Stock Intelligence (Vice-Versa) ────────────────────────────────────────

  /// Get stock profile metadata (name, sector, impact summary, keywords)
  Future<StockProfile> getStockProfile(String symbol) async {
    final resp = await _dio.get('/users/stocks/${symbol.toUpperCase()}');
    return StockProfile.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Vice-versa: get all news articles that affected this stock
  Future<List<StockNewsItem>> getNewsForStock(String symbol, {int limit = 20}) async {
    final resp = await _dio.get(
      '/users/stocks/${symbol.toUpperCase()}/news',
      queryParameters: {'limit': limit},
    );
    final data = resp.data as Map<String, dynamic>;
    final newsList = (data['news'] as List? ?? []);
    return newsList.map((j) => StockNewsItem.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Get trending stocks sorted by news activity
  Future<List<TrendingStock>> getTrendingStocks({int limit = 20}) async {
    final resp = await _dio.get('/users/stocks', queryParameters: {'limit': limit});
    final data = resp.data as Map<String, dynamic>;
    final stocks = (data['trending_stocks'] as List? ?? []);
    return stocks.map((j) => TrendingStock.fromJson(j as Map<String, dynamic>)).toList();
  }
}
