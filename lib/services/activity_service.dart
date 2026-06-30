import '../models/activity.dart';
import 'runalyze_client.dart';

/// ActivityService provides high-level activity operations with caching.
class ActivityService {
  final RunalyzeClient client;
  List<Activity>? _cachedActivities;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10);
  int _lastFetchedPage = 0;
  int _cachedItemsPerPage = 0;
  bool _reachedLastPage = false;

  ActivityService({required this.client});

  /// Get activities, using cache if available and fresh.
  ///
  /// Set [forceRefresh] to true to ignore cache.
  Future<List<Activity>> getActivities({
    bool forceRefresh = false,
    DateTime? notBefore,
    int itemsPerPage = 500,
  }) async {
    if (forceRefresh) {
      _resetPageCache();
    }

    if (_cachedItemsPerPage != 0 && _cachedItemsPerPage != itemsPerPage) {
      _resetPageCache();
    }
    _cachedItemsPerPage = itemsPerPage;

    _cachedActivities ??= <Activity>[];

    if (_coversCutoff(notBefore)) {
      _cacheTime = DateTime.now();
      return _cachedActivities!;
    }

    try {
      while (!_coversCutoff(notBefore) && !_reachedLastPage) {
        final nextPage = _lastFetchedPage + 1;
        final pageActivities = await client.getActivitiesPage(
          itemsPerPage: itemsPerPage,
          page: nextPage,
        );

        if (pageActivities.isEmpty) {
          _reachedLastPage = true;
          break;
        }

        final existingIds = _cachedActivities!.map((a) => a.id).toSet();
        _cachedActivities!.addAll(
          pageActivities.where((a) => !existingIds.contains(a.id)),
        );
        _cachedActivities!.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        _lastFetchedPage = nextPage;
        if (pageActivities.length < itemsPerPage) {
          _reachedLastPage = true;
        }
      }

      _cacheTime = DateTime.now();
      return _cachedActivities!;
    } on RunalyzeException {
      if (forceRefresh) {
        rethrow;
      }

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
    _resetPageCache();
  }

  /// The oldest date we have definitively fetched data past.
  /// Null if no pages have been fetched yet.
  DateTime? get oldestFetchedDate {
    if (_cachedActivities == null || _cachedActivities!.isEmpty) return null;
    if (_reachedLastPage) return DateTime(2000);
    return _cachedActivities!.last.dateTime;
  }

  bool _coversCutoff(DateTime? cutoff) {
    if (_cachedActivities == null || _cachedActivities!.isEmpty) {
      return false;
    }

    if (cutoff == null) {
      return true;
    }

    if (_reachedLastPage) {
      return true;
    }

    final oldest = _cachedActivities!.last.dateTime;
    return oldest.isBefore(cutoff) || oldest.isAtSameMomentAs(cutoff);
  }

  void _resetPageCache() {
    _cachedActivities = null;
    _cacheTime = null;
    _lastFetchedPage = 0;
    _cachedItemsPerPage = 0;
    _reachedLastPage = false;
  }

  bool get _isValidCache =>
      _cachedActivities != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;
}
