import '../models/app_settings.dart';
import 'code_generator.dart';

/// 一次待打印任务的完整内容（不依赖打印机，便于单测）。
class LabelJob {
  const LabelJob({
    required this.accessoryCode,
    required this.serial,
    required this.productCode,
    required this.qrContent,
    required this.lines,
    this.isReprint = false,
    this.originalId,
  });

  final String accessoryCode;
  final int serial;
  final String productCode;
  final String qrContent;

  /// 标签上人眼可见的三行文字。
  final List<String> lines;

  final bool isReprint;
  final int? originalId;

  /// 依据设置与配件编号生成一个打印任务。
  factory LabelJob.build({
    required AppSettings settings,
    required String accessoryCode,
    CodeGenerator generator = const CodeGenerator(),
    bool isReprint = false,
    int? originalId,
  }) {
    final productCode = generator.buildProductCode(
      prefixA: settings.prefixA,
      prefixB: settings.prefixB,
      prefixC: settings.prefixC,
      serial: settings.serialNumber,
      serialLength: settings.serialLength,
    );
    final qrContent = generator.buildQrContent(
      productCode: productCode,
      accessoryCode: accessoryCode,
    );
    final lines = generator.buildLabelLines(
      prefixA: settings.prefixA,
      prefixB: settings.prefixB,
      prefixC: settings.prefixC,
      serial: settings.serialNumber,
      serialLength: settings.serialLength,
    );
    return LabelJob(
      accessoryCode: accessoryCode,
      serial: settings.serialNumber,
      productCode: productCode,
      qrContent: qrContent,
      lines: lines,
      isReprint: isReprint,
      originalId: originalId,
    );
  }

  /// 依据一条历史记录构造重打任务。
  factory LabelJob.fromReused({
    required String accessoryCode,
    required String productCode,
    required int serial,
    required String qrContent,
    required List<String> lines,
    required int originalId,
  }) {
    return LabelJob(
      accessoryCode: accessoryCode,
      serial: serial,
      productCode: productCode,
      qrContent: qrContent,
      lines: lines,
      isReprint: true,
      originalId: originalId,
    );
  }
}
