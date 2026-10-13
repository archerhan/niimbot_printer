import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/product_series.dart';

void main() {
  test('productPrefix 拼接三段前缀', () {
    const series = ProductSeries(
      id: 's1',
      createdAt: 0,
      prefixA: 'ADM',
      prefixB: 'CTX',
      prefixC: '6O6',
    );
    expect(series.productPrefix, 'ADMCTX6O6');
  });

  test('displayName：有名用名，无名用前缀拼接', () {
    const named = ProductSeries(
      id: 's1',
      createdAt: 0,
      name: '  E系列  ',
      prefixA: 'ADM',
    );
    expect(named.displayName, 'E系列');

    const unnamed = ProductSeries(
      id: 's2',
      createdAt: 0,
      prefixA: 'ADM',
      prefixC: '6O6',
    );
    expect(unnamed.displayName, 'ADM6O6');
  });

  test('displayName：无名且无前缀时给出占位', () {
    const empty = ProductSeries(id: 's3', createdAt: 0);
    expect(empty.displayName, '（未命名系列）');
  });

  test('toJson / fromJson 往返一致', () {
    const series = ProductSeries(
      id: 's1',
      createdAt: 123,
      name: 'E系列',
      prefixA: 'A',
      prefixB: 'B',
      prefixC: 'C',
      serialNumber: 9,
    );
    final restored = ProductSeries.fromJson(series.toJson());
    expect(restored.id, 's1');
    expect(restored.createdAt, 123);
    expect(restored.name, 'E系列');
    expect(restored.prefixB, 'B');
    expect(restored.serialNumber, 9);
  });

  test('copyWith 保留 id 与创建时间', () {
    const series = ProductSeries(id: 's1', createdAt: 5, serialNumber: 3);
    final updated = series.copyWith(prefixA: 'X', serialNumber: 4);
    expect(updated.id, 's1');
    expect(updated.createdAt, 5);
    expect(updated.prefixA, 'X');
    expect(updated.serialNumber, 4);
  });
}
