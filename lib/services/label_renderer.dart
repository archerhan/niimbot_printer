import 'dart:typed_data';

import 'package:niim_blue_flutter/niim_blue_flutter.dart';

/// 标签版式参数（单位：打印点 / pixel）。
///
/// 默认值依据 B1（384 点宽、203 dpi）与实物照片比例估算，
/// 实机标定后可在设置中微调。
class LabelLayout {
  const LabelLayout({
    this.pageWidth = 384,
    this.pageHeight = 240,
    this.qrSize = 140,
    this.qrCenterX = 95,
    this.qrCenterY = 120,
    this.textLeft = 190,
    this.line1Y = 65,
    this.line2Y = 120,
    this.line3Y = 175,
    this.fontSize = 24,
  });

  final int pageWidth;
  final int pageHeight;
  final int qrSize;
  final int qrCenterX;
  final int qrCenterY;
  final int textLeft;
  final int line1Y;
  final int line2Y;
  final int line3Y;
  final int fontSize;
}

/// 将二维码内容 + 三行文字渲染成打印页。
class LabelRenderer {
  const LabelRenderer();

  Future<PrintPage> buildPage({
    required String qrContent,
    required List<String> lines,
    LabelLayout layout = const LabelLayout(),
    int offsetX = 0,
    int offsetY = 0,
    int? fontSize,
  }) async {
    final page = PrintPage(layout.pageWidth, layout.pageHeight);

    page.addQR(
      qrContent,
      QROptions(
        x: layout.qrCenterX + offsetX,
        y: layout.qrCenterY + offsetY,
        width: layout.qrSize,
        height: layout.qrSize,
        align: HAlignment.center,
        vAlign: VAlignment.middle,
        ecl: QRErrorCorrection.medium,
      ),
    );

    final ys = <int>[layout.line1Y, layout.line2Y, layout.line3Y];
    for (var i = 0; i < lines.length && i < ys.length; i++) {
      await page.addText(
        lines[i],
        TextOptions(
          x: layout.textLeft + offsetX,
          y: ys[i] + offsetY,
          fontSize: fontSize ?? layout.fontSize,
          align: HAlignment.left,
          vAlign: VAlignment.middle,
        ),
      );
    }

    return page;
  }

  /// 生成预览 PNG（用于打印前确认）。
  Future<Uint8List> preview(PrintPage page) => page.toPreviewImage();
}
