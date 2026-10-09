import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/skip_checker.dart';
import '../services/history_repository.dart';
import '../services/label_printer.dart';
import '../services/print_service.dart';
import '../services/settings_service.dart';

/// 打印机连接状态。
enum ConnectionStatus { disconnected, connecting, connected }

/// 应用级状态：持有各服务，并管理打印机连接。
class AppController extends ChangeNotifier {
  AppController({
    required this.settings,
    required this.history,
    required this.printService,
    required this.printer,
    this.skipChecker = const SkipChecker(),
  });

  final SettingsService settings;
  final HistoryRepository history;
  final PrintService printService;
  final NiimbotPrinterService printer;
  final SkipChecker skipChecker;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _deviceName;

  ConnectionStatus get status => _status;
  String? get deviceName => _deviceName;
  bool get isConnected => _status == ConnectionStatus.connected;

  String get statusText => switch (_status) {
        ConnectionStatus.disconnected => '未连接',
        ConnectionStatus.connecting => '连接中…',
        ConnectionStatus.connected =>
          _deviceName == null ? '已连接' : '已连接：$_deviceName',
      };

  /// 启动时自动连接上次设备，失败重试 3 次。
  Future<void> autoConnect() async {
    final lastId = settings.settings.lastDeviceId;
    if (lastId.isEmpty) return;

    printer.setOnDisconnect(() {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    });

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final devices =
            await printer.listDevices(timeout: const Duration(seconds: 3));
        final match =
            devices.where((d) => d.remoteId.str == lastId).toList();
        if (match.isNotEmpty) {
          await connect(match.first);
          return;
        }
      } catch (_) {
        // 忽略，进入下次重试
      }
      await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
    }
  }

  /// 扫描可用打印机。
  Future<List<BluetoothDevice>> scan({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      printer.listDevices(timeout: timeout);

  /// 连接指定设备。
  Future<void> connect(BluetoothDevice device) async {
    _status = ConnectionStatus.connecting;
    notifyListeners();
    try {
      final name = await printer.connect(device);
      _deviceName = name;
      _status = ConnectionStatus.connected;
      await settings.setLastDevice(id: device.remoteId.str, name: name);
    } catch (error) {
      _status = ConnectionStatus.disconnected;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await printer.disconnect();
    _status = ConnectionStatus.disconnected;
    _deviceName = null;
    notifyListeners();
  }
}
