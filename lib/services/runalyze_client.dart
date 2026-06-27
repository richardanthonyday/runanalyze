import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity.dart';

/// RunalyzeClient handles API communication with Runalyze.
class RunalyzeClient {
  static const String baseUrl = 'https://runalyze.com/api/v1';
  final String apiToken;
  final http.Client httpClient;

  RunalyzeClient({
    required this.apiToken,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Fetch activities from Runalyze API.
  /// 
  /// Parameters:
  /// - [itemsPerPage]: Number of activities to fetch (default 100)
  /// - [page]: Page number for pagination (default 1)
  /// 
  /// Throws [RunalyzeException] on failure.
  Future<List<Activity>> getActivities({
    int itemsPerPage = 100,
    int page = 1,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/activity')
          .replace(queryParameters: {
        'preset': 'latest',
        'page': page.toString(),
        'itemsPerPage': itemsPerPage.toString(),
        'order[id]': 'asc',
      });

      final response = await httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json
            .map((item) => Activity.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw RunalyzeException('Authentication failed. Invalid or expired API token.');
      } else {
        throw RunalyzeException(
          'Failed to fetch activities: ${response.statusCode}',
        );
      }
    } on RunalyzeException {
      rethrow;
    } catch (e) {
      throw RunalyzeException('Network error: $e');
    }
  }

  /// Fetch a single activity by ID.
  Future<Activity?> getActivity(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/activity/$id');
      final response = await httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Activity.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw RunalyzeException('Authentication failed.');
      } else {
        throw RunalyzeException('Failed to fetch activity: ${response.statusCode}');
      }
    } on RunalyzeException {
      rethrow;
    } catch (e) {
      throw RunalyzeException('Network error: $e');
    }
  }
}

/// Exception thrown by RunalyzeClient.
class RunalyzeException implements Exception {
  final String message;
  RunalyzeException(this.message);

  @override
  String toString() => 'RunalyzeException: $message';
}
