import '../models/activity.dart';
import 'runalyze_client.dart';

/// ActivityService provides high-level activity operations with caching.
class ActivityService {
  final RunalyzeClient client;
  List<Activity>? _cachedActivities;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  ActivityService({required this.client});

  /// Get activities, using cache if available and fresh.
  /// 
  /// Set [forceRefresh] to true to ignore cache.
  Future<List<Activity>> getActivities({bool forceRefresh = false}) async {
    if (!forceRefresh && _isValidCache) {
      return _cachedActivities!;
    }

    try {
      final activities = await client.getActivities();
      _cachedActivities = activities;
      _cacheTime = DateTime.now();
      return activities;
    } on RunalyzeException {
      // If API fails and we have cached data, return it gracefully
      if (_cachedActivities != null) {
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

  /// Clear cache (e.g., on logout or force refresh).
  void clearCache() {
    _cachedActivities = null;
    _cacheTime = null;
  }

  bool get _isValidCache =>
      _cachedActivities != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;
}
