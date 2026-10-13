import 'package:flutter_test/flutter_test.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';
import 'package:printer/models/app_settings.dart';
import 'package:printer/services/label_printer.dart';

void main() {
  group('resolvePrintTask', () {
    test('手动指定优先于自动识别结果', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.b1,
        detected: PrintTaskName.d110,
        protocolVersion: 5,
        model: PrinterModel.b1,
      );
      expect(result.task, PrintTaskName.b1);
      expect(result.reason, '手动指定');
    });

    test('自动模式优先使用库的自动识别结果', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: PrintTaskName.d110,
        protocolVersion: 1,
        model: PrinterModel.d110,
      );
      expect(result.task, PrintTaskName.d110);
      expect(result.reason, '自动识别');
    });

    test('未识别且协议版本 ≥ 4 → D110M_V4（与 niimbluelib 一致）', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: null,
        protocolVersion: 4,
        model: null,
      );
      expect(result.task, PrintTaskName.d110mV4);
      expect(result.reason, contains('协议版本'));
    });

    test('Z401（未识别、协议版本 0）→ 兜底 B1', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: null,
        protocolVersion: 0,
        model: PrinterModel.z401,
      );
      expect(result.task, PrintTaskName.b1);
      expect(result.reason, contains('兜底'));
    });

    test('B3S 使用社区验证的 B1 兜底', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: null,
        protocolVersion: 0,
        model: PrinterModel.b3s,
      );
      expect(result.task, PrintTaskName.b1);
      expect(result.reason, contains('社区验证'));
    });

    test('B3S_P 同样使用 B1 兜底', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: null,
        protocolVersion: 3,
        model: PrinterModel.b3sP,
      );
      expect(result.task, PrintTaskName.b1);
    });

    test('协议版本缺失时未识别 → 兜底 B1', () {
      final result = resolvePrintTask(
        preference: PrinterTaskPreference.auto,
        detected: null,
        protocolVersion: null,
        model: null,
      );
      expect(result.task, PrintTaskName.b1);
    });
  });

  test('printTaskLabel 输出任务名', () {
    expect(printTaskLabel(PrintTaskName.b1), 'B1');
    expect(printTaskLabel(PrintTaskName.d110mV4), 'D110M_V4');
    expect(printTaskLabel(PrintTaskName.d110), 'D110');
    expect(printTaskLabel(PrintTaskName.b21V1), 'B21_V1');
    expect(printTaskLabel(PrintTaskName.d11V1), 'D11_V1');
  });

  test('describePrinterError 转换为中文描述', () {
    expect(describePrinterError(PrintError('No paper', 0x02)), contains('缺纸'));
    expect(describePrinterError(PrintError('Cover', 0x01)), contains('盖子未关闭'));
    // 未知错误码回退英文描述 + 十六进制
    expect(describePrinterError(PrintError('Unknown', 0x77)), contains('0x77'));
    expect(describePrinterError(Exception('boom')), contains('boom'));
  });
}
