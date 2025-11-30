class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException: [$statusCode]: $message';
    }
    return 'ApiException: $message';
  }
}
