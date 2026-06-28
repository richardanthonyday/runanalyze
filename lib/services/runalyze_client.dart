import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity.dart';

class RunalyzeApiProbeResult {
  final String requestUrl;
  final Map<String, String> requestHeaders;
  final int? statusCode;
  final Map<String, String> responseHeaders;
  final String? responseBody;
  final String? error;
  final int durationMs;

  const RunalyzeApiProbeResult({
    required this.requestUrl,
    required this.requestHeaders,
    required this.statusCode,
    required this.responseHeaders,
    required this.responseBody,
    required this.error,
    required this.durationMs,
  });
}

/// RunalyzeClient handles API communication with Runalyze.
class RunalyzeClient {
  static const String baseUrl = 'https://runalyze.com/api/v1';
  final String apiToken;
  final http.Client httpClient;

  RunalyzeClient({
    required this.apiToken,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Probe endpoint call for debugging.
  Future<RunalyzeApiProbeResult> probeActivityPage({
    int page = 1,
    int itemsPerPage = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/activity').replace(
      queryParameters: {
        'page': page.toString(),
        'itemsPerPage': itemsPerPage.toString(),
        'pagination': 'true',
        'order[id]': 'desc',
      },
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiToken',
    };

    final started = DateTime.now();

    try {
      final response = await httpClient.get(uri, headers: headers).timeout(
            const Duration(seconds: 20),
          );

      return RunalyzeApiProbeResult(
        requestUrl: uri.toString(),
        requestHeaders: headers,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: response.body,
        error: null,
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    } catch (e) {
      return RunalyzeApiProbeResult(
        requestUrl: uri.toString(),
        requestHeaders: headers,
        statusCode: null,
        responseHeaders: const {},
        responseBody: null,
        error: e.toString(),
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }

  /// Fetch activities from Runalyze API.
  ///
  /// Parameters:
  /// - [itemsPerPage]: Number of activities to fetch per page (default 100)
  /// - [page]: Starting page number for pagination (default 1)
  ///
  /// Throws [RunalyzeException] on failure.
  Future<List<Activity>> getActivities({
    int itemsPerPage = 500,
    int page = 1,
    DateTime? notBefore,
  }) async {
    try {
      final allActivities = <Activity>[];
      var currentPage = page;
      const maxPages = 100;

      final cutoff = notBefore;

      while (currentPage < page + maxPages) {
        final uri = Uri.parse('$baseUrl/activity').replace(
          queryParameters: {
            'page': currentPage.toString(),
            'itemsPerPage': itemsPerPage.toString(),
            'pagination': 'true',
            'order[id]': 'desc', // newest first
          },
        );

        final response = await httpClient.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $apiToken',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final lastPageHeader = response.headers['pagination-last-page'];
          final lastPage = int.tryParse(lastPageHeader ?? '');
          final List<dynamic> json = jsonDecode(response.body);
          final pageActivities = json
              .map((item) => Activity.fromJson(item as Map<String, dynamic>))
              .toList();

          if (cutoff == null) {
            allActivities.addAll(pageActivities);
          } else {
            allActivities.addAll(
              pageActivities.where((a) => !a.dateTime.isBefore(cutoff)),
            );
          }

          if (cutoff != null &&
              pageActivities.isNotEmpty &&
              pageActivities.every((a) => a.dateTime.isBefore(cutoff))) {
            break;
          }

          // Last page when fewer than requested items are returned.
          if (pageActivities.length < itemsPerPage) {
            break;
          }

          if (lastPage != null && currentPage >= lastPage) {
            break;
          }

          currentPage++;
          continue;
        }

        if (response.statusCode == 401) {
          throw RunalyzeException('Authentication failed. Invalid or expired API token.');
        }

        if (response.statusCode == 429) {
          throw RunalyzeException('Runalyze API rate limit reached. Please wait a minute and retry.');
        }

        throw RunalyzeException(
          'Failed to fetch activities: ${response.statusCode}',
        );
      }

      return allActivities;
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
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Activity.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw RunalyzeException('Authentication failed.');
      } else if (response.statusCode == 429) {
        throw RunalyzeException('Runalyze API rate limit reached. Please wait a minute and retry.');
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
