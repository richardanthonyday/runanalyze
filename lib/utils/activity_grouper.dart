import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';

/// Groups activities by calendar week, month, or year.
class ActivityGroup {
  final String label; // "Week 27, 2026" or "June 2026" or "2026"
  final List<Activity> activities;
  final DateTime startDate;

  ActivityGroup({
    required this.label,
    required this.activities,
    required this.startDate,
  });

  double get totalDistance => activities.fold(0.0, (sum, a) => sum + a.distance);
  int get totalDuration => activities.fold(0, (sum, a) => sum + a.duration);
  int get count => activities.length;

  double get averagePace {
    if (totalDistance <= 0) return 0;
    return (totalDuration / 60) / totalDistance;
  }
}

/// Groups activities by timeframe (week, month, year).
class ActivityGrouper {
  /// Group activities by calendar week (Sunday-Saturday).
  static List<ActivityGroup> groupByWeek(List<Activity> activities) {
    final groups = <String, List<Activity>>{};

    for (var activity in activities) {
      final date = activity.dateTime;
      final startDate = _startOfWeek(date);
      final key = DateFormat('yyyy-MM-dd').format(startDate);
      groups.putIfAbsent(key, () => []).add(activity);
    }

    return _sortGroups(groups, (key, activities) {
      final startDate = DateTime.parse(key);
      final endDate = startDate.add(const Duration(days: 6));
      return ActivityGroup(
        label:
            '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
        activities: activities,
        startDate: startDate,
      );
    });
  }

  /// Group activities by calendar month.
  static List<ActivityGroup> groupByMonth(List<Activity> activities) {
    final groups = <String, List<Activity>>{};

    for (var activity in activities) {
      final date = activity.dateTime;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(activity);
    }

    return _sortGroups(groups, (key, activities) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final startDate = DateTime(year, month);
      return ActivityGroup(
        label: DateFormat('MMMM yyyy').format(startDate),
        activities: activities,
        startDate: startDate,
      );
    });
  }

  /// Group activities by calendar year.
  static List<ActivityGroup> groupByYear(List<Activity> activities) {
    final groups = <String, List<Activity>>{};

    for (var activity in activities) {
      final year = activity.dateTime.year.toString();
      groups.putIfAbsent(year, () => []).add(activity);
    }

    return _sortGroups(groups, (key, activities) {
      final year = int.parse(key);
      return ActivityGroup(
        label: year.toString(),
        activities: activities,
        startDate: DateTime(year),
      );
    });
  }

  /// Helper: Sort groups by start date (newest first).
  static List<ActivityGroup> _sortGroups(
    Map<String, List<Activity>> groups,
    ActivityGroup Function(String, List<Activity>) builder,
  ) {
    return groups.entries
        .map((e) => builder(e.key, e.value))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  /// Get the start date (Sunday) of a calendar week.
  static DateTime _startOfWeek(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    return localDate.subtract(Duration(days: localDate.weekday % 7));
  }
}
