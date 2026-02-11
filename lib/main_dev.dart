import 'firebase_options_dev.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/Environment.dart';

void main() async {
  Environment.initDev();

  await App.initialize(firebaseOptions: DefaultFirebaseOptions.currentPlatform);
}
