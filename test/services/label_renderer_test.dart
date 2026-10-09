import 'package:flutter_test/flutter_test.dart';
import 'package:printer/services/label_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const renderer = LabelRenderer();

  test('默认页面尺寸为 384 x 240', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: <String>['ADM32672805', 'CTX', '6O6-0001'],
    );
    expect(page.width, 384);
    expect(page.height, 240);
    expect(page.pixels.length, 240);
    expect(page.pixels.first.length, 384);
  });

  test('渲染后存在黑色像素（二维码与文字被绘制）', () async {
    final page = await renderer.buildPage(
      qrContent: '!ADM32672805CTX6O60001#MDE:MDE62564302CDFL9D@RESULT:OK',
      lines: <String>['ADM32672805', 'CTX', '6O6-0001'],
    );
    final black = page.pixels
        .expand((row) => row)
        .where((pixel) => pixel == 1)
        .length;
    expect(black, greaterThan(100));
  });

  test('可生成预览 PNG', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: <String>['ADM32672805', 'CTX', '6O6-0001'],
    );
    final png = await renderer.preview(page);
    expect(png.length, greaterThan(0));
    // PNG magic number
    expect(png.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });

  test('偏移会影响页面尺寸外的内容但仍可渲染', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: <String>['A', 'B', 'C-0001'],
      offsetX: 5,
      offsetY: 5,
      fontSize: 18,
    );
    expect(page.width, 384);
    expect(page.height, 240);
  });
}
