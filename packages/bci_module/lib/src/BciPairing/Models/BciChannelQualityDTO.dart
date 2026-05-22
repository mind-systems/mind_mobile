enum BciSignalQuality { good, fair, poor }

class BciChannelQualityDTO {
  final String channelName;
  final BciSignalQuality quality;

  const BciChannelQualityDTO({
    required this.channelName,
    required this.quality,
  });
}
