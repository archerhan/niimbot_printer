import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// 基于 shared_preferences 的设置读写。
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const String kPrefixA = 'prefixA';
  static const String kPrefixB = 'prefixB';
  static const String kPrefixC = 'prefixC';
  static const String kSerialNumber = 'serialNumber';
  static const String kSerialLength = 'serialLength';
  static const String kContinuousMode = 'continuousMode';
  static const String kOffsetX = 'offsetX';
  static const String kOffsetY = 'offsetY';
  static const String kLabelWidthMm = 'labelWidthMm';
  static const String kLabelHeightMm = 'labelHeightMm';
  static const String kLabelDpi = 'labelDpi';
  static const String kFontSize = 'fontSize';
  static const String kDensity = 'density';
  static const String kLastDeviceId = 'lastDeviceId';
  static const String kLastDeviceName = 'lastDeviceName';

  /// 读取完整设置快照。
  AppSettings get settings => AppSettings(
        prefixA: _prefs.getString(kPrefixA) ?? AppSettings.defaultPrefixA,
        prefixB: _prefs.getString(kPrefixB) ?? AppSettings.defaultPrefixB,
        prefixC: _prefs.getString(kPrefixC) ?? AppSettings.defaultPrefixC,
        serialNumber:
            _prefs.getInt(kSerialNumber) ?? AppSettings.defaultSerialNumber,
        serialLength:
            _prefs.getInt(kSerialLength) ?? AppSettings.defaultSerialLength,
        continuousMode: _prefs.getBool(kContinuousMode) ?? false,
        offsetX: _prefs.getInt(kOffsetX) ?? 0,
        offsetY: _prefs.getInt(kOffsetY) ?? 0,
        labelWidthMm: _prefs.getDouble(kLabelWidthMm) ??
            AppSettings.defaultLabelWidthMm,
        labelHeightMm: _prefs.getDouble(kLabelHeightMm) ??
            AppSettings.defaultLabelHeightMm,
        labelDpi: _prefs.getInt(kLabelDpi) ?? AppSettings.defaultLabelDpi,
        fontSize: _prefs.getDouble(kFontSize) ?? AppSettings.defaultFontSize,
        density: _prefs.getInt(kDensity) ?? AppSettings.defaultDensity,
        lastDeviceId: _prefs.getString(kLastDeviceId) ?? '',
        lastDeviceName: _prefs.getString(kLastDeviceName) ?? '',
      );

  int get serialNumber =>
      _prefs.getInt(kSerialNumber) ?? AppSettings.defaultSerialNumber;

  /// 序号 +1（打印成功后调用）。
  Future<void> incrementSerial() => setSerialNumber(serialNumber + 1);

  Future<void> setSerialNumber(int value) =>
      _prefs.setInt(kSerialNumber, value);

  Future<void> setPrefixA(String value) => _prefs.setString(kPrefixA, value);
  Future<void> setPrefixB(String value) => _prefs.setString(kPrefixB, value);
  Future<void> setPrefixC(String value) => _prefs.setString(kPrefixC, value);

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
  Future<void> setDensity(int value) => _prefs.setInt(kDensity, value);

  Future<void> setLastDevice({required String id, required String name}) async {
    await _prefs.setString(kLastDeviceId, id);
    await _prefs.setString(kLastDeviceName, name);
  }

  /// 修改前缀并重置序号为 1（调用方需先做二次确认）。
  Future<void> changePrefix({String? a, String? b, String? c}) async {
    if (a != null) await setPrefixA(a);
    if (b != null) await setPrefixB(b);
    if (c != null) await setPrefixC(c);
    await setSerialNumber(AppSettings.defaultSerialNumber);
  }
}
