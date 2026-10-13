import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

/// 标签版式（单位：打印点 / pixel）。
///
/// 排版规则（自动适配纸张，无需人工换算）：
/// - 「二维码 + 文字块」作为整体在纸张内居中；
/// - 四周保留边距，二维码与文字之间保留间距，不会紧贴边缘；
/// - 字号先收敛到可容纳范围（每行完整放下、不折行、不超界），
///   二维码尺寸随后收敛（不挤占文字、不超出纸张）；
/// - 用户设置的 X/Y 偏移在居中之后应用，用于现场微调。
class LabelLayout {
  const LabelLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.qrSize,
    required this.qrLeft,
    required this.qrTop,
    required this.textLeft,
    required this.lineCenters,
    required this.fontSize,
    required this.lineHeight,
    required this.textWidth,
    required this.margin,
    required this.gap,
  });

  /// 设计基准尺寸：字号以 384×240 为基准随纸张等比缩放。
  static const int baseWidth = 384;
  static const int baseHeight = 240;
  static const int baseFontSize = 30;

  /// 边距/间距：按纸张短边比例，保证内容不贴边。
  static const double marginRatio = 0.06;

  /// 二维码最小边长：按纸张短边比例。
  static const double qrMinRatio = 0.15;

  /// 行间距相对行高的倍数。
  static const double lineSpacingFactor = 1.5;

  final int pageWidth;
  final int pageHeight;

  /// 实际使用的二维码边长（已限制）。
  final int qrSize;
  final int qrLeft;
  final int qrTop;

  /// 文字块左边界；各行垂直中心见 [lineCenters]。
  final int textLeft;
  final List<int> lineCenters;

  /// 实际使用的字号（已限制）。
  final int fontSize;
  final int lineHeight;
  final int textWidth;

  final int margin;
  final int gap;

  /// 依据纸张与内容计算版式。
  ///
  /// [requestedFontSize] 为设置中的字号（未乘纸张缩放）；
  /// [requestedQrSize] 为设置中的二维码边长（像素）；二者都会被限制在可容纳范围内。
  static LabelLayout compute({
    int pageWidth = baseWidth,
    int pageHeight = baseHeight,
    List<String> lines = const <String>[],
    int? requestedFontSize,
    int? requestedQrSize,
    int offsetX = 0,
    int offsetY = 0,
  }) {
    final w = pageWidth;
    final h = pageHeight;
    final minSide = math.min(w, h);

    final margin = math.max(3, (minSide * marginRatio).round());
    final gap = margin;
    final qrMin = math.max(16, (minSide * qrMinRatio).round());
    final fontScale = math.min(w / baseWidth, h / baseHeight);

    // ---- 1. 字号：向下收敛，保证「每行完整放下 + 给二维码留最小空间 + 不超高」----
    var fontSize = ((requestedFontSize ?? baseFontSize) * fontScale).round();
    const minFontSize = 6;
    final fontHardCap = math.max(
      minFontSize,
      math.min(h - 2 * margin, w - 2 * margin),
    );
    fontSize = fontSize.clamp(minFontSize, fontHardCap);

    int textWidthOf(int size) => lines.isEmpty
        ? 0
        : lines
              .map((line) => _measure(line, size).width.ceil())
              .reduce(math.max);
    int lineHeightOf(int size) =>
        lines.isEmpty ? 0 : _measure(lines.first, size).height.ceil();
    int lineSpacingOf(int size) =>
        (lineHeightOf(size) * lineSpacingFactor).round();
    int blockHeightOf(int size) => lines.isEmpty
        ? 0
        : lineHeightOf(size) + lineSpacingOf(size) * (lines.length - 1);

    while (fontSize > minFontSize) {
      final fitsWidth = textWidthOf(fontSize) <= w - 2 * margin - gap - qrMin;
      final fitsHeight = blockHeightOf(fontSize) <= h - 2 * margin;
      if (fitsWidth && fitsHeight) break;
      fontSize -= 1;
    }

    final textW = textWidthOf(fontSize);
    final lineH = lineHeightOf(fontSize);
    final blockH = blockHeightOf(fontSize);

    // ---- 2. 二维码尺寸：不超出纸张、不挤占文字 ----
    final qrMaxWidth = w - 2 * margin - gap - textW;
    final qrMaxHeight = h - 2 * margin;
    final qrUpper = math.max(qrMin, math.min(qrMaxWidth, qrMaxHeight));
    final qrDefault = math.min((h * 0.583).round(), (w * 0.40).round());
    // 取偶数边长，居中取整更精确。
    final qrSize = (requestedQrSize ?? qrDefault).clamp(qrMin, qrUpper) & ~1;

    // ---- 3. 整体居中，再应用用户偏移 ----
    final contentW = qrSize + (textW > 0 ? gap + textW : 0);
    final contentH = math.max(qrSize, blockH);
    final left = ((w - contentW) / 2).round() + offsetX;
    final top = ((h - contentH) / 2).round() + offsetY;

    final qrLeft = left;
    final qrTop = top + ((contentH - qrSize) / 2).round();
    final textLeft = left + qrSize + gap;
    final firstCenter = top + ((contentH - blockH) / 2).round() + lineH ~/ 2;
    final spacing = lineSpacingOf(fontSize);
    final centers = <int>[
      for (var i = 0; i < lines.length; i++) firstCenter + i * spacing,
    ];

    return LabelLayout(
      pageWidth: w,
      pageHeight: h,
      qrSize: qrSize,
      qrLeft: qrLeft,
      qrTop: qrTop,
      textLeft: textLeft,
      lineCenters: centers,
      fontSize: fontSize,
      lineHeight: lineH,
      textWidth: textW,
      margin: margin,
      gap: gap,
    );
  }

  /// 使用与 PrintPage.addText 相同的样式测量文本，保证排版位置与实际绘制一致。
  static TextPainter _measure(String text, int fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize.toDouble()),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }
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
    int? qrSize,
  }) async {
    final layout = LabelLayout.compute(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      lines: lines,
      requestedFontSize: fontSize,
      requestedQrSize: qrSize,
      offsetX: offsetX,
      offsetY: offsetY,
    );
    final page = PrintPage(layout.pageWidth, layout.pageHeight);

    page.addQR(
      qrContent,
      QROptions(
        x: layout.qrLeft + layout.qrSize ~/ 2,
        y: layout.qrTop + layout.qrSize ~/ 2,
        width: layout.qrSize,
        height: layout.qrSize,
        align: HAlignment.center,
        vAlign: VAlignment.middle,
        ecl: QRErrorCorrection.medium,
      ),
    );

    for (var i = 0; i < lines.length && i < layout.lineCenters.length; i++) {
      // 前缀为空的行跳过绘制（保留该行位置留白，不影响其它行）。
      if (lines[i].isEmpty) continue;
      await page.addText(
        lines[i],
        TextOptions(
          x: layout.textLeft,
          y: layout.lineCenters[i],
          fontSize: layout.fontSize,
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
