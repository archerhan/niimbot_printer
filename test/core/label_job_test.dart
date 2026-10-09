import 'package:flutter_test/flutter_test.dart';
import 'package:printer/core/label_job.dart';
import 'package:printer/models/app_settings.dart';

void main() {
  test('依据默认设置构建任务', () {
    final job = LabelJob.build(
      settings: const AppSettings(),
      accessoryCode: 'MDE62564302CDFL9D',
    );
    expect(job.serial, 1);
    expect(job.productCode, 'ADM32672805CTX6O60001');
    expect(
      job.qrContent,
      '!ADM32672805CTX6O60001#MDE:MDE62564302CDFL9D@RESULT:OK',
    );
    expect(job.lines, <String>['ADM32672805', 'CTX', '6O6-0001']);
    expect(job.isReprint, isFalse);
  });

  test('依据自定义序号构建任务', () {
    final job = LabelJob.build(
      settings: const AppSettings(serialNumber: 42),
      accessoryCode: 'ABC',
    );
    expect(job.serial, 42);
    expect(job.productCode, 'ADM32672805CTX6O60042');
    expect(job.lines.last, '6O6-0042');
  });

  test('重打任务标记正确', () {
    final job = LabelJob.fromReused(
      accessoryCode: 'MDE1',
      productCode: 'ADM32672805CTX6O60005',
      serial: 5,
      qrContent: '!ADM32672805CTX6O60005#MDE:MDE1@RESULT:OK',
      lines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
      originalId: 7,
    );
    expect(job.isReprint, isTrue);
    expect(job.originalId, 7);
  });
}
