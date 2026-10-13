import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:printer/models/print_record.dart';
import 'package:printer/services/history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PrintRecord _record({
  required int serial,
  required String accessory,
  bool success = true,
  bool isReprint = false,
  int? originalId,
  String seriesId = 's1',
  String seriesName = '甲系列',
  int? createdAt,
}) {
  final padded = serial.toString().padLeft(4, '0');
  return PrintRecord(
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      createdAt ?? (1700000000000 + serial),
    ),
    productCode: 'ADM32672805CTX6O6$padded',
    accessoryCode: accessory,
    serial: serial,
    qrContent: '!ADM32672805CTX6O6$padded#MDE:$accessory@RESULT:OK',
    labelLines: <String>['ADM32672805', 'CTX', '6O6-$padded'],
    seriesId: seriesId,
    seriesName: seriesName,
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

  test('recent 按时间倒序', () async {
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

  test('lastSuccess 支持按系列过滤（跳号判断按系列）', () async {
    await repo.insert(_record(serial: 5, accessory: 'A1', seriesId: 's1'));
    await repo.insert(_record(serial: 1, accessory: 'B1', seriesId: 's2'));
    final s1 = await repo.lastSuccess(seriesId: 's1');
    final s2 = await repo.lastSuccess(seriesId: 's2');
    expect(s1!.serial, 5);
    expect(s2!.serial, 1);
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

  group('软删除', () {
    test('软删除后不出现在列表与计数中', () async {
      final a = await repo.insert(_record(serial: 1, accessory: 'A1'));
      await repo.insert(_record(serial: 2, accessory: 'A2'));

      await repo.softDelete(<int>[a.id!]);

      expect(await repo.count(), 1);
      expect((await repo.recent()).length, 1);
      expect((await repo.recent()).first.accessoryCode, 'A2');
    });

    test('软删除后仍参与跳号与重复码检测', () async {
      final a = await repo.insert(_record(serial: 7, accessory: 'DUP'));
      await repo.softDelete(<int>[a.id!]);

      expect((await repo.lastSuccess())!.serial, 7);
      expect((await repo.lastByAccessoryCode('DUP'))!.serial, 7);
      // 但列表里看不到
      expect(await repo.recent(), isEmpty);
    });

    test('空列表不报错', () async {
      expect(await repo.softDelete(<int>[]), 0);
    });
  });

  group('筛选与搜索', () {
    setUp(() async {
      // s1：2 月两条；s2：3 月一条
      await repo.insert(
        _record(
          serial: 1,
          accessory: 'A1',
          seriesId: 's1',
          seriesName: '甲系列',
          createdAt: DateTime(2026, 2, 10).millisecondsSinceEpoch,
        ),
      );
      await repo.insert(
        _record(
          serial: 12,
          accessory: 'A2',
          seriesId: 's1',
          seriesName: '甲系列',
          createdAt: DateTime(2026, 2, 20).millisecondsSinceEpoch,
        ),
      );
      await repo.insert(
        _record(
          serial: 3,
          accessory: 'B1',
          seriesId: 's2',
          seriesName: '乙系列',
          createdAt: DateTime(2026, 3, 5).millisecondsSinceEpoch,
        ),
      );
    });

    test('按系列筛选', () async {
      final list = await repo.search(seriesId: 's2');
      expect(list.length, 1);
      expect(list.first.seriesName, '乙系列');
    });

    test('按月份筛选', () async {
      final list = await repo.search(
        monthStart: DateTime(2026, 2, 1),
        monthEnd: DateTime(2026, 3, 1),
      );
      expect(list.length, 2);
      expect(list.every((r) => r.seriesId == 's1'), isTrue);
    });

    test('按产品编号模糊搜索（序号命中）', () async {
      final list = await repo.search(keyword: '0012');
      expect(list.length, 1);
      expect(list.first.serial, 12);
    });

    test('部分序号也能命中', () async {
      final list = await repo.search(keyword: '001');
      expect(list.length, 2); // 0001 与 0012
    });

    test('系列 + 月份 + 搜索 组合为 AND', () async {
      expect(
        (await repo.search(
          seriesId: 's1',
          monthStart: DateTime(2026, 2, 1),
          monthEnd: DateTime(2026, 3, 1),
          keyword: '0001',
        ))
            .length,
        1,
      );
      expect(
        (await repo.search(
          seriesId: 's2',
          monthStart: DateTime(2026, 2, 1),
          monthEnd: DateTime(2026, 3, 1),
        ))
            .length,
        0,
      );
    });

    test('countMatching 与筛选一致', () async {
      expect(await repo.countMatching(seriesId: 's1'), 2);
      expect(await repo.countMatching(keyword: '0012'), 1);
    });

    test('分页 offset/limit', () async {
      final firstPage = await repo.search(limit: 1, offset: 0);
      final secondPage = await repo.search(limit: 1, offset: 1);
      expect(firstPage.first.serial, 3);
      expect(secondPage.first.serial, 12);
    });

    test('seriesOptions 列出出现过的系列（去重，最近优先）', () async {
      final options = await repo.seriesOptions();
      expect(options.length, 2);
      expect(options.first.id, 's2');
      expect(options.first.name, '乙系列');
    });

    test('availableMonths 列出出现过的月份（倒序）', () async {
      expect(await repo.availableMonths(), <String>['2026-03', '2026-02']);
    });

    test('软删除的记录不参与筛选与下拉选项', () async {
      final list = await repo.search(keyword: '0012');
      await repo.softDelete(<int>[list.first.id!]);
      expect(await repo.search(keyword: '0012'), isEmpty);
      expect(await repo.countMatching(keyword: '0012'), 0);
    });
  });

  group('迁移', () {
    test('v1 升级到 v2 时保留数据并补齐新字段', () async {
      final dir = await Directory.systemTemp.createTemp('printer_db');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = p.join(dir.path, 'upgrade.db');

      // 手工建立 v1 表结构，模拟老版本安装（v1 没有 series_* / deleted 列）
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => db.execute('''
            CREATE TABLE ${HistoryRepository.table} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_at INTEGER NOT NULL,
              product_code TEXT NOT NULL,
              accessory_code TEXT NOT NULL,
              serial INTEGER NOT NULL,
              qr_content TEXT NOT NULL,
              label_lines TEXT NOT NULL DEFAULT '',
              success INTEGER NOT NULL DEFAULT 0,
              is_reprint INTEGER NOT NULL DEFAULT 0,
              original_id INTEGER,
              device_id TEXT
            )
          '''),
        ),
      );
      await v1.insert(HistoryRepository.table, <String, Object?>{
        'created_at': 1700000000000,
        'product_code': 'ADM32672805CTX6O60001',
        'accessory_code': 'A1',
        'serial': 1,
        'qr_content': '!ADM32672805CTX6O60001#MDE:A1@RESULT:OK',
        'label_lines': 'ADM32672805\nCTX\n6O6-0001',
        'success': 1,
        'is_reprint': 0,
        'original_id': null,
        'device_id': null,
      });
      await v1.close();

      final repoV2 = await HistoryRepository.open(
        factory: databaseFactoryFfi,
        path: path,
        version: 2,
      );
      expect(await repoV2.count(), 1);
      final record = (await repoV2.recent()).first;
      expect(record.accessoryCode, 'A1');
      // 新字段有默认值
      expect(record.seriesId, '');
      expect(record.deleted, isFalse);
      await repoV2.close();
    });
  });
}
