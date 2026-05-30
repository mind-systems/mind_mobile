import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind/Bci/Models/NfbCalibrationData.dart';
import 'package:mind/Bci/NfbCalibrationGrpcApi.dart';
import 'package:mind/Logger.dart';

class NfbCalibrationRepository {
  static const int _maxEntries = 20;

  final SharedPreferences _prefs;
  final NfbCalibrationGrpcApi _api;

  NfbCalibrationRepository({required SharedPreferences prefs, required NfbCalibrationGrpcApi api})
      : _prefs = prefs,
        _api = api;

  String _keyFor(String serial) => 'bci_nfb_cal_history_$serial';

  List<NfbCalibrationData> history(String serial) {
    final raw = _prefs.getString(_keyFor(serial));
    if (raw == null) return const <NfbCalibrationData>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <NfbCalibrationData>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => NfbCalibrationData.fromJson(e))
          .toList();
    } catch (_) {
      return const <NfbCalibrationData>[];
    }
  }

  NfbCalibrationData? latestValid(String serial) {
    for (final entry in history(serial)) {
      if (entry.isValid) return entry;
    }
    return null;
  }

  Future<void> refreshFromServer(String serial) async {
    try {
      final list = await _api.list(serial);
      final trimmed = list.length > _maxEntries ? list.sublist(0, _maxEntries) : list;
      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await _prefs.setString(_keyFor(serial), encoded);
    } catch (e) {
      logPrint('NfbCalibrationRepository: refreshFromServer failed for $serial: $e');
    }
  }

  Future<void> record(String serial, NfbCalibrationData data) async {
    final existing = history(serial);
    var newList = [data, ...existing];
    if (newList.length > _maxEntries) {
      newList = newList.sublist(0, _maxEntries);
    }
    final encoded = jsonEncode(newList.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyFor(serial), encoded);
    unawaited(_api.record(serial, data).catchError(
      (Object e) => logPrint('NfbCalibrationRepository: sync failed: $e'),
    ));
  }
}
