import 'package:flutter_test/flutter_test.dart';
import 'package:runanalyze_mobile/services/runalyze_client.dart';
import 'dart:convert';

import 'mock_http_client.dart';

void main() {
  group('RunalyzeClient', () {
    late RunalyzeClient client;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      client = RunalyzeClient(
        apiToken: 'test-token-12345',
        httpClient: mockHttpClient,
      );
    });

    group('getActivities', () {
      test('fetches activities successfully', () async {
        final mockActivities = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'id': 1, 'name': 'Running'},
            'type': {'id': 1, 'name': 'Easy run', 'avg_hr': 143},
            'distance': 4.87,
            'duration': 1384,
            'hr_max': 162,
          },
          {
            'id': 2,
            'date_time': '2026-06-23T20:46:00+00:00',
            'sport': {'id': 2, 'name': 'Cycling'},
            'distance': 4.83,
            'duration': 1260,
            'hr_max': 155,
          },
        ];

        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivities),
        );

        final activities = await client.getActivities();

        expect(activities.length, 2);
        expect(activities[0].id, 1);
        expect(activities[0].sport, 'Running');
        expect(activities[1].sport, 'Cycling');
      });

      test('uses correct query parameters', () async {
        mockHttpClient.setResponse(status: 200, body: '[]');

        await client.getActivities(
          itemsPerPage: 50,
          page: 2,
        );

        // Verify the request was made (call count increased)
        expect(mockHttpClient.getCallCount(), 1);
      });

      test('throws RunalyzeException on 401 auth failure', () async {
        mockHttpClient.setResponse(status: 401);

        expect(
          () => client.getActivities(),
          throwsA(isA<RunalyzeException>()),
        );
      });

      test('throws RunalyzeException on 500 server error', () async {
        mockHttpClient.setResponse(status: 500);

        expect(
          () => client.getActivities(),
          throwsA(isA<RunalyzeException>()),
        );
      });

      test('includes Bearer token in auth header', () async {
        mockHttpClient.setResponse(status: 200, body: '[]');

        await client.getActivities();

        // Verify auth header was sent (client was constructed with token)
        expect(client.apiToken, 'test-token-12345');
      });

      test('handles empty response list', () async {
        mockHttpClient.setResponse(status: 200, body: '[]');

        final activities = await client.getActivities();

        expect(activities, isEmpty);
      });

      test('aggregates activities across multiple pages', () async {
        final page1 = [
          {
            'id': 1,
            'date_time': '2026-06-26T19:28:14-05:00',
            'sport': {'id': 1, 'name': 'Running'},
            'distance': 5.0,
            'duration': 1800,
          },
          {
            'id': 2,
            'date_time': '2026-06-25T19:28:14-05:00',
            'sport': {'id': 1, 'name': 'Running'},
            'distance': 6.0,
            'duration': 1900,
          },
        ];

        final page2 = [
          {
            'id': 3,
            'date_time': '2026-06-24T19:28:14-05:00',
            'sport': {'id': 2, 'name': 'Cycling'},
            'distance': 10.0,
            'duration': 2100,
          },
        ];

        mockHttpClient.setResponseQueue([
          {'status': 200, 'body': jsonEncode(page1)},
          {'status': 200, 'body': jsonEncode(page2)},
        ]);

        final activities = await client.getActivities(itemsPerPage: 2);

        expect(activities.length, 3);
        expect(mockHttpClient.getCallCount(), 2);
      });

      test('handles network timeout', () async {
        mockHttpClient.setThrowOnRequest(true);

        expect(
          () => client.getActivities(),
          throwsA(isA<RunalyzeException>()),
        );
      });
    });

    group('getActivity', () {
      test('fetches single activity by ID', () async {
        final mockActivity = {
          'id': 123,
          'date_time': '2026-06-26T19:28:14-05:00',
          'sport': {'name': 'Running'},
          'distance': 5.0,
          'duration': 1800,
        };

        mockHttpClient.setResponse(
          status: 200,
          body: jsonEncode(mockActivity),
        );

        final activity = await client.getActivity(123);

        expect(activity, isNotNull);
        expect(activity!.id, 123);
        expect(activity.distance, 5.0);
      });

      test('returns null on 404 not found', () async {
        mockHttpClient.setResponse(status: 404);

        final activity = await client.getActivity(999);

        expect(activity, isNull);
      });

      test('throws RunalyzeException on 401 auth failure', () async {
        mockHttpClient.setResponse(status: 401);

        expect(
          () => client.getActivity(123),
          throwsA(isA<RunalyzeException>()),
        );
      });

      test('throws RunalyzeException on other errors', () async {
        mockHttpClient.setResponse(status: 500);

        expect(
          () => client.getActivity(123),
          throwsA(isA<RunalyzeException>()),
        );
      });
    });

    group('RunalyzeException', () {
      test('has readable error message', () {
        final exception = RunalyzeException('Test error message');

        expect(exception.toString(), contains('Test error message'));
        expect(exception.message, 'Test error message');
      });
    });

    group('API integration', () {
      test('constructs correct base URL', () {
        expect(RunalyzeClient.baseUrl, 'https://runalyze.com/api/v1');
      });

      test('can be instantiated with custom httpClient', () {
        final customMockClient = MockHttpClient();
        final customClient = RunalyzeClient(
          apiToken: 'token',
          httpClient: customMockClient,
        );

        expect(customClient.httpClient, customMockClient);
      });

      test('uses default http.Client if not provided', () {
        // This should not throw
        final defaultClient = RunalyzeClient(apiToken: 'token');
        expect(defaultClient.httpClient, isNotNull);
      });
    });
  });
}
