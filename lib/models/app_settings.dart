import 'product_series.dart';

/// 应用设置快照。
class AppSettings {
  const AppSettings({
    this.seriesList = const <ProductSeries>[],
    this.currentSeriesId = '',
    this.serialLength = defaultSerialLength,
    this.continuousMode = false,
    this.offsetX = 0,
    this.offsetY = 0,
    this.labelWidthMm = defaultLabelWidthMm,
    this.labelHeightMm = defaultLabelHeightMm,
    this.labelDpi = defaultLabelDpi,
    this.fontSize = defaultFontSize,
    this.density = defaultDensity,
    this.lastDeviceId = '',
    this.lastDeviceName = '',
  });

  static const int defaultSerialLength = 4;
  static const double defaultFontSize = 24;
  static const int defaultDensity = 3;
  static const double defaultLabelWidthMm = 40;
  static const double defaultLabelHeightMm = 20;
  static const int defaultLabelDpi = 300;

  /// 产品系列列表（正常情况下至少一个）。
  final List<ProductSeries> seriesList;

  /// 当前产品系列的 id。
  final String currentSeriesId;

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

  /// 当前产品系列。列表为空或 id 找不到时回退（正常情况下不会发生）。
  ProductSeries get currentSeries {
    if (seriesList.isEmpty) return ProductSeries.fallback;
    for (final series in seriesList) {
      if (series.id == currentSeriesId) return series;
    }
    return seriesList.first;
  }

  /// 纸张宽度（像素/打印点）。
  int get labelWidthPx => (labelWidthMm * labelDpi / 25.4).round();

  /// 纸张高度（像素/打印点）。
  int get labelHeightPx => (labelHeightMm * labelDpi / 25.4).round();

  AppSettings copyWith({
    List<ProductSeries>? seriesList,
    String? currentSeriesId,
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
      seriesList: seriesList ?? this.seriesList,
      currentSeriesId: currentSeriesId ?? this.currentSeriesId,
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
