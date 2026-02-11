import 'firebase_options_prod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/Environment.dart';

void main() async {
  Environment.initProd();

  await App.initialize(firebaseOptions: DefaultFirebaseOptions.currentPlatform);
}
