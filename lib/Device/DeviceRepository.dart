import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:mind/Core/Api/DeviceApi.dart';
import 'package:mind/Core/Api/Models/DevicePingRequest.dart';
import 'package:mind/User/Infrastructure/ISecureStorage.dart';

class DeviceRepository {
  static const _installationIdKey = 'device_installation_id';

  final DeviceApi _api;
  final ISecureStorage _storage;

  DeviceRepository({required DeviceApi api, required ISecureStorage storage})
      : _api = api,
        _storage = storage;

  Future<void> ping() async {
    try {
      final request = await _buildRequest();
      await _api.ping(request);
    } catch (_) {}
  }

  Future<DevicePingRequest> _buildRequest() async {
    final installationId = await _loadOrCreateInstallationId();
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    String osVersion = '';
    String model = '';
    String manufacturer = '';

    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      osVersion = info.systemVersion;
      model = info.utsname.machine;
      manufacturer = 'Apple';
    } else if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      osVersion = info.version.release;
      model = info.model;
      manufacturer = info.manufacturer;
    }

    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = window.physicalSize;
    final pixelRatio = window.devicePixelRatio;

    return DevicePingRequest(
      installationId: installationId,
      platform: Platform.isIOS ? 'ios' : 'android',
      osVersion: osVersion,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenWidth: size.width / pixelRatio,
      screenHeight: size.height / pixelRatio,
      pixelRatio: pixelRatio,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      model: model,
      manufacturer: manufacturer,
    );
  }

  Future<String> _loadOrCreateInstallationId() async {
    final existing = await _storage.read(_installationIdKey);
    if (existing != null) return existing;
    final newId = const Uuid().v4();
    await _storage.write(_installationIdKey, newId);
    return newId;
  }
}
