import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/product_series.dart';

/// 基于 shared_preferences 的设置读写（含产品系列的增删改切换）。
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const String kSeriesList = 'seriesList';
  static const String kCurrentSeriesId = 'currentSeriesId';
  static const String kSerialLength = 'serialLength';
  static const String kContinuousMode = 'continuousMode';
  static const String kOffsetX = 'offsetX';
  static const String kOffsetY = 'offsetY';
  static const String kLabelWidthMm = 'labelWidthMm';
  static const String kLabelHeightMm = 'labelHeightMm';
  static const String kLabelDpi = 'labelDpi';
  static const String kFontSize = 'fontSize';
  static const String kQrSizeMm = 'qrSizeMm';
  static const String kDensity = 'density';
  static const String kLastDeviceId = 'lastDeviceId';
  static const String kLastDeviceName = 'lastDeviceName';
  static const String kPrintTask = 'printTask';

  // 老版本遗留字段（全局前缀 + 序号），仅用于一次性迁移。
  static const String kLegacyPrefixA = 'prefixA';
  static const String kLegacyPrefixB = 'prefixB';
  static const String kLegacyPrefixC = 'prefixC';
  static const String kLegacySerialNumber = 'serialNumber';

  /// 读取完整设置快照。
  AppSettings get settings => AppSettings(
        seriesList: seriesList,
        currentSeriesId: currentSeriesId,
        serialLength:
            _prefs.getInt(kSerialLength) ?? AppSettings.defaultSerialLength,
        continuousMode: _prefs.getBool(kContinuousMode) ?? false,
        offsetX: _prefs.getInt(kOffsetX) ?? 0,
        offsetY: _prefs.getInt(kOffsetY) ?? 0,
        labelWidthMm:
            _prefs.getDouble(kLabelWidthMm) ?? AppSettings.defaultLabelWidthMm,
        labelHeightMm: _prefs.getDouble(kLabelHeightMm) ??
            AppSettings.defaultLabelHeightMm,
        labelDpi: _prefs.getInt(kLabelDpi) ?? AppSettings.defaultLabelDpi,
        fontSize: _prefs.getDouble(kFontSize) ?? AppSettings.defaultFontSize,
        qrSizeMm: _prefs.getDouble(kQrSizeMm) ?? AppSettings.defaultQrSizeMm,
        density: _prefs.getInt(kDensity) ?? AppSettings.defaultDensity,
        lastDeviceId: _prefs.getString(kLastDeviceId) ?? '',
        lastDeviceName: _prefs.getString(kLastDeviceName) ?? '',
        printTaskPreference: PrinterTaskPreference.fromKey(
          _prefs.getString(kPrintTask),
        ),
      );

  // ---------------------------------------------------------------- 产品系列

  /// 全部产品系列，始终至少返回一个。
  List<ProductSeries> get seriesList {
    final raw = _prefs.getString(kSeriesList);
    if (raw != null && raw.isNotEmpty) {
      final parsed = _decodeSeries(raw);
      if (parsed.isNotEmpty) return parsed;
    }
    return <ProductSeries>[_legacySeries()];
  }

  /// 当前产品系列。
  ProductSeries get currentSeries => settings.currentSeries;

  /// 当前系列 id；非法或缺失时回退到第一个系列。
  String get currentSeriesId {
    final id = _prefs.getString(kCurrentSeriesId);
    final list = seriesList;
    if (id != null && list.any((series) => series.id == id)) return id;
    return list.first.id;
  }

  /// 老版本升级：把旧的全局前缀 + 序号迁移成一个系列。
  Future<void> migrateIfNeeded() async {
    if (_prefs.containsKey(kSeriesList)) return;
    final series = _legacySeries();
    await saveSeriesList(<ProductSeries>[series]);
    await _prefs.setString(kCurrentSeriesId, series.id);
  }

  Future<void> saveSeriesList(List<ProductSeries> list) async {
    await _prefs.setString(
      kSeriesList,
      jsonEncode(list.map((series) => series.toJson()).toList()),
    );
  }

  Future<void> addSeries(ProductSeries series) =>
      saveSeriesList(<ProductSeries>[...seriesList, series]);

  Future<void> updateSeries(ProductSeries series) {
    final list =
        seriesList.map((item) => item.id == series.id ? series : item).toList();
    return saveSeriesList(list);
  }

  /// 删除系列。调用方需保证它不是当前系列。
  Future<void> deleteSeries(String id) async {
    final list = seriesList.where((series) => series.id != id).toList();
    if (list.isEmpty) return;
    await saveSeriesList(list);
    if (currentSeriesId == id) {
      await _prefs.setString(kCurrentSeriesId, list.first.id);
    }
  }

  Future<void> switchSeries(String id) => _prefs.setString(kCurrentSeriesId, id);

  /// 当前系列序号 +1（打印成功后调用）。
  Future<void> incrementSerial() async {
    final current = currentSeries;
    await updateSeries(current.copyWith(serialNumber: current.serialNumber + 1));
  }

  /// 手动修正当前系列序号。
  Future<void> setCurrentSerial(int value) async {
    final current = currentSeries;
    await updateSeries(current.copyWith(serialNumber: value));
  }

  // ------------------------------------------------------------------ 其它项

  Future<void> setContinuousMode(bool value) =>
      _prefs.setBool(kContinuousMode, value);

  Future<void> setOffsetX(int value) => _prefs.setInt(kOffsetX, value);
  Future<void> setOffsetY(int value) => _prefs.setInt(kOffsetY, value);
  Future<void> setLabelWidthMm(double value) =>
      _prefs.setDouble(kLabelWidthMm, value);
  Future<void> setLabelHeightMm(double value) =>
      _prefs.setDouble(kLabelHeightMm, value);
  Future<void> setLabelDpi(int value) => _prefs.setInt(kLabelDpi, value);
  Future<void> setFontSize(double value) => _prefs.setDouble(kFontSize, value);
  Future<void> setQrSizeMm(double value) => _prefs.setDouble(kQrSizeMm, value);
  Future<void> setDensity(int value) => _prefs.setInt(kDensity, value);

  Future<void> setLastDevice({required String id, required String name}) async {
    await _prefs.setString(kLastDeviceId, id);
    await _prefs.setString(kLastDeviceName, name);
  }

  /// 打印任务偏好（兼容性设置，立即生效）。
  Future<void> setPrintTaskPreference(PrinterTaskPreference value) =>
      _prefs.setString(kPrintTask, value.key);

  // ---------------------------------------------------------------- 内部实现

  static List<ProductSeries> _decodeSeries(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ProductSeries>[];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map((item) => ProductSeries.fromJson(item.cast<String, Object?>()))
          .toList();
    } catch (_) {
      return const <ProductSeries>[];
    }
  }

  /// 用老字段构造一个系列（迁移与兜底用）。
  ProductSeries _legacySeries() => ProductSeries(
        id: 'legacy-default',
        createdAt: 0,
        prefixA:
            _prefs.getString(kLegacyPrefixA) ?? ProductSeries.defaultPrefixA,
        prefixB:
            _prefs.getString(kLegacyPrefixB) ?? ProductSeries.defaultPrefixB,
        prefixC:
            _prefs.getString(kLegacyPrefixC) ?? ProductSeries.defaultPrefixC,
        serialNumber: _prefs.getInt(kLegacySerialNumber) ?? 1,
      );
}
