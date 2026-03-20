import 'package:mind/Core/Api/Models/ChangeEvent.dart';

class SyncResponse {
  final List<ChangeEvent> events;
  final bool fullResync;

  SyncResponse({
    required this.events,
    required this.fullResync,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
    events: (json['events'] as List).map((e) => ChangeEvent.fromJson(e as Map<String, dynamic>)).toList(),
    fullResync: json['fullResync'] as bool? ?? false,
  );
}
