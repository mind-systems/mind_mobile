import 'package:mind/Bci/Models/NfbCalibrationData.dart';
import 'package:mind/Core/Grpc/generated/nfb_calibration.pbgrpc.dart';

class NfbCalibrationGrpcApi {
  final NfbCalibrationServiceClient _client;

  NfbCalibrationGrpcApi(this._client);

  Future<void> record(String serial, NfbCalibrationData data) async {
    await _client.record(RecordNfbCalibrationRequest(
      deviceSerial: serial,
      calibratedAt: data.calibratedAt.toIso8601String(),
      isValid: data.isValid,
      failReason: data.failReason,
      individualFrequency: data.individualFrequency,
      individualPeakFrequencyPower: data.individualPeakFrequencyPower,
      individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
      individualBandwidth: data.individualBandwidth,
      individualNormalizedPower: data.individualNormalizedPower,
      lowerFrequency: data.lowerFrequency,
      upperFrequency: data.upperFrequency,
    ));
    // Return value (NfbCalibrationRecord) is intentionally discarded — repository
    // treats remote sync as fire-and-forget; the server-assigned id/createdAt are
    // not needed by the local cache in this milestone.
  }

  Future<List<NfbCalibrationData>> list(String serial, {int limit = 50}) async {
    final response = await _client.list(ListNfbCalibrationsRequest(
      deviceSerial: serial,
      limit: limit,
    ));
    return response.records.map(_recordToDomain).toList(growable: false);
  }

  NfbCalibrationData _recordToDomain(NfbCalibrationRecord r) {
    return NfbCalibrationData(
      calibratedAt: DateTime.parse(r.calibratedAt),
      isValid: r.isValid,
      failReason: r.failReason,
      individualFrequency: r.individualFrequency,
      individualPeakFrequencyPower: r.individualPeakFrequencyPower,
      individualPeakFrequencySuppression: r.individualPeakFrequencySuppression,
      individualBandwidth: r.individualBandwidth,
      individualNormalizedPower: r.individualNormalizedPower,
      lowerFrequency: r.lowerFrequency,
      upperFrequency: r.upperFrequency,
    );
  }
}
