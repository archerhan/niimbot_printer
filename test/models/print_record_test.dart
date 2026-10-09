import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/print_record.dart';

void main() {
  final record = PrintRecord(
    id: 7,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    productCode: 'ADM32672805CTX6O60005',
    accessoryCode: 'MDE62564302CDFL9D',
    serial: 5,
    qrContent: '!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK',
    success: true,
    labelLines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
    isReprint: false,
    deviceId: 'AA:BB:CC',
  );

  test('toMap / fromMap 往返一致', () {
    final restored = PrintRecord.fromMap(record.toMap());
    expect(restored.id, 7);
    expect(restored.createdAt, record.createdAt);
    expect(restored.productCode, 'ADM32672805CTX6O60005');
    expect(restored.accessoryCode, 'MDE62564302CDFL9D');
    expect(restored.serial, 5);
    expect(restored.labelLines, <String>['ADM32672805', 'CTX', '6O6-0005']);
    expect(restored.success, isTrue);
    expect(restored.isReprint, isFalse);
    expect(restored.deviceId, 'AA:BB:CC');
  });

  test('失败记录成功位为 0', () {
    final failed = record.copyWith(success: false);
    expect(failed.toMap()['success'], 0);
    expect(PrintRecord.fromMap(failed.toMap()).success, isFalse);
  });

  test('重打记录带原记录关联', () {
    final reprint = record.copyWith(id: null, isReprint: true, originalId: 7);
    final map = reprint.toMap();
    expect(map['is_reprint'], 1);
    expect(map['original_id'], 7);
  });
}
