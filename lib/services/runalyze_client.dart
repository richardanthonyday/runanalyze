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

  /// Fetch exactly one page of activities.
  Future<List<Activity>> getActivitiesPage({
    int itemsPerPage = 500,
    int page = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/activity').replace(
      queryParameters: {
        'page': page.toString(),
        'itemsPerPage': itemsPerPage.toString(),
        'pagination': 'true',
        'order[date_time]': 'desc',
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
      final List<dynamic> json = jsonDecode(response.body);
      return json
          .map((item) => Activity.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401) {
      throw RunalyzeException('Authentication failed. Invalid or expired API token.');
    }

    if (response.statusCode == 429) {
      throw RunalyzeException('Runalyze API rate limit reached. Please wait a minute and retry.');
    }

    throw RunalyzeException('Failed to fetch activities: ${response.statusCode}');
  }

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
        'order[date_time]': 'desc',
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

  /// Upload a manually entered activity as a generated TCX file.
  ///
  /// Runalyze's public API currently supports activity creation via file upload.
  Future<void> uploadManualActivity({
    required String sport,
    required double distanceKm,
    required int durationSeconds,
    DateTime? startedAt,
    String? note,
  }) async {
    final started = startedAt ?? DateTime.now();
    final tcx = _buildManualTcx(
      sport: sport,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      startedAt: started,
      note: note,
    );

    final uri = Uri.parse('$baseUrl/activities/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiToken'
      ..fields['title'] = '$sport ${DateTime.now().toIso8601String()}';

    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }

    request.files.add(
      http.MultipartFile.fromString(
        'file',
        tcx,
        filename: 'manual_${started.millisecondsSinceEpoch}.tcx',
      ),
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw RunalyzeException('Network error while uploading activity: $e');
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 202) {
      return;
    }

    if (response.statusCode == 401) {
      throw RunalyzeException('Authentication failed. Invalid or expired API token.');
    }

    if (response.statusCode == 429) {
      throw RunalyzeException('Runalyze API rate limit reached. Please wait a minute and retry.');
    }

    throw RunalyzeException(
      'Failed to upload activity: ${response.statusCode}${response.body.isNotEmpty ? ' - ${response.body}' : ''}',
    );
  }

  String _buildManualTcx({
    required String sport,
    required double distanceKm,
    required int durationSeconds,
    required DateTime startedAt,
    String? note,
  }) {
    final tcxSport = _toTcxSport(sport);
    final startedUtc = startedAt.toUtc();
    final idIso = startedUtc.toIso8601String();
    final distanceMeters = (distanceKm * 1000).clamp(0, double.infinity);
    final escapedNote = _escapeXml(note ?? 'Manual activity from RunAnalyze');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
  <Activities>
    <Activity Sport="$tcxSport">
      <Id>$idIso</Id>
      <Lap StartTime="$idIso">
        <TotalTimeSeconds>$durationSeconds</TotalTimeSeconds>
        <DistanceMeters>$distanceMeters</DistanceMeters>
        <Calories>0</Calories>
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
      </Lap>
      <Notes>$escapedNote</Notes>
    </Activity>
  </Activities>
</TrainingCenterDatabase>
''';
  }

  String _toTcxSport(String sport) {
    final value = sport.trim().toLowerCase();
    if (value == 'running' || value == 'walking') {
      return 'Running';
    }
    if (value == 'cycling') {
      return 'Biking';
    }
    return 'Other';
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
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
        final pageActivities = await getActivitiesPage(
          itemsPerPage: itemsPerPage,
          page: currentPage,
        );

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

        currentPage++;
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
