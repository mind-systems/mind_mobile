class DevicePingRequest {
  final String installationId;
  final String platform;
  final String osVersion;
  final String locale;
  final String timezone;
  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;
  final String appVersion;
  final String buildNumber;
  final String model;
  final String manufacturer;

  DevicePingRequest({
    required this.installationId,
    required this.platform,
    required this.osVersion,
    required this.locale,
    required this.timezone,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.appVersion,
    required this.buildNumber,
    required this.model,
    required this.manufacturer,
  });

  Map<String, dynamic> toJson() => {
    'installation_id': installationId,
    'platform': platform,
    'os_version': osVersion,
    'locale': locale,
    'timezone': timezone,
    'screen_width': screenWidth,
    'screen_height': screenHeight,
    'pixel_ratio': pixelRatio,
    'app_version': appVersion,
    'build_number': buildNumber,
    'model': model,
    'manufacturer': manufacturer,
  };
}
