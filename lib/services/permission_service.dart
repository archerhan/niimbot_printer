import 'package:permission_handler/permission_handler.dart';

/// 运行时权限申请（Android 12+）。
class PermissionService {
  const PermissionService();

  /// 申请蓝牙扫描与连接权限。
  Future<bool> ensureBluetooth() async {
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  /// 申请相机权限（扫码）。
  Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 跳转到系统应用设置页。
  Future<bool> openSettings() => openAppSettings();
}
