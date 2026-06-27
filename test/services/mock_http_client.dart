import 'package:http/http.dart' as http;

/// Mock HTTP client for testing.
class MockHttpClient extends http.BaseClient {
  int _callCount = 0;
  int _responseStatus = 200;
  String _responseBody = '[]';
  bool _throwOnRequest = false;

  void setResponse({required int status, String? body}) {
    _responseStatus = status;
    _responseBody = body ?? '[]';
  }

  void setThrowOnRequest(bool shouldThrow) {
    _throwOnRequest = shouldThrow;
  }

  int getCallCount() => _callCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _callCount++;
    
    if (_throwOnRequest) {
      throw Exception('Network error');
    }
    
    return http.StreamedResponse(
      Stream.value(_responseBody.codeUnits),
      _responseStatus,
      request: request,
    );
  }
}
