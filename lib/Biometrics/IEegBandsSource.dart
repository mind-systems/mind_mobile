import 'dart:async';

import 'package:mind/Bci/Models/BciNfbData.dart';

/// Capability interface for a source that emits EEG band amplitude samples.
///
/// [BciNfbData] stays under `lib/Bci/Models/` because it is EEG-classifier
/// output by definition — produced exclusively by BCI hardware.
abstract interface class IEegBandsSource {
  Stream<BciNfbData> get nfbStream;
}
