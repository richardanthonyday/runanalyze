import '../models/activity.dart';
import 'backend_api_client.dart';

/// ActivityService provides high-level activity operations with backend or cached data.
class ActivityService {
  final BackendApiClient backendClient;
  List<Activity>? _cachedActivities;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  ActivityService({
    BackendApiClient? backendClient,
  }) : backendClient = backendClient ?? BackendApiClient();

  /// Get summary metrics from backend.
  Future<Map<String, dynamic>> getSummary({String timeframe = 'week'}) async {
    try {
      return await backendClient.getDashboardSummary(timeframe: timeframe);
    } catch (_) {
      final activities = await getActivities();
      final days = timeframe == 'week' ? 7 : (timeframe == 'month' ? 30 : 365);
      final filtered = filterByDays(activities, days);
      final totalDist = totalDistance(filtered);
      final totalDur = totalDuration(filtered);
      final avgPace = averagePace(filtered);

      return {
        'timeframe': timeframe,
        'sport': 'all',
        'distance_km': totalDist,
        'duration_seconds': totalDur,
        'activity_count': filtered.length,
        'average_pace_min_km': avgPace,
      };
    }
  }

  /// Get activities, using cache if available and fresh.
  Future<List<Activity>> getActivities({
    bool forceRefresh = false,
    DateTime? notBefore,
    int itemsPerPage = 50,
  }) async {
    if (!forceRefresh && _isValidCache && _cachedActivities != null) {
      return _cachedActivities!;
    }

    try {
      final activities = await backendClient.getActivities(limit: itemsPerPage);
      _cachedActivities = activities;
      _cacheTime = DateTime.now();
      return activities;
    } catch (e) {
      if (!forceRefresh && _cachedActivities != null) {
        return _cachedActivities!;
      }
      rethrow;
    }
  }

  /// Filter activities by timeframe (last N days).
  List<Activity> filterByDays(List<Activity> activities, int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    return activities.where((a) => a.dateTime.isAfter(cutoff)).toList();
  }

  /// Calculate total distance from activities.
  double totalDistance(List<Activity> activities) {
    return activities.fold(0.0, (sum, a) => sum + a.distance);
  }

  /// Calculate total duration in seconds.
  int totalDuration(List<Activity> activities) {
    return activities.fold(0, (sum, a) => sum + a.duration);
  }

  /// Calculate average pace (min/km).
  double averagePace(List<Activity> activities) {
    final totalDist = totalDistance(activities);
    if (totalDist <= 0) return 0;
    final totalDur = totalDuration(activities);
    return (totalDur / 60) / totalDist;
  }

  /// Clear cache.
  void clearCache() {
    _cachedActivities = null;
    _cacheTime = null;
  }

  bool get _isValidCache =>
      _cachedActivities != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;
}
