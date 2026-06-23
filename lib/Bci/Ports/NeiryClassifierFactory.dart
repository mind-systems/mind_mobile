import 'package:neiry_kit/neiry_kit.dart' as neiry;

import 'ClassifierFactory.dart';
import 'ClassifierSet.dart';
import 'DevicePort.dart';
import 'NeiryClassifierSet.dart';
import 'NeiryDeviceAdapter.dart';

/// Thin factory that builds a [NeiryClassifierSet] from a [NeiryDeviceAdapter].
///
/// Extracts the raw [neiry.Device] handle from the adapter and delegates to
/// [NeiryClassifierSet], which constructs the four classifiers in order.
///
/// This is one of two files (with [NeiryClassifierSet]) permitted to import
/// `neiry_kit`.
class NeiryClassifierFactory implements ClassifierFactory {
  @override
  ClassifierSet build(DevicePort device) {
    final raw = (device as NeiryDeviceAdapter).rawDevice;
    return NeiryClassifierSet(raw);
  }
}
