enum BciSignalQuality { good, fair, poor }

class BciChannelQualityDTO {
  final String channelName;
  final BciSignalQuality quality;
  final double? impedanceOhm;

  const BciChannelQualityDTO({
    required this.channelName,
    required this.quality,
    this.impedanceOhm,
  });
}
