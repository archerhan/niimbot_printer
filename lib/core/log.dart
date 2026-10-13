import 'package:flutter/foundation.dart';

/// 统一的调试日志输出。
///
/// `flutter run` 时在控制台可见；也可用 `adb logcat`（TAG 为 flutter）查看。
void appLog(String tag, String message) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final ts =
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[$ts][$tag] $message');
}

/// 字节数组转十六进制字符串，便于日志中查看原始数据包。
String hexBytes(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
