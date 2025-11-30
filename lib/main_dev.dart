import 'firebase_options_dev.dart';
import 'package:mind/Core/AppInitializer.dart';
import 'package:mind/Core/Environment.dart';

void main() async {
  Environment.initDev();

  await AppInitializer.initialize(firebaseOptions: DefaultFirebaseOptions.currentPlatform);
}
