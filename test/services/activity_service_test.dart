import 'package:flutter_test/flutter_test.dart';
import 'package:runanalyze_mobile/models/activity.dart';
import 'package:runanalyze_mobile/services/activity_service.dart';
import 'package:runanalyze_mobile/services/runalyze_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'mock_http_client.dart';

void main() {
  group('ActivityService', () {
    late ActivityService activityService;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      final client = RunalyzeClient(
        apiToken: 'test-token',
        httpClient: mockHttpClient,
      );
      activityService = ActivityService(client: client);
    });

    group('getActivities', () {
      test('fetches and caches activities successfully', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'name': 'Running'},
            'type': {'name': 'Easy run'},
            'distance': 5.0,
            'duration': 1800,
          },
        ];
        
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );

        final activities = await activityService.getActivities();

        expect(activities.length, 1);
        expect(activities[0].id, 1);
        expect(activities[0].sport, 'Running');
        expect(activities[0].distance, 5.0);
      });

      test('uses cache on second call', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'name': 'Running'},
            'distance': 5.0,
            'duration': 1800,
          },
        ];
        
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );

        // First call
        final activities1 = await activityService.getActivities();
        final callCount1 = mockHttpClient.getCallCount();

        // Second call (should use cache)
        final activities2 = await activityService.getActivities();
        final callCount2 = mockHttpClient.getCallCount();

        expect(activities1.length, activities2.length);
        expect(callCount1, callCount2); // No additional HTTP call
      });

      test('refreshes cache when forceRefresh is true', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'name': 'Running'},
            'distance': 5.0,
            'duration': 1800,
          },
        ];
        
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );

        // First call
        await activityService.getActivities();
        final callCount1 = mockHttpClient.getCallCount();

        // Second call with forceRefresh
        await activityService.getActivities(forceRefresh: true);
        final callCount2 = mockHttpClient.getCallCount();

        expect(callCount2, callCount1 + 1); // One more HTTP call
      });

      test('returns cached data on API failure if available', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'name': 'Running'},
            'distance': 5.0,
            'duration': 1800,
          },
        ];
        
        // First call succeeds
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );
        final activities1 = await activityService.getActivities();

        // Second call fails
        mockHttpClient.setResponse(status: 500);

        // Should return cached data instead of throwing
        final activities2 = await activityService.getActivities(forceRefresh: true);
        
        expect(activities2.length, activities1.length);
      });
    });

    group('filterByDays', () {
      test('filters activities by number of days', () {
        final now = DateTime.now();
        final activities = [
          Activity(
            id: 1,
            dateTime: now.subtract(const Duration(days: 2)),
            sport: 'Running',
            distance: 5.0,
            duration: 1800,
          ),
          Activity(
            id: 2,
            dateTime: now.subtract(const Duration(days: 8)),
            sport: 'Running',
            distance: 10.0,
            duration: 3600,
          ),
        ];

        final filtered = activityService.filterByDays(activities, 7);

        expect(filtered.length, 1);
        expect(filtered[0].id, 1);
      });
    });

    group('totalDistance', () {
      test('calculates total distance correctly', () {
        final activities = [
          Activity(
            id: 1,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 5.0,
            duration: 1800,
          ),
          Activity(
            id: 2,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 10.0,
            duration: 3600,
          ),
        ];

        final total = activityService.totalDistance(activities);
        expect(total, 15.0);
      });

      test('returns 0 for empty list', () {
        final total = activityService.totalDistance([]);
        expect(total, 0.0);
      });
    });

    group('totalDuration', () {
      test('calculates total duration correctly', () {
        final activities = [
          Activity(
            id: 1,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 5.0,
            duration: 1800,
          ),
          Activity(
            id: 2,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 10.0,
            duration: 3600,
          ),
        ];

        final total = activityService.totalDuration(activities);
        expect(total, 5400);
      });
    });

    group('averagePace', () {
      test('calculates average pace correctly', () {
        final activities = [
          Activity(
            id: 1,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 10.0,
            duration: 3600, // 60 min
          ),
        ];

        // 3600 sec / 60 = 60 min, 60 / 10 km = 6 min/km
        final pace = activityService.averagePace(activities);
        expect(pace, 6.0);
      });

      test('returns 0 for zero distance', () {
        final activities = [
          Activity(
            id: 1,
            dateTime: DateTime.now(),
            sport: 'Running',
            distance: 0.0,
            duration: 1800,
          ),
        ];

        final pace = activityService.averagePace(activities);
        expect(pace, 0.0);
      });
    });

    group('clearCache', () {
      test('clears cached activities', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'name': 'Running'},
            'distance': 5.0,
            'duration': 1800,
          },
        ];
        
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );

        // Cache some activities
        await activityService.getActivities();

        // Clear cache
        activityService.clearCache();

        // Set new mock response
        final newActivities = [
          {
            'id': 2,
            'date_time': '2026-06-27T19:28:14-05:00',
            'sport': {'name': 'Cycling'},
            'distance': 20.0,
            'duration': 3600,
          },
        ];
        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(newActivities),
        );

        // Next call should fetch fresh data (without forceRefresh)
        final activities = await activityService.getActivities();
        expect(activities[0].id, 2); // Got new data
      });
    });
  });
}
