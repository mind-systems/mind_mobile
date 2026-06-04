import 'package:bci_module/bci_module.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';

BciSignalQuality mapBciSignalLevel(BciSignalLevel level) {
  switch (level) {
    case BciSignalLevel.green:
      return BciSignalQuality.good;
    case BciSignalLevel.yellow:
      return BciSignalQuality.fair;
    case BciSignalLevel.red:
      return BciSignalQuality.poor;
  }
}

List<BciChannelQualityDTO> mapBciChannelQualities(List<BciChannelQuality> channels) {
  return channels
      .map((c) => BciChannelQualityDTO(
            channelName: c.channelName,
            quality: mapBciSignalLevel(c.level),
            impedanceOhm: c.impedanceOhm,
          ))
      .toList(growable: false);
}
