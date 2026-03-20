import 'package:mind/BreathModule/Models/BreathSession.dart';

class BatchSessionsResponse {
  final List<BreathSession> data;

  BatchSessionsResponse({
    required this.data,
  });

  factory BatchSessionsResponse.fromJson(Map<String, dynamic> json) => BatchSessionsResponse(
    data: (json['data'] as List).map((e) => BreathSession.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
