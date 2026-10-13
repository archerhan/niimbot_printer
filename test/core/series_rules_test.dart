import 'package:flutter_test/flutter_test.dart';
import 'package:printer/core/series_rules.dart';
import 'package:printer/models/product_series.dart';

void main() {
  const rules = SeriesRules();

  ProductSeries series({
    String id = 's1',
    String name = '',
    String a = 'ADM',
    String b = 'CTX',
    String c = '6O6',
    int serial = 1,
  }) {
    return ProductSeries(
      id: id,
      createdAt: 0,
      name: name,
      prefixA: a,
      prefixB: b,
      prefixC: c,
      serialNumber: serial,
    );
  }

  group('validate', () {
    test('正常系列通过', () {
      expect(rules.validate(series(), const <ProductSeries>[]), isNull);
    });

    test('三段前缀全为空时报错', () {
      final error = rules.validate(
        series(a: '', b: '', c: ''),
        const <ProductSeries>[],
      );
      expect(error, contains('至少填写一段'));
    });

    test('允许部分前缀为空', () {
      expect(
        rules.validate(series(b: '', c: ''), const <ProductSeries>[]),
        isNull,
      );
    });

    test('前缀含空格报错', () {
      expect(
        rules.validate(series(a: 'AD M'), const <ProductSeries>[]),
        contains('空格'),
      );
    });

    test('前缀含保留符号报错（# @ !）', () {
      for (final char in SeriesRules.forbiddenPrefixChars) {
        expect(
          rules.validate(series(a: 'ADM$char'), const <ProductSeries>[]),
          contains(char),
        );
      }
    });

    test('非空名称与其它系列重复时报错', () {
      final other = series(id: 's2', name: 'E系列');
      expect(
        rules.validate(series(id: 's1', name: 'e系列'), <ProductSeries>[other]),
        contains('已被其它系列使用'),
      );
    });

    test('空名称不算重名', () {
      final other = series(id: 's2', name: '');
      expect(
        rules.validate(series(id: 's1', name: ''), <ProductSeries>[other]),
        isNull,
      );
    });

    test('与自己同名不算重复', () {
      final self = series(id: 's1', name: 'E系列');
      expect(rules.validate(self, <ProductSeries>[self]), isNull);
    });

    test('序号越界报错', () {
      expect(
        rules.validate(series(serial: 0), const <ProductSeries>[]),
        contains('序号'),
      );
      expect(
        rules.validate(series(serial: 10000), const <ProductSeries>[]),
        contains('序号'),
      );
    });
  });

  group('conflictWarning', () {
    test('前缀拼接相同（忽略大小写）时提示', () {
      final other = series(id: 's2', a: 'ADMCTX', b: '6O6', c: '');
      final warning = rules.conflictWarning(
        series(id: 's1', a: 'admctx', b: '6o6', c: ''),
        <ProductSeries>[other],
      );
      expect(warning, isNotNull);
      expect(warning, contains('相同'));
    });

    test('前缀不同不提示', () {
      expect(
        rules.conflictWarning(
          series(id: 's1'),
          <ProductSeries>[series(id: 's2', a: 'ZZZ')],
        ),
        isNull,
      );
    });

    test('忽略自己', () {
      final self = series(id: 's1');
      expect(rules.conflictWarning(self, <ProductSeries>[self]), isNull);
    });
  });
}
