class BciScannedDeviceDTO {
  final String serial;
  final String name;
  final bool isKnown;

  const BciScannedDeviceDTO({
    required this.serial,
    required this.name,
    required this.isKnown,
  });
}
