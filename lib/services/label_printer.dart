import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';
// niim_blue_flutter 1.0.1 未导出 print_task_factory，这里需要 PrintTaskName 做兜底。
// ignore: implementation_imports
import 'package:niim_blue_flutter/src/print_tasks/print_task_factory.dart'
    show PrintTaskName;

import '../core/log.dart';
import '../models/app_settings.dart';

// 便于测试与其他模块引用 PrintTaskName，避免重复使用 implementation import。
// ignore: implementation_imports
export 'package:niim_blue_flutter/src/print_tasks/print_task_factory.dart'
    show PrintTaskName;

/// 打印机抽象，便于在单测中注入假实现。
abstract class LabelPrinter {
  bool get isConnected;
  String? get deviceId;

  /// 打印一页标签；失败时抛异常。
  Future<void> printPage(
    PrintPage page, {
    required int density,
    PrinterTaskPreference taskPreference = PrinterTaskPreference.auto,
  });
}

/// 打印任务显示名。
String printTaskLabel(PrintTaskName name) => switch (name) {
  PrintTaskName.b1 => 'B1',
  PrintTaskName.d110mV4 => 'D110M_V4',
  PrintTaskName.d110 => 'D110',
  PrintTaskName.b21V1 => 'B21_V1',
  PrintTaskName.d11V1 => 'D11_V1',
};

/// niim_blue_flutter 的映射表缺失、但有社区真机验证结论的型号兜底。
///
/// - B3S / B3S_P：flutter-niimblue-lib issue #3 的修复方案与 Thermalith 项目
///   的真机验证（2026-07-30，B3S_P id 272）均确认使用 B1 打印任务。
const Map<PrinterModel, PrintTaskName> knownMissingModelTasks = {
  PrinterModel.b3s: PrintTaskName.b1,
  PrinterModel.b3sP: PrintTaskName.b1,
};

/// 解析实际使用的打印任务。
///
/// 顺序：
/// 1. 用户手动指定（设置页「打印任务」）；
/// 2. 库自动识别结果；
/// 3. 已知缺失型号的社区兜底（[knownMissingModelTasks]）；
/// 4. 协议版本 ≥ 4 → D110M_V4（与 niimbluelib 参考实现一致）；
/// 5. 其余未识别型号 → B1（与 niimblue 网页版默认值、Thermalith 默认值一致）。
({PrintTaskName task, String reason}) resolvePrintTask({
  required PrinterTaskPreference preference,
  required PrintTaskName? detected,
  required int? protocolVersion,
  PrinterModel? model,
}) {
  switch (preference) {
    case PrinterTaskPreference.auto:
      break;
    case PrinterTaskPreference.b1:
      return (task: PrintTaskName.b1, reason: '手动指定');
    case PrinterTaskPreference.d110mV4:
      return (task: PrintTaskName.d110mV4, reason: '手动指定');
    case PrinterTaskPreference.d110:
      return (task: PrintTaskName.d110, reason: '手动指定');
    case PrinterTaskPreference.b21V1:
      return (task: PrintTaskName.b21V1, reason: '手动指定');
    case PrinterTaskPreference.d11V1:
      return (task: PrintTaskName.d11V1, reason: '手动指定');
  }

  if (detected != null) {
    return (task: detected, reason: '自动识别');
  }

  final knownFallback = model == null ? null : knownMissingModelTasks[model];
  if (knownFallback != null) {
    return (
      task: knownFallback,
      reason: '兜底：${model!.value} 使用 ${printTaskLabel(knownFallback)}（社区验证）',
    );
  }

  if ((protocolVersion ?? 0) >= 4) {
    return (task: PrintTaskName.d110mV4, reason: '兜底：协议版本 ≥ 4 → D110M_V4');
  }
  return (task: PrintTaskName.b1, reason: '兜底：未识别型号默认 B1');
}

/// 把打印异常转换为便于现场排查的中文描述。
String describePrinterError(Object? error) {
  if (error is PrintError) {
    final code = error.reasonId;
    final name = PrinterErrorCode.fromValue(code);
    final hex = '0x${code.toRadixString(16).padLeft(2, '0')}';
    return '打印机返回错误：${_printerErrorZh(code) ?? name?.description ?? '未知错误'}（$hex）';
  }
  return '$error';
}

String? _printerErrorZh(int code) => switch (code) {
  0x01 => '盖子未关闭',
  0x02 => '缺纸',
  0x03 => '电量低',
  0x04 => '电池异常',
  0x05 => '打印被取消',
  0x06 => '数据错误',
  0x07 => '打印头过热',
  0x08 => '出纸异常',
  0x09 => '打印机忙',
  0x0a => '未检测到打印头',
  0x0b => '温度过低',
  0x0c => '打印头松动',
  0x0d => '缺少碳带（热转印机型）',
  0x0e => '碳带不匹配',
  0x0f => '碳带已用完',
  0x10 => '纸张不匹配',
  0x1b => '出纸异常（B3S）',
  0x1c => '请检查纸张',
  0x1d => 'RFID 标签未写入',
  0x1e => '该机型不支持设置浓度',
  0x1f => '该机型不支持设置打印模式',
  0x32 => '页码非法',
  0x33 => '碳带页非法',
  0x34 => '接收数据超时（可重试）',
  0x35 => '非专用碳带',
  _ => null,
};

/// 打印机诊断快照（设置页展示 / 排查用）。
class PrinterDiagnostics {
  const PrinterDiagnostics({
    required this.connected,
    required this.deviceName,
    required this.modelId,
    required this.modelName,
    required this.dpi,
    required this.printheadPixels,
    required this.protocolVersion,
    required this.connectResult,
    required this.softwareVersion,
    required this.hardwareVersion,
    required this.serial,
    required this.detectedTask,
    required this.resolvedTask,
    required this.resolvedReason,
  });

  final bool connected;
  final String? deviceName;
  final int? modelId;
  final String? modelName;
  final int? dpi;
  final int? printheadPixels;
  final int? protocolVersion;
  final String? connectResult;
  final String? softwareVersion;
  final String? hardwareVersion;
  final String? serial;

  /// 库自动识别出的任务（null = 未识别）。
  final String? detectedTask;

  /// 实际将使用的任务及其原因。
  final String resolvedTask;
  final String resolvedReason;

  /// 多行文本，便于直接展示或复制。
  String get summary =>
      '型号：${modelName ?? '未知'}（ID ${modelId ?? '-'}）\n'
      '协议版本：${protocolVersion ?? '-'}｜连接结果：${connectResult ?? '-'}\n'
      'DPI/打印头：${dpi ?? '-'} / ${printheadPixels ?? '-'}px\n'
      '软件/硬件：${softwareVersion ?? '-'} / ${hardwareVersion ?? '-'}\n'
      '打印任务：$resolvedTask（$resolvedReason）';
}

/// 基于 niim_blue_flutter 的精臣蓝牙打印机实现。
class NiimbotPrinterService implements LabelPrinter {
  NiimbotPrinterService({NiimbotBluetoothClient? client})
    : _client = client ?? NiimbotBluetoothClient() {
    // 打开库内调试日志（连接流程、数据包收发），便于真机排查。
    _client.setDebug(true);
    _client.onPacketReceived.listen(_logIncomingPacket);
  }

  final NiimbotBluetoothClient _client;
  BluetoothDevice? _device;

  /// 最近一次打印使用的任务名与选择原因（诊断用）。
  String? lastPrintTask;
  String? lastPrintTaskReason;

  @override
  bool get isConnected => _client.isConnected();

  @override
  String? get deviceId => _device?.remoteId.str;

  String? get deviceName => _device?.platformName;

  /// 已连接打印机的型号信息（用于自动识别 DPI 等）。
  PrinterModelMeta? get modelMeta {
    final id = _client.info.modelId;
    if (id == null) return null;
    for (final meta in modelsLibrary) {
      if (meta.id.contains(id)) return meta;
    }
    return null;
  }

  /// 当前打印机诊断信息。
  PrinterDiagnostics diagnostics({
    PrinterTaskPreference preference = PrinterTaskPreference.auto,
  }) {
    final info = _client.info;
    final meta = modelMeta;
    final detected = _client.getPrintTaskType();
    final resolution = resolvePrintTask(
      preference: preference,
      detected: detected,
      protocolVersion: info.protocolVersion,
      model: meta?.model,
    );
    return PrinterDiagnostics(
      connected: isConnected,
      deviceName: deviceName,
      modelId: info.modelId,
      modelName: meta?.model.value,
      dpi: meta?.dpi,
      printheadPixels: meta?.printheadPixels,
      protocolVersion: info.protocolVersion,
      connectResult: info.connectResult?.name,
      softwareVersion: info.softwareVersion,
      hardwareVersion: info.hardwareVersion,
      serial: info.serial,
      detectedTask: detected == null ? null : printTaskLabel(detected),
      resolvedTask: printTaskLabel(resolution.task),
      resolvedReason: resolution.reason,
    );
  }

  void setOnDisconnect(void Function() callback) =>
      _client.setOnDisconnect(callback);

  /// 扫描可用打印机。
  Future<List<BluetoothDevice>> listDevices({
    Duration timeout = const Duration(seconds: 3),
  }) => NiimbotBluetoothClient.listDevices(timeout: timeout);

  /// 连接指定设备。
  Future<String> connect(BluetoothDevice device) async {
    _device = device;
    _client.setDevice(device);
    final info = await _client.connect();
    _client.startHeartbeat();
    final meta = modelMeta;
    final clientInfo = _client.info;
    final resolution = resolvePrintTask(
      preference: PrinterTaskPreference.auto,
      detected: _client.getPrintTaskType(),
      protocolVersion: clientInfo.protocolVersion,
      model: meta?.model,
    );
    appLog(
      '连接',
      '已连接 ${info.deviceName ?? device.platformName}'
          '｜型号=${meta?.model.value ?? '未知'}（ID=${clientInfo.modelId}）'
          '｜协议版本=${clientInfo.protocolVersion}'
          '｜连接结果=${clientInfo.connectResult?.name}'
          '｜软件=${clientInfo.softwareVersion ?? '-'}'
          '硬件=${clientInfo.hardwareVersion ?? '-'}'
          '｜打印任务=${printTaskLabel(resolution.task)}（${resolution.reason}）',
    );
    return info.deviceName ?? device.platformName;
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _device = null;
  }

  @override
  Future<void> printPage(
    PrintPage page, {
    required int density,
    PrinterTaskPreference taskPreference = PrinterTaskPreference.auto,
  }) async {
    if (!isConnected) {
      throw Exception('打印机未连接');
    }

    final meta = modelMeta;
    final resolution = resolvePrintTask(
      preference: taskPreference,
      detected: _client.getPrintTaskType(),
      protocolVersion: _client.info.protocolVersion,
      model: meta?.model,
    );
    lastPrintTask = printTaskLabel(resolution.task);
    lastPrintTaskReason = resolution.reason;
    appLog(
      '打印',
      '任务=$lastPrintTask（$lastPrintTaskReason）'
          '｜型号=${meta?.model.value ?? '未知'}（ID=${_client.info.modelId}）'
          '｜协议版本=${_client.info.protocolVersion}'
          '｜浓度=$density｜页面=${page.width}x${page.height}',
    );

    _client.stopHeartbeat();
    _client.setPacketInterval(0);

    final stopwatch = Stopwatch()..start();
    try {
      final options = PrintOptions(
        totalPages: 1,
        density: density,
        labelType: LabelType.withGaps,
      );

      final task = _client.abstraction.newPrintTask(resolution.task, options);

      appLog('打印', 'printInit …');
      await task.printInit();
      appLog('打印', 'printPage …');
      await task.printPage(page.toEncodedImage(), 1);
      appLog('打印', 'waitForFinished …');
      await task.waitForFinished();
      appLog('打印', '完成，用时 ${stopwatch.elapsedMilliseconds}ms');
    } catch (error) {
      appLog(
        '打印',
        '失败（用时 ${stopwatch.elapsedMilliseconds}ms）：'
            '${describePrinterError(error)}',
      );
      rethrow;
    } finally {
      _client.startHeartbeat();
    }
  }

  /// 记录打印机上行数据包（心跳除外，避免日志刷屏）。
  void _logIncomingPacket(NiimbotPacket packet) {
    const heartbeatCommands = {0xdc, 0xdd, 0xde, 0xdf, 0xd9};
    if (heartbeatCommands.contains(packet.command.value)) return;
    appLog(
      'BLE',
      'RX cmd=0x${packet.command.value.toRadixString(16)} '
          'len=${packet.data.length} ${hexBytes(packet.data)}',
    );
  }
}
