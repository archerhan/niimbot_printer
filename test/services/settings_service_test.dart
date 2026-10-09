import 'package:flutter_test/flutter_test.dart';
import 'package:printer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = SettingsService(await SharedPreferences.getInstance());
  });

  test('未设置时返回默认值', () {
    final s = service.settings;
    expect(s.prefixA, 'ADM32672805');
    expect(s.prefixB, 'CTX');
    expect(s.prefixC, '6O6');
    expect(s.serialNumber, 1);
    expect(s.continuousMode, isFalse);
    expect(s.density, 3);
  });

  test('可读写前缀与序号', () async {
    await service.setPrefixA('XXX');
    await service.setSerialNumber(42);
    expect(service.settings.prefixA, 'XXX');
    expect(service.serialNumber, 42);
  });

  test('incrementSerial 递增', () async {
    await service.setSerialNumber(5);
    await service.incrementSerial();
    expect(service.serialNumber, 6);
  });

  test('changePrefix 会重置序号为 1', () async {
    await service.setSerialNumber(99);
    await service.changePrefix(b: 'NEW');
    expect(service.settings.prefixB, 'NEW');
    expect(service.serialNumber, 1);
  });

  test('设备信息可持久化', () async {
    await service.setLastDevice(id: 'AA:BB', name: 'B1');
    expect(service.settings.lastDeviceId, 'AA:BB');
    expect(service.settings.lastDeviceName, 'B1');
  });
}
