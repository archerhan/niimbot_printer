import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

/// 打印机抽象，便于在单测中注入假实现。
abstract class LabelPrinter {
  bool get isConnected;
  String? get deviceId;

  /// 打印一页标签；失败时抛异常。
  Future<void> printPage(PrintPage page, {required int density});
}

/// 基于 niim_blue_flutter 的精臣蓝牙打印机实现。
class NiimbotPrinterService implements LabelPrinter {
  NiimbotPrinterService({NiimbotBluetoothClient? client})
      : _client = client ?? NiimbotBluetoothClient();

  final NiimbotBluetoothClient _client;
  BluetoothDevice? _device;

  @override
  bool get isConnected => _client.isConnected();

  @override
  String? get deviceId => _device?.remoteId.str;

  String? get deviceName => _device?.platformName;

  void setOnDisconnect(void Function() callback) =>
      _client.setOnDisconnect(callback);

  /// 扫描可用打印机。
  Future<List<BluetoothDevice>> listDevices({
    Duration timeout = const Duration(seconds: 3),
  }) =>
      NiimbotBluetoothClient.listDevices(timeout: timeout);

  /// 连接指定设备。
  Future<String> connect(BluetoothDevice device) async {
    _device = device;
    _client.setDevice(device);
    final info = await _client.connect();
    _client.startHeartbeat();
    return info.deviceName ?? device.platformName;
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _device = null;
  }

  @override
  Future<void> printPage(PrintPage page, {required int density}) async {
    if (!isConnected) {
      throw Exception('打印机未连接');
    }

    _client.stopHeartbeat();
    _client.setPacketInterval(0);

    try {
      final task = _client.createPrintTask(
        PrintOptions(
          totalPages: 1,
          density: density,
          labelType: LabelType.withGaps,
        ),
      );
      if (task == null) {
        throw Exception('未能识别打印机型号');
      }

      await task.printInit();
      await task.printPage(page.toEncodedImage(), 1);
      await task.waitForFinished();
    } finally {
      _client.startHeartbeat();
    }
  }
}
