import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/print_record.dart';
import 'package:printer/services/history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PrintRecord _record({
  required int serial,
  required String accessory,
  bool success = true,
  bool isReprint = false,
  int? originalId,
}) {
  return PrintRecord(
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + serial),
    productCode: 'ADM32672805CTX6O6${serial.toString().padLeft(4, '0')}',
    accessoryCode: accessory,
    serial: serial,
    qrContent: '!ADM32672805CTX6O6${serial.toString().padLeft(4, '0')}'
        '#MDE:$accessory@RESULT:OK',
    labelLines: <String>[
      'ADM32672805',
      'CTX',
      '6O6-${serial.toString().padLeft(4, '0')}',
    ],
    success: success,
    isReprint: isReprint,
    originalId: originalId,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  late HistoryRepository repo;

  setUp(() async {
    repo = await HistoryRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await repo.close();
  });

  test('insert 返回自增 id，count 正确', () async {
    final saved = await repo.insert(_record(serial: 1, accessory: 'A1'));
    expect(saved.id, 1);
    await repo.insert(_record(serial: 2, accessory: 'A2'));
    expect(await repo.count(), 2);
  });

  test('recent 按 id 倒序', () async {
    await repo.insert(_record(serial: 1, accessory: 'A1'));
    await repo.insert(_record(serial: 2, accessory: 'A2'));
    final list = await repo.recent();
    expect(list.first.accessoryCode, 'A2');
    expect(list.last.accessoryCode, 'A1');
  });

  test('lastSuccess 只取成功记录里最近一条', () async {
    await repo.insert(_record(serial: 1, accessory: 'A1'));
    await repo.insert(_record(serial: 2, accessory: 'A2', success: false));
    await repo.insert(_record(serial: 3, accessory: 'A3'));
    final last = await repo.lastSuccess();
    expect(last, isNotNull);
    expect(last!.serial, 3);
  });

  test('lastSuccess 无成功记录时返回 null', () async {
    await repo.insert(_record(serial: 1, accessory: 'A1', success: false));
    expect(await repo.lastSuccess(), isNull);
  });

  test('lastByAccessoryCode 命中最近一次', () async {
    await repo.insert(_record(serial: 1, accessory: 'DUP'));
    await repo.insert(_record(serial: 2, accessory: 'OTHER'));
    final hit = await repo.lastByAccessoryCode('DUP');
    expect(hit, isNotNull);
    expect(hit!.serial, 1);
    expect(await repo.lastByAccessoryCode('NONE'), isNull);
  });

  test('byId 取回详情', () async {
    final saved = await repo.insert(_record(serial: 1, accessory: 'A1'));
    final fetched = await repo.byId(saved.id!);
    expect(fetched, isNotNull);
    expect(fetched!.qrContent, contains('@RESULT:OK'));
  });

  test('重打记录能正确存取', () async {
    final original = await repo.insert(_record(serial: 1, accessory: 'A1'));
    final reprint = await repo.insert(
      _record(
        serial: 1,
        accessory: 'A1',
        isReprint: true,
        originalId: original.id,
      ),
    );
    expect(reprint.isReprint, isTrue);
    expect(reprint.originalId, original.id);
  });
}
