import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind/Bci/BciDevicesGrpcApi.dart';

class BciDeviceRepository {
  static const String _cacheKey = 'bci_known_serials';

  final BciDevicesGrpcApi _api;
  final SharedPreferences _prefs;

  BciDeviceRepository({required BciDevicesGrpcApi api, required SharedPreferences prefs})
      : _api = api,
        _prefs = prefs;

  List<String> cachedSerials() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _writeCache(List<String> serials) async {
    await _prefs.setString(_cacheKey, jsonEncode(serials));
  }

  Future<List<String>> fetchKnownSerials() async {
    final devices = await _api.listDevices();
    final serials = devices.map((d) => d.serial).toList();
    await _writeCache(serials);
    return serials;
  }

  Future<void> registerDevice(String serial) async {
    await _api.register(serial);
  }

  Future<void> deleteDevice(String id) async {
    await _api.delete(id);
  }
}
