class DevicePingRequest {
  final String installationId;
  final String platform;
  final String osVersion;
  final String locale;
  final String timezone;
  final int screenWidth;
  final int screenHeight;
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
    required this.appVersion,
    required this.buildNumber,
    required this.model,
    required this.manufacturer,
  });

  Map<String, dynamic> toJson() => {
    'installationId': installationId,
    'platform': platform,
    'osVersion': osVersion,
    'locale': locale,
    'timezone': timezone,
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'model': model,
    'manufacturer': manufacturer,
  };
}
