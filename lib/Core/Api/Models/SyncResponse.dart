import 'package:mind/Core/Api/Models/ChangeEvent.dart';

class SyncResponse {
  final List<ChangeEvent> events;
  final bool fullResync;

  SyncResponse({
    required this.events,
    required this.fullResync,
  });
}
