import 'BciEmotionsDTO.dart';
import 'BciNfbDTO.dart';
import '../../BciPairing/Models/BciChannelQualityDTO.dart';

const Object _undefined = Object();

class BciDataState {
  final int? heartRate;
  final BciEmotionsDTO? emotions;
  final BciNfbDTO? nfb;
  final int? batteryPercent;
  final List<BciChannelQualityDTO> channels;
  final bool isConnected;

  const BciDataState({
    this.heartRate,
    this.emotions,
    this.nfb,
    this.batteryPercent,
    required this.channels,
    required this.isConnected,
  });

  static BciDataState initial() => const BciDataState(
        channels: [],
        isConnected: false,
      );

  BciDataState copyWith({
    Object? heartRate = _undefined,
    Object? emotions = _undefined,
    Object? nfb = _undefined,
    Object? batteryPercent = _undefined,
    List<BciChannelQualityDTO>? channels,
    bool? isConnected,
  }) {
    return BciDataState(
      heartRate: identical(heartRate, _undefined)
          ? this.heartRate
          : heartRate as int?,
      emotions: identical(emotions, _undefined)
          ? this.emotions
          : emotions as BciEmotionsDTO?,
      nfb: identical(nfb, _undefined) ? this.nfb : nfb as BciNfbDTO?,
      batteryPercent: identical(batteryPercent, _undefined)
          ? this.batteryPercent
          : batteryPercent as int?,
      channels: channels ?? this.channels,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
