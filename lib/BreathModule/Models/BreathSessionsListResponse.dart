import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionsListResponse {
  final List<BreathSession> data;
  final int total;
  final int page;
  final int pageSize;

  BreathSessionsListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory BreathSessionsListResponse.fromJson(Map<String, dynamic> json) {
    return BreathSessionsListResponse(
      data: (json['data'] as List).map((e) => BreathSession.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
    );
  }
}
