import 'firebase_options_prod.dart';
import 'package:mind/Core/AppInitializer.dart';
import 'package:mind/Core/Environment.dart';

void main() async {
  Environment.initProd();

  await AppInitializer.initialize(firebaseOptions: DefaultFirebaseOptions.currentPlatform);
}
