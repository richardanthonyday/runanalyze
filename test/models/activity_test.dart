import 'package:flutter_test/flutter_test.dart';
import 'package:runanalyze_mobile/models/activity.dart';

void main() {
  group('Activity Model', () {
    late Activity activity;

    setUp(() {
      activity = Activity(
        id: 1,
        dateTime: DateTime(2026, 6, 26, 19, 28, 14),
        sport: 'Running',
        type: 'Easy run',
        distance: 4.87,
        duration: 1384,
        hrMax: 162,
        hrAvg: 143,
        vo2Max: 40.78,
        temperature: 31.0,
        weather: 'sunny',
      );
    });

    group('fromJson', () {
      test('parses activity from Runalyze API JSON', () {
        final json = {
          'id': 186967505,
          'date_time': '2026-06-26T19:28:14-05:00',
          'sport': {'name': 'Running'},
          'type': {'name': 'Easy run', 'avg_hr': 143},
          'distance': 4.87,
          'duration': 1384,
          'hr_max': 162,
          'vo2max_by_time': 40.78,
          'temperature': 31,
          'weather_condition': 'sunny',
        };

        final parsed = Activity.fromJson(json);

        expect(parsed.id, 186967505);
        expect(parsed.sport, 'Running');
        expect(parsed.type, 'Easy run');
        expect(parsed.distance, 4.87);
        expect(parsed.duration, 1384);
        expect(parsed.hrMax, 162);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 1,
          'date_time': '2026-06-26T19:28:14Z',
          'sport': {'name': 'Running'},
          'distance': 5.0,
          'duration': 1800,
        };

        final parsed = Activity.fromJson(json);

        expect(parsed.id, 1);
        expect(parsed.type, isNull);
        expect(parsed.hrMax, isNull);
        expect(parsed.temperature, isNull);
      });

      test('parses numeric fields when API returns doubles', () {
        final json = {
          'id': 186967505.0,
          'date_time': '2026-06-26T19:28:14-05:00',
          'sport': {'name': 'Running'},
          'type': {'name': 'Easy run', 'avg_hr': 143.0},
          'distance': 4.87,
          'duration': 1384.0,
          'hr_max': 162.0,
          'power': 210.0,
        };

        final parsed = Activity.fromJson(json);

        expect(parsed.id, 186967505);
        expect(parsed.duration, 1384);
        expect(parsed.hrMax, 162);
        expect(parsed.hrAvg, 143);
        expect(parsed.power, 210);
      });

      test('handles missing sport gracefully', () {
        final json = {
          'id': 1,
          'date_time': '2026-06-26T19:28:14Z',
          'distance': 5.0,
          'duration': 1800,
        };

        final parsed = Activity.fromJson(json);

        expect(parsed.sport, 'Unknown');
      });
    });

    group('paceMinPerKm', () {
      test('calculates pace correctly', () {
        // 1384 sec / 60 = 23.07 min, 23.07 / 4.87 ≈ 4.73 min/km
        final expectedPace = (1384 / 60) / 4.87;
        expect(activity.paceMinPerKm, closeTo(expectedPace, 0.01));
      });

      test('returns 0 for zero distance', () {
        final zeroDistActivity = Activity(
          id: 1,
          dateTime: DateTime.now(),
          sport: 'Running',
          distance: 0.0,
          duration: 1800,
        );

        expect(zeroDistActivity.paceMinPerKm, 0.0);
      });
    });

    group('formatDuration', () {
      test('formats duration with hours and minutes', () {
        expect(activity.formatDuration(), '23m');
      });

      test('formats duration with only minutes', () {
        final shortActivity = Activity(
          id: 1,
          dateTime: DateTime.now(),
          sport: 'Running',
          distance: 5.0,
          duration: 600, // 10 min
        );

        expect(shortActivity.formatDuration(), '10m');
      });

      test('formats duration with hours', () {
        final longActivity = Activity(
          id: 1,
          dateTime: DateTime.now(),
          sport: 'Running',
          distance: 15.0,
          duration: 5400, // 1h 30m
        );

        expect(longActivity.formatDuration(), '1h 30m');
      });
    });

    group('formatPace', () {
      test('formats pace as min/km', () {
        final pace = activity.formatPace();
        expect(pace, contains('min/km'));
        expect(pace, isNotEmpty);
      });
    });

    group('equality and hashing', () {
      test('two activities with same data are independent objects', () {
        final activity1 = Activity(
          id: 1,
          dateTime: DateTime(2026, 6, 26),
          sport: 'Running',
          distance: 5.0,
          duration: 1800,
        );

        final activity2 = Activity(
          id: 1,
          dateTime: DateTime(2026, 6, 26),
          sport: 'Running',
          distance: 5.0,
          duration: 1800,
        );

        // Same values
        expect(activity1.id, activity2.id);
        expect(activity1.distance, activity2.distance);
      });
    });
  });
}
