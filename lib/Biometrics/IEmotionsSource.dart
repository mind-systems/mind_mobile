import 'dart:async';

import 'package:mind/Bci/Models/BciEmotionsData.dart';

/// Capability interface for a source that emits high-level emotion classifier
/// outputs.
///
/// [BciEmotionsData] stays under `lib/Bci/Models/` because it is produced
/// exclusively by BCI hardware emotion classifiers.
abstract interface class IEmotionsSource {
  Stream<BciEmotionsData> get emotionsStream;
}
