import '../core/code_generator.dart';
import '../core/label_job.dart';
import '../models/print_record.dart';
import 'history_repository.dart';
import 'label_printer.dart';
import 'label_renderer.dart';
import 'settings_service.dart';

/// 一次打印的结果。
class PrintOutcome {
  const PrintOutcome({
    required this.success,
    required this.record,
    this.error,
  });

  final bool success;
  final PrintRecord record;
  final Object? error;
}

/// 编排一次标签打印：渲染 → 打印 → 落库 → 递增序号。
///
/// - 打印成功且非重打：序号 +1，历史记成功。
/// - 打印失败：历史记失败，序号不变。
/// - 重打：序号不变，新增一条带 isReprint 标记的记录。
class PrintService {
  PrintService({
    required this.settings,
    required this.history,
    required this.printer,
    this.renderer = const LabelRenderer(),
    this.now,
  });

  final SettingsService settings;
  final HistoryRepository history;
  final LabelPrinter printer;
  final LabelRenderer renderer;

  /// 可注入的时间源，便于测试。
  final DateTime Function()? now;

  Future<PrintOutcome> print(LabelJob job) async {
    final s = settings.settings;
    final page = await renderer.buildPage(
      qrContent: job.qrContent,
      lines: job.lines,
      pageWidth: s.labelWidth,
      pageHeight: s.labelHeight,
      offsetX: s.offsetX,
      offsetY: s.offsetY,
      fontSize: s.fontSize.round(),
    );

    final createdAt = (now ?? DateTime.now)();
    final record = PrintRecord(
      createdAt: createdAt,
      productCode: job.productCode,
      accessoryCode: job.accessoryCode,
      serial: job.serial,
      qrContent: job.qrContent,
      success: false,
      labelLines: job.lines,
      isReprint: job.isReprint,
      originalId: job.originalId,
      deviceId: printer.deviceId,
    );

    try {
      await printer.printPage(page, density: s.density);
      final saved = await history.insert(record.copyWith(success: true));
      if (!job.isReprint) {
        await settings.incrementSerial();
      }
      return PrintOutcome(success: true, record: saved);
    } catch (error) {
      final saved = await history.insert(record);
      return PrintOutcome(success: false, record: saved, error: error);
    }
  }

  /// 依据设置生成二维码内容（供预览用）。
  String buildQrContent({required String accessoryCode}) {
    final job = LabelJob.build(
      settings: settings.settings,
      accessoryCode: accessoryCode,
      generator: const CodeGenerator(),
    );
    return job.qrContent;
  }
}
