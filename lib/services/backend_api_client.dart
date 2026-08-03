import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity.dart';

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(this.message, {this.statusCode});

  @override
  String toString() => 'BackendApiException: $message (status: $statusCode)';
}

/// Client for communicating with the FastAPI backend service (runSimple API).
class BackendApiClient {
  static const String _defaultUrl = 'http://10.0.2.2:8000'; // Android emulator localhost
  static const String _tokenStorageKey = 'backend_session_token';

  final String baseUrl;
  final http.Client httpClient;
  String? _sessionToken;

  BackendApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment('BACKEND_URL', defaultValue: _defaultUrl),
        httpClient = httpClient ?? http.Client();

  /// Initialize and load saved session token from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_tokenStorageKey);
  }

  /// Get current session token.
  String? get sessionToken => _sessionToken;

  /// Set and persist session token.
  Future<void> setSessionToken(String? token) async {
    _sessionToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenStorageKey, token);
    } else {
      await prefs.remove(_tokenStorageKey);
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }

  void _logCurl(String method, Uri uri, {Map<String, String>? headers, String? body}) {
    if (!kDebugMode) return;
    final buffer = StringBuffer('curl -X $method "$uri"');
    final hdrs = headers ?? _headers;
    for (final entry in hdrs.entries) {
      buffer.write(' -H "${entry.key}: ${entry.value}"');
    }
    if (body != null && body.isNotEmpty) {
      buffer.write(" -d '$body'");
    }
    debugPrint('[BackendApiClient] Request:\n${buffer.toString()}');
  }

  /// Health check endpoint.
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      _logCurl('GET', uri);
      final response = await httpClient.get(uri).timeout(const Duration(seconds: 5));
      debugPrint('[BackendApiClient] Response (${response.statusCode}): ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e, st) {
      debugPrint('[BackendApiClient] Health check error: $e\n$st');
      return false;
    }
  }

  /// Fetch dashboard summary metrics (week, month, or year).
  /// Returns map with distance_km, duration_seconds, activity_count, average_pace_min_km.
  Future<Map<String, dynamic>> getDashboardSummary({
    String timeframe = 'week',
    String sport = 'all',
  }) async {
    final uri = Uri.parse('$baseUrl/v1/dashboard/summary').replace(
      queryParameters: {
        'timeframe': timeframe,
        'sport': sport,
      },
    );

    _logCurl('GET', uri);
    try {
      final response = await httpClient.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      debugPrint('[BackendApiClient] Summary Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw BackendApiException('Unauthorized. Please log in.', statusCode: 401);
      }

      throw BackendApiException('Failed to load summary', statusCode: response.statusCode);
    } catch (e, st) {
      debugPrint('[BackendApiClient] getDashboardSummary error: $e\n$st');
      rethrow;
    }
  }

  /// Fetch activity list with pagination.
  Future<List<Activity>> getActivities({
    int limit = 50,
    int offset = 0,
    String? sport,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (sport != null) params['sport'] = sport;

    final uri = Uri.parse('$baseUrl/v1/activities').replace(queryParameters: params);

    _logCurl('GET', uri);
    try {
      final response = await httpClient.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      debugPrint('[BackendApiClient] Activities Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => Activity.fromBackendJson(item as Map<String, dynamic>)).toList();
      }

      throw BackendApiException('Failed to load activities', statusCode: response.statusCode);
    } catch (e, st) {
      debugPrint('[BackendApiClient] getActivities error: $e\n$st');
      rethrow;
    }
  }

  /// Trigger a Strava synchronization job.
  Future<Map<String, dynamic>> triggerStravaSync() async {
    final uri = Uri.parse('$baseUrl/v1/sync/strava');

    _logCurl('POST', uri);
    try {
      final response = await httpClient.post(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      debugPrint('[BackendApiClient] Strava Sync Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw BackendApiException('Failed to trigger Strava sync', statusCode: response.statusCode);
    } catch (e, st) {
      debugPrint('[BackendApiClient] triggerStravaSync error: $e\n$st');
      rethrow;
    }
  }
}
