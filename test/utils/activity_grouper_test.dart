import 'package:flutter_test/flutter_test.dart';
import 'package:runanalyze_mobile/models/activity.dart';
import 'package:runanalyze_mobile/utils/activity_grouper.dart';

void main() {
  group('ActivityGrouper', () {
    late List<Activity> activities;

    setUp(() {
      // Create test activities spanning multiple weeks/months
      activities = [
        Activity(
          id: 1,
          dateTime: DateTime(2026, 6, 26), // Friday
          sport: 'Running',
          type: 'Easy run',
          distance: 5.0,
          duration: 1800, // 30 min
        ),
        Activity(
          id: 2,
          dateTime: DateTime(2026, 6, 27), // Saturday
          sport: 'Running',
          type: 'Long run',
          distance: 10.0,
          duration: 3600, // 60 min
        ),
        Activity(
          id: 3,
          dateTime: DateTime(2026, 7, 3), // Friday (next week)
          sport: 'Cycling',
          distance: 20.0,
          duration: 3600, // 60 min
        ),
        Activity(
          id: 4,
          dateTime: DateTime(2026, 8, 1), // Next month
          sport: 'Running',
          type: 'Tempo run',
          distance: 8.0,
          duration: 2400, // 40 min
        ),
      ];
    });

    group('groupByWeek', () {
      test('groups activities by ISO week', () {
        final groups = ActivityGrouper.groupByWeek(activities);

        // Should have at least 2 groups (week of 6/26 and week of 7/3)
        expect(groups.length, greaterThanOrEqualTo(2));

        // Each group should have label and activities
        for (var group in groups) {
          expect(group.label, isNotEmpty);
          expect(group.activities, isNotEmpty);
        }
      });

      test('sorts groups newest first', () {
        final groups = ActivityGrouper.groupByWeek(activities);
        
        // Verify newest group is first
        if (groups.length > 1) {
          expect(groups[0].startDate.isAfter(groups[1].startDate), true);
        }
      });

      test('calculates group totals correctly', () {
        final groups = ActivityGrouper.groupByWeek(activities);
        
        // Find the first week group (Jun 26-27)
        final firstWeekGroup = groups.firstWhere(
          (g) => g.activities.any((a) => a.id == 1),
        );

        expect(firstWeekGroup.count, 2);
        expect(firstWeekGroup.totalDistance, 15.0); // 5 + 10
        expect(firstWeekGroup.totalDuration, 5400); // 1800 + 3600
      });

      test('calculates average pace correctly', () {
        final groups = ActivityGrouper.groupByWeek(activities);
        
        final firstWeekGroup = groups.firstWhere(
          (g) => g.activities.any((a) => a.id == 1),
        );

        final expectedPace = (5400 / 60) / 15.0; // (5400 sec / 60) / 15 km
        expect(firstWeekGroup.averagePace, closeTo(expectedPace, 0.01));
      });
    });

    group('groupByMonth', () {
      test('groups activities by calendar month', () {
        final groups = ActivityGrouper.groupByMonth(activities);

        // Should have 2 groups (June and July, and August)
        expect(groups.length, 3);

        // Verify group labels
        expect(groups.any((g) => g.label.contains('June')), true);
        expect(groups.any((g) => g.label.contains('July')), true);
        expect(groups.any((g) => g.label.contains('August')), true);
      });

      test('sorts groups newest first', () {
        final groups = ActivityGrouper.groupByMonth(activities);
        
        if (groups.length > 1) {
          expect(groups[0].startDate.isAfter(groups[1].startDate), true);
        }
      });

      test('calculates June totals correctly', () {
        final groups = ActivityGrouper.groupByMonth(activities);
        
        final juneGroup = groups.firstWhere((g) => g.label.contains('June'));
        
        // June has activities 1 and 2
        expect(juneGroup.count, 2);
        expect(juneGroup.totalDistance, 15.0); // 5 + 10
      });
    });

    group('groupByYear', () {
      test('groups activities by year', () {
        final groups = ActivityGrouper.groupByYear(activities);

        // All test activities are in 2026, so should be 1 group
        expect(groups.length, 1);
        expect(groups[0].label, '2026');
      });

      test('calculates year totals correctly', () {
        final groups = ActivityGrouper.groupByYear(activities);
        
        final yearGroup = groups[0];
        expect(yearGroup.count, 4);
        expect(yearGroup.totalDistance, 43.0); // 5 + 10 + 20 + 8
        expect(yearGroup.totalDuration, 11400); // 1800 + 3600 + 3600 + 2400
      });
    });

    group('Activity totals', () {
      test('handles empty activity list', () {
        final groups = ActivityGrouper.groupByWeek([]);
        expect(groups.length, 0);
      });

      test('calculates pace with zero distance returns 0', () {
        final group = ActivityGroup(
          label: 'Test',
          activities: [
            Activity(
              id: 1,
              dateTime: DateTime.now(),
              sport: 'Running',
              distance: 0.0,
              duration: 1800,
            ),
          ],
          startDate: DateTime.now(),
        );

        expect(group.averagePace, 0.0);
      });
    });
  });
}
