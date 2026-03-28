import 'package:mind/Core/Grpc/ActivityType.dart';

abstract interface class ILiveSocketService {
  Stream<Map<String, dynamic>> get sessionStateEvents;
  void sendActivityStart({required ActivityType type, String? refId});
  void sendActivityEnd();
  void sendActivityStop();
  void sendActivityPause();
  void sendActivityResume();
}
