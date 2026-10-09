import 'package:flutter_test/flutter_test.dart';
import 'package:printer/core/code_generator.dart';

void main() {
  const gen = CodeGenerator();

  group('formatSerial', () {
    test('左补零到 4 位', () {
      expect(gen.formatSerial(1), '0001');
      expect(gen.formatSerial(5), '0005');
      expect(gen.formatSerial(9999), '9999');
    });

    test('可自定义位数', () {
      expect(gen.formatSerial(5, 6), '000005');
      expect(gen.formatSerial(5, 1), '5');
    });

    test('超过位数不截断', () {
      expect(gen.formatSerial(10000), '10000');
    });
  });

  group('buildProductCode', () {
    test('按 A+B+C+序号 拼接', () {
      expect(
        gen.buildProductCode(
          prefixA: 'ADM32672805',
          prefixB: 'CTX',
          prefixC: '6O6',
          serial: 5,
        ),
        'ADM32672805CTX6O60005',
      );
    });

    test('序号从 0001 起', () {
      expect(
        gen.buildProductCode(
          prefixA: 'A',
          prefixB: 'B',
          prefixC: 'C',
          serial: 1,
        ),
        'ABC0001',
      );
    });
  });

  group('buildQrContent', () {
    test('按 !{产品编号}#MDE:{配件编号}@RESULT:OK 拼接', () {
      expect(
        gen.buildQrContent(
          productCode: 'ADM32672805CTX6O60005',
          accessoryCode: 'MDE62564302CDFL9D',
        ),
        '!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK',
      );
    });
  });

  group('buildQr', () {
    test('与文档给的样例完全一致', () {
      expect(
        gen.buildQr(
          prefixA: 'ADM32672805',
          prefixB: 'CTX',
          prefixC: '6O6',
          serial: 5,
          accessoryCode: 'MDE62564302CDFL9D',
        ),
        '!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK',
      );
    });
  });

  group('buildLabelLines', () {
    test('返回三行：A / B / C-序号', () {
      expect(
        gen.buildLabelLines(
          prefixA: 'ADM32672805',
          prefixB: 'CTX',
          prefixC: '6O6',
          serial: 6,
        ),
        <String>['ADM32672805', 'CTX', '6O6-0006'],
      );
    });
  });

  group('isSerialInRange', () {
    test('1~9999 合法', () {
      expect(gen.isSerialInRange(1), isTrue);
      expect(gen.isSerialInRange(9999), isTrue);
    });

    test('0 与 10000 非法', () {
      expect(gen.isSerialInRange(0), isFalse);
      expect(gen.isSerialInRange(10000), isFalse);
    });
  });
}
