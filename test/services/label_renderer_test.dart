import 'package:flutter_test/flutter_test.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';
import 'package:printer/services/label_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const renderer = LabelRenderer();
  const lines = <String>['ADM32672805', 'CTX', '6O6-0001'];
  const qr = '!ADM32672805CTX6O60001#MDE:MDE62564302CDFL9D@RESULT:OK';

  ({int left, int top, int right, int bottom}) darkBounds(PrintPage page) {
    var left = page.width;
    var top = page.height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < page.height; y++) {
      for (var x = 0; x < page.width; x++) {
        if (page.pixels[y][x] == 1) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    return (left: left, top: top, right: right, bottom: bottom);
  }

  test('默认页面尺寸为 384 x 240', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: lines,
    );
    expect(page.width, 384);
    expect(page.height, 240);
    expect(page.pixels.length, 240);
    expect(page.pixels.first.length, 384);
  });

  test('渲染后存在黑色像素（二维码与文字被绘制）', () async {
    final page = await renderer.buildPage(qrContent: qr, lines: lines);
    final black = page.pixels
        .expand((row) => row)
        .where((pixel) => pixel == 1)
        .length;
    expect(black, greaterThan(100));
  });

  test('可生成预览 PNG', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: lines,
    );
    final png = await renderer.preview(page);
    expect(png.length, greaterThan(0));
    // PNG magic number
    expect(png.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });

  test('内容整体居中：四周留白基本对称', () async {
    final page = await renderer.buildPage(qrContent: qr, lines: lines);
    final bounds = darkBounds(page);

    final leftGap = bounds.left;
    final rightGap = page.width - 1 - bounds.right;
    final topGap = bounds.top;
    final bottomGap = page.height - 1 - bounds.bottom;

    expect(
      (leftGap - rightGap).abs(),
      lessThanOrEqualTo(4),
      reason: 'left=$leftGap right=$rightGap',
    );
    expect(
      (topGap - bottomGap).abs(),
      lessThanOrEqualTo(6),
      reason: 'top=$topGap bottom=$bottomGap',
    );
    // 内容不贴边
    expect(leftGap, greaterThan(0));
    expect(topGap, greaterThan(0));
  });

  test('X/Y 偏移整体平移内容', () async {
    final base = await renderer.buildPage(qrContent: qr, lines: lines);
    final moved = await renderer.buildPage(
      qrContent: qr,
      lines: lines,
      offsetX: 6,
      offsetY: 6,
    );
    final b0 = darkBounds(base);
    final b1 = darkBounds(moved);
    expect((b1.left - b0.left - 6).abs(), lessThanOrEqualTo(1));
    expect((b1.top - b0.top - 6).abs(), lessThanOrEqualTo(1));
  });

  test('字号越大渲染出的黑色像素越多', () async {
    final small = await renderer.buildPage(
      qrContent: 'X',
      lines: lines,
      fontSize: 12,
    );
    final large = await renderer.buildPage(
      qrContent: 'X',
      lines: lines,
      fontSize: 28,
    );
    final smallBlack = small.pixels
        .expand((row) => row)
        .where((p) => p == 1)
        .length;
    final largeBlack = large.pixels
        .expand((row) => row)
        .where((p) => p == 1)
        .length;
    expect(largeBlack, greaterThan(smallBlack));
  });

  test('自定义纸张尺寸生效', () async {
    final page = await renderer.buildPage(
      qrContent: '!TEST@RESULT:OK',
      lines: lines,
      pageWidth: 384,
      pageHeight: 320,
    );
    expect(page.width, 384);
    expect(page.height, 320);
    expect(page.pixels.length, 320);
  });

  group('LabelLayout.compute', () {
    test('默认 384×240：内容不超出纸张并留有边距', () {
      final layout = LabelLayout.compute(lines: lines);

      expect(layout.qrSize % 2, 0, reason: '二维码边长取偶数');
      expect(layout.qrLeft, greaterThanOrEqualTo(layout.margin - 1));
      expect(
        layout.textLeft + layout.textWidth,
        lessThanOrEqualTo(384 - layout.margin),
      );
      expect(
        layout.lineCenters.last + layout.lineHeight ~/ 2,
        lessThanOrEqualTo(240 - layout.margin),
      );
    });

    test('字号过大自动缩小到可容纳范围', () {
      final layout = LabelLayout.compute(lines: lines, requestedFontSize: 300);

      expect(layout.fontSize, lessThan(300));
      expect(layout.fontSize, greaterThanOrEqualTo(6));
      // 每行完整放下（不超出纸张右侧边距）
      expect(
        layout.textLeft + layout.textWidth,
        lessThanOrEqualTo(384 - layout.margin),
      );
      // 三行完整放下（不超出纸张下边距）
      expect(
        layout.lineCenters.last + layout.lineHeight ~/ 2,
        lessThanOrEqualTo(240 - layout.margin),
      );
    });

    test('二维码过大自动限制：不超出纸张、不挤占文字', () {
      final layout = LabelLayout.compute(lines: lines, requestedQrSize: 1000);

      expect(layout.qrSize, lessThanOrEqualTo(240 - 2 * layout.margin));
      expect(
        layout.qrLeft + layout.qrSize + layout.gap + layout.textWidth,
        lessThanOrEqualTo(384 - layout.margin),
      );
    });

    test('二维码过小被抬高到最小值', () {
      final layout = LabelLayout.compute(lines: lines, requestedQrSize: 4);

      expect(layout.qrSize, greaterThanOrEqualTo(16));
    });

    test('无偏移时内容整体居中', () {
      final layout = LabelLayout.compute(lines: lines);

      final leftSpace = layout.qrLeft;
      final rightSpace = 384 - (layout.textLeft + layout.textWidth);
      expect((leftSpace - rightSpace).abs(), lessThanOrEqualTo(2));
    });
  });
}
