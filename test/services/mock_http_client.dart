import 'package:http/http.dart' as http;

/// Mock HTTP client for testing.
class MockHttpClient extends http.BaseClient {
  int _callCount = 0;
  int _responseStatus = 200;
  String _responseBody = '[]';
  bool _throwOnRequest = false;
  final List<Map<String, dynamic>> _queuedResponses = [];

  void setResponse({required int status, String? body}) {
    _responseStatus = status;
    _responseBody = body ?? '[]';
  }

  void setThrowOnRequest(bool shouldThrow) {
    _throwOnRequest = shouldThrow;
  }

  void setResponseQueue(List<Map<String, dynamic>> responses) {
    _queuedResponses
      ..clear()
      ..addAll(responses);
  }

  int getCallCount() => _callCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _callCount++;
    
    if (_throwOnRequest) {
      throw Exception('Network error');
    }
    
    if (_queuedResponses.isNotEmpty) {
      final next = _queuedResponses.removeAt(0);
      return http.StreamedResponse(
        Stream.value((next['body'] as String? ?? '[]').codeUnits),
        next['status'] as int? ?? 200,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value(_responseBody.codeUnits),
      _responseStatus,
      request: request,
    );
  }
}
