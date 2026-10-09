import 'dart:math' as math;
import 'dart:typed_data';

import 'package:niim_blue_flutter/niim_blue_flutter.dart';

/// 标签版式参数（单位：打印点 / pixel）。
///
/// 以 384×240 为设计基准，按纸张尺寸等比推导，
/// 实机标定后可在设置中微调偏移与字号。
class LabelLayout {
  const LabelLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.qrSize,
    required this.qrCenterX,
    required this.qrCenterY,
    required this.textLeft,
    required this.line1Y,
    required this.line2Y,
    required this.line3Y,
    required this.fontScale,
  });

  /// 设计基准尺寸。
  static const int baseWidth = 384;
  static const int baseHeight = 240;
  static const int baseFontSize = 24;

  /// 依据纸张尺寸按比例推导版式。
  factory LabelLayout.forSize(int pageWidth, int pageHeight) {
    final w = pageWidth;
    final h = pageHeight;
    final qrSize = math.min((h * 0.583).round(), (w * 0.40).round());
    return LabelLayout(
      pageWidth: w,
      pageHeight: h,
      qrSize: qrSize,
      qrCenterX: (w * 0.247).round(),
      qrCenterY: (h * 0.5).round(),
      textLeft: (w * 0.495).round(),
      line1Y: (h * 0.271).round(),
      line2Y: (h * 0.5).round(),
      line3Y: (h * 0.729).round(),
      fontScale: math.min(w / baseWidth, h / baseHeight),
    );
  }

  final int pageWidth;
  final int pageHeight;
  final int qrSize;
  final int qrCenterX;
  final int qrCenterY;
  final int textLeft;
  final int line1Y;
  final int line2Y;
  final int line3Y;

  /// 字号相对设计基准的缩放系数。
  final double fontScale;
}

/// 将二维码内容 + 三行文字渲染成打印页。
class LabelRenderer {
  const LabelRenderer();

  Future<PrintPage> buildPage({
    required String qrContent,
    required List<String> lines,
    int pageWidth = LabelLayout.baseWidth,
    int pageHeight = LabelLayout.baseHeight,
    int offsetX = 0,
    int offsetY = 0,
    int? fontSize,
  }) async {
    final layout = LabelLayout.forSize(pageWidth, pageHeight);
    final page = PrintPage(layout.pageWidth, layout.pageHeight);

    final baseFont =
        (fontSize ?? LabelLayout.baseFontSize) * layout.fontScale;

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
          fontSize: baseFont.round().clamp(6, 200),
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
