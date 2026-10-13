import 'package:flutter_test/flutter_test.dart';
import 'package:printer/core/label_job.dart';
import 'package:printer/models/product_series.dart';

void main() {
  test('依据产品系列构建任务', () {
    final job = LabelJob.build(
      series: ProductSeries.fallback,
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
    expect(job.seriesId, ProductSeries.fallback.id);
  });

  test('序号取自系列自身', () {
    const series = ProductSeries(
      id: 's2',
      createdAt: 1,
      name: '乙系列',
      prefixA: 'ADM',
      prefixB: 'CTX',
      prefixC: '6O6',
      serialNumber: 42,
    );
    final job = LabelJob.build(series: series, accessoryCode: 'ABC');
    expect(job.serial, 42);
    expect(job.productCode, 'ADMCTX6O60042');
    expect(job.lines.last, '6O6-0042');
    expect(job.seriesId, 's2');
    expect(job.seriesName, '乙系列');
  });

  test('名称为空时历史里记录前缀拼接作为系列名', () {
    const series = ProductSeries(
      id: 's3',
      createdAt: 1,
      prefixA: 'AAA',
      prefixB: 'BBB',
    );
    final job = LabelJob.build(series: series, accessoryCode: 'X');
    expect(job.seriesName, 'AAABBB');
  });

  test('前缀留空时对应行为空', () {
    const series = ProductSeries(
      id: 's4',
      createdAt: 1,
      prefixA: 'ADM',
      prefixB: '',
      prefixC: '',
    );
    final job = LabelJob.build(series: series, accessoryCode: 'X');
    expect(job.lines, <String>['ADM', '', '0001']);
  });

  test('重打任务标记正确', () {
    final job = LabelJob.fromReused(
      accessoryCode: 'MDE1',
      productCode: 'ADM32672805CTX6O60005',
      serial: 5,
      qrContent: '!ADM32672805CTX6O60005#MDE:MDE1@RESULT:OK',
      lines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
      originalId: 7,
      seriesId: 's9',
      seriesName: '九系列',
    );
    expect(job.isReprint, isTrue);
    expect(job.originalId, 7);
    expect(job.seriesId, 's9');
  });
}
