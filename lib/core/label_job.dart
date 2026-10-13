import '../models/app_settings.dart';
import '../models/product_series.dart';
import 'code_generator.dart';

/// 一次待打印任务的完整内容（不依赖打印机，便于单测）。
class LabelJob {
  const LabelJob({
    required this.accessoryCode,
    required this.serial,
    required this.productCode,
    required this.qrContent,
    required this.lines,
    this.seriesId = '',
    this.seriesName = '',
    this.isReprint = false,
    this.originalId,
  });

  final String accessoryCode;
  final int serial;
  final String productCode;
  final String qrContent;

  /// 标签上人眼可见的三行文字。
  final List<String> lines;

  /// 所属产品系列（写入历史用）。
  final String seriesId;
  final String seriesName;

  final bool isReprint;
  final int? originalId;

  /// 依据当前产品系列与配件编号生成一个打印任务。
  factory LabelJob.build({
    required ProductSeries series,
    required String accessoryCode,
    int serialLength = AppSettings.defaultSerialLength,
    CodeGenerator generator = const CodeGenerator(),
  }) {
    final productCode = generator.buildProductCode(
      prefixA: series.prefixA,
      prefixB: series.prefixB,
      prefixC: series.prefixC,
      serial: series.serialNumber,
      serialLength: serialLength,
    );
    final qrContent = generator.buildQrContent(
      productCode: productCode,
      accessoryCode: accessoryCode,
    );
    final lines = generator.buildLabelLines(
      prefixA: series.prefixA,
      prefixB: series.prefixB,
      prefixC: series.prefixC,
      serial: series.serialNumber,
      serialLength: serialLength,
    );
    return LabelJob(
      accessoryCode: accessoryCode,
      serial: series.serialNumber,
      productCode: productCode,
      qrContent: qrContent,
      lines: lines,
      seriesId: series.id,
      seriesName: series.displayName,
    );
  }

  /// 依据一条历史记录构造重打任务（不依赖系列是否还存在）。
  factory LabelJob.fromReused({
    required String accessoryCode,
    required String productCode,
    required int serial,
    required String qrContent,
    required List<String> lines,
    required int originalId,
    String seriesId = '',
    String seriesName = '',
  }) {
    return LabelJob(
      accessoryCode: accessoryCode,
      serial: serial,
      productCode: productCode,
      qrContent: qrContent,
      lines: lines,
      seriesId: seriesId,
      seriesName: seriesName,
      isReprint: true,
      originalId: originalId,
    );
  }
}
