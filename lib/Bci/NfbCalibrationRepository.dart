import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind/Bci/Models/NfbCalibrationData.dart';

class NfbCalibrationRepository {
  static const int _maxEntries = 20;

  final SharedPreferences _prefs;

  NfbCalibrationRepository({required SharedPreferences prefs}) : _prefs = prefs;

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

  Future<void> record(String serial, NfbCalibrationData data) async {
    final existing = history(serial);
    var newList = [data, ...existing];
    if (newList.length > _maxEntries) {
      newList = newList.sublist(0, _maxEntries);
    }
    final encoded = jsonEncode(newList.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyFor(serial), encoded);
  }
}
