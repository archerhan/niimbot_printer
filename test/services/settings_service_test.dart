import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/product_series.dart';
import 'package:printer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = SettingsService(await SharedPreferences.getInstance());
  });

  test('未设置时返回默认系列与默认值', () {
    final s = service.settings;
    final series = s.currentSeries;
    expect(series.prefixA, 'ADM32672805');
    expect(series.prefixB, 'CTX');
    expect(series.prefixC, '6O6');
    expect(series.serialNumber, 1);
    expect(s.continuousMode, isFalse);
    expect(s.density, 3);
    expect(s.labelWidthMm, 40);
    expect(s.labelHeightMm, 20);
    expect(s.labelDpi, 300);
    // 40 × 20 mm @ 300dpi
    expect(s.labelWidthPx, 472);
    expect(s.labelHeightPx, 236);
  });

  test('迁移：老版本的全局前缀与序号转成一个系列', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'prefixA': 'AAA',
      'prefixB': 'BBB',
      'prefixC': 'CCC',
      'serialNumber': 9,
    });
    final migrated = SettingsService(await SharedPreferences.getInstance());
    await migrated.migrateIfNeeded();

    expect(migrated.seriesList.length, 1);
    final series = migrated.currentSeries;
    expect(series.prefixA, 'AAA');
    expect(series.prefixB, 'BBB');
    expect(series.prefixC, 'CCC');
    expect(series.serialNumber, 9);
  });

  test('迁移只执行一次，不覆盖已有系列', () async {
    await service.migrateIfNeeded();
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, prefixA: 'X'),
    );
    await service.migrateIfNeeded();
    expect(service.seriesList.length, 2);
  });

  test('新增系列：序号从 1 开始，且不影响当前系列', () async {
    await service.setCurrentSerial(7);
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, name: '乙系列', prefixA: 'X'),
    );

    expect(service.seriesList.length, 2);
    expect(service.currentSeries.serialNumber, 7);
    expect(service.seriesList.last.serialNumber, 1);
  });

  test('切换系列：各自序号互不干扰', () async {
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, prefixA: 'X'),
    );
    await service.incrementSerial(); // 默认系列 → 2
    await service.switchSeries('s2');

    expect(service.currentSeriesId, 's2');
    await service.incrementSerial(); // s2 → 2
    expect(service.currentSeries.serialNumber, 2);
    expect(service.seriesList.first.serialNumber, 2);
  });

  test('切回旧系列继续上次序号，不重置', () async {
    final firstId = service.currentSeriesId;
    await service.setCurrentSerial(5);
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, prefixA: 'X'),
    );
    await service.switchSeries('s2');
    await service.setCurrentSerial(3);

    await service.switchSeries(firstId);
    expect(service.currentSeries.serialNumber, 5);
  });

  test('更新系列只影响目标系列', () async {
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, prefixA: 'X'),
    );
    await service.updateSeries(
      const ProductSeries(id: 's2', createdAt: 1, name: '改名', prefixA: 'Y'),
    );
    expect(service.seriesList.last.name, '改名');
    expect(service.seriesList.last.prefixA, 'Y');
    expect(service.currentSeries.serialNumber, 1);
  });

  test('删除系列：列表移除', () async {
    await service.addSeries(
      const ProductSeries(id: 's2', createdAt: 1, prefixA: 'X'),
    );
    await service.deleteSeries('s2');
    expect(service.seriesList.length, 1);
    expect(service.seriesList.any((s) => s.id == 's2'), isFalse);
  });

  test('手动修正当前系列序号', () async {
    await service.setCurrentSerial(42);
    expect(service.currentSeries.serialNumber, 42);
  });

  test('可读写纸张尺寸与 DPI', () async {
    await service.setLabelWidthMm(40);
    await service.setLabelHeightMm(20);
    await service.setLabelDpi(203);
    expect(service.settings.labelDpi, 203);
    // 40mm @ 203dpi ≈ 320 像素
    expect(service.settings.labelWidthPx, 320);
  });

  test('设备信息可持久化', () async {
    await service.setLastDevice(id: 'AA:BB', name: 'Z401');
    expect(service.settings.lastDeviceId, 'AA:BB');
    expect(service.settings.lastDeviceName, 'Z401');
  });
}
