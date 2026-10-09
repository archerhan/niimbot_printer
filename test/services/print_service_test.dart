import 'package:flutter_test/flutter_test.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';
import 'package:printer/core/label_job.dart';
import 'package:printer/models/app_settings.dart';
import 'package:printer/services/history_repository.dart';
import 'package:printer/services/label_printer.dart';
import 'package:printer/services/print_service.dart';
import 'package:printer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePrinter implements LabelPrinter {
  bool fail = false;
  int printCount = 0;

  @override
  bool get isConnected => true;

  @override
  String? get deviceId => 'FAKE:01';

  @override
  Future<void> printPage(PrintPage page, {required int density}) async {
    printCount++;
    if (fail) {
      throw Exception('boom');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late SettingsService settings;
  late HistoryRepository history;
  late _FakePrinter printer;
  late PrintService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = SettingsService(await SharedPreferences.getInstance());
    history = await HistoryRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    printer = _FakePrinter();
    service = PrintService(
      settings: settings,
      history: history,
      printer: printer,
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
  });

  tearDown(() async {
    await history.close();
  });

  test('打印成功：写成功历史并递增序号', () async {
    final job = LabelJob.build(
      settings: settings.settings,
      accessoryCode: 'MDE62564302CDFL9D',
    );
    final outcome = await service.print(job);

    expect(outcome.success, isTrue);
    expect(printer.printCount, 1);
    expect(await history.count(), 1);
    expect(settings.serialNumber, 2);
    final record = (await history.recent()).first;
    expect(record.success, isTrue);
    expect(record.serial, 1);
    expect(record.deviceId, 'FAKE:01');
  });

  test('打印失败：写失败历史且序号不变', () async {
    printer.fail = true;
    final job = LabelJob.build(
      settings: settings.settings,
      accessoryCode: 'MDE62564302CDFL9D',
    );
    final outcome = await service.print(job);

    expect(outcome.success, isFalse);
    expect(outcome.error, isNotNull);
    expect(await history.count(), 1);
    expect(settings.serialNumber, 1);
    expect((await history.recent()).first.success, isFalse);
  });

  test('重打：序号不变且记录带重打标记', () async {
    final job = LabelJob.fromReused(
      accessoryCode: 'MDE1',
      productCode: 'ADM32672805CTX6O60005',
      serial: 5,
      qrContent: '!ADM32672805CTX6O60005#MDE:MDE1@RESULT:OK',
      lines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
      originalId: 3,
    );
    final outcome = await service.print(job);

    expect(outcome.success, isTrue);
    expect(settings.serialNumber, 1);
    final record = (await history.recent()).first;
    expect(record.isReprint, isTrue);
    expect(record.originalId, 3);
  });

  test('自定义初始序号生效', () async {
    await settings.setSerialNumber(7);
    final job = LabelJob.build(
      settings: settings.settings,
      accessoryCode: 'X',
    );
    expect(job.qrContent, contains('6O6'));
    expect(job.serial, 7);
    final outcome = await service.print(job);
    expect(outcome.success, isTrue);
    expect(settings.serialNumber, 8);
  });

  test('默认设置快照一致性', () async {
    expect(settings.settings.prefixA, AppSettings.defaultPrefixA);
  });
}
