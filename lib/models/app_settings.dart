/// 应用设置快照。
class AppSettings {
  const AppSettings({
    this.prefixA = defaultPrefixA,
    this.prefixB = defaultPrefixB,
    this.prefixC = defaultPrefixC,
    this.serialNumber = defaultSerialNumber,
    this.serialLength = defaultSerialLength,
    this.continuousMode = false,
    this.offsetX = 0,
    this.offsetY = 0,
    this.labelWidthMm = defaultLabelWidthMm,
    this.labelHeightMm = defaultLabelHeightMm,
    this.labelDpi = defaultLabelDpi,
    this.fontSize = defaultFontSize,
    this.density = 3,
    this.lastDeviceId = '',
    this.lastDeviceName = '',
  });

  static const String defaultPrefixA = 'ADM32672805';
  static const String defaultPrefixB = 'CTX';
  static const String defaultPrefixC = '6O6';
  static const int defaultSerialNumber = 1;
  static const int defaultSerialLength = 4;
  static const double defaultFontSize = 24;
  static const int defaultDensity = 3;
  static const double defaultLabelWidthMm = 40;
  static const double defaultLabelHeightMm = 20;
  static const int defaultLabelDpi = 300;

  final String prefixA;
  final String prefixB;
  final String prefixC;
  final int serialNumber;
  final int serialLength;
  final bool continuousMode;
  final int offsetX;
  final int offsetY;
  final double labelWidthMm;
  final double labelHeightMm;
  final int labelDpi;
  final double fontSize;
  final int density;
  final String lastDeviceId;
  final String lastDeviceName;

  /// 纸张宽度（像素/打印点）。
  int get labelWidthPx => (labelWidthMm * labelDpi / 25.4).round();

  /// 纸张高度（像素/打印点）。
  int get labelHeightPx => (labelHeightMm * labelDpi / 25.4).round();

  AppSettings copyWith({
    String? prefixA,
    String? prefixB,
    String? prefixC,
    int? serialNumber,
    int? serialLength,
    bool? continuousMode,
    int? offsetX,
    int? offsetY,
    double? labelWidthMm,
    double? labelHeightMm,
    int? labelDpi,
    double? fontSize,
    int? density,
    String? lastDeviceId,
    String? lastDeviceName,
  }) {
    return AppSettings(
      prefixA: prefixA ?? this.prefixA,
      prefixB: prefixB ?? this.prefixB,
      prefixC: prefixC ?? this.prefixC,
      serialNumber: serialNumber ?? this.serialNumber,
      serialLength: serialLength ?? this.serialLength,
      continuousMode: continuousMode ?? this.continuousMode,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      labelWidthMm: labelWidthMm ?? this.labelWidthMm,
      labelHeightMm: labelHeightMm ?? this.labelHeightMm,
      labelDpi: labelDpi ?? this.labelDpi,
      fontSize: fontSize ?? this.fontSize,
      density: density ?? this.density,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
    );
  }
}
