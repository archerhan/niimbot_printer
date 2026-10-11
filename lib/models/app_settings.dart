/// 打印任务偏好（兼容性设置）。
///
/// 部分型号不在 niim_blue_flutter 的自动识别映射表中（如 Z401/B32 系列），
/// 自动兜底任务工作不正常时，可在此手动指定。
enum PrinterTaskPreference {
  auto('auto', '自动（推荐）'),
  b1('b1', 'B1'),
  d110mV4('d110mV4', 'D110M_V4'),
  d110('d110', 'D110'),
  b21V1('b21V1', 'B21_V1'),
  d11V1('d11V1', 'D11_V1');

  const PrinterTaskPreference(this.key, this.label);

  /// 持久化用的字符串键。
  final String key;

  /// 界面显示名。
  final String label;

  static PrinterTaskPreference fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return auto;
  }
}

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
    this.qrSizeMm = defaultQrSizeMm,
    this.density = defaultDensity,
    this.lastDeviceId = '',
    this.lastDeviceName = '',
    this.printTaskPreference = PrinterTaskPreference.auto,
  });

  static const String defaultPrefixA = 'ADM32672805';
  static const String defaultPrefixB = 'CTX';
  static const String defaultPrefixC = '6O6';
  static const int defaultSerialNumber = 1;
  static const int defaultSerialLength = 4;
  static const double defaultFontSize = 30;
  static const double defaultQrSizeMm = 12;
  static const int defaultDensity = 12;
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

  /// 二维码边长（毫米）。渲染时会自动限制，保证不超出纸张。
  final double qrSizeMm;
  final int density;
  final String lastDeviceId;
  final String lastDeviceName;
  final PrinterTaskPreference printTaskPreference;

  /// 纸张宽度（像素/打印点）。
  int get labelWidthPx => (labelWidthMm * labelDpi / 25.4).round();

  /// 纸张高度（像素/打印点）。
  int get labelHeightPx => (labelHeightMm * labelDpi / 25.4).round();

  /// 二维码边长（像素/打印点）。
  int get qrSizePx => (qrSizeMm * labelDpi / 25.4).round();

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
    double? qrSizeMm,
    int? density,
    String? lastDeviceId,
    String? lastDeviceName,
    PrinterTaskPreference? printTaskPreference,
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
      qrSizeMm: qrSizeMm ?? this.qrSizeMm,
      density: density ?? this.density,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
      printTaskPreference: printTaskPreference ?? this.printTaskPreference,
    );
  }
}
