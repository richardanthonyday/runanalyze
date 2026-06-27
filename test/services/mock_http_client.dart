import 'package:http/http.dart' as http;

/// Mock HTTP client for testing.
class MockHttpClient extends http.BaseClient {
  int _callCount = 0;
  int _responseStatus = 200;
  String _responseBody = '[]';

  void setResponse({required int status, String? body}) {
    _responseStatus = status;
    _responseBody = body ?? '[]';
  }

  int getCallCount() => _callCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _callCount++;
    
    return http.StreamedResponse(
      Stream.value(_responseBody.codeUnits),
      _responseStatus,
      request: request,
    );
  }
}
