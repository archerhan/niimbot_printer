import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 简单提示框。
Future<void> showAlert(
  BuildContext context, {
  required String title,
  String? message,
}) {
  return showShadDialog<void>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text(title),
      description: message == null ? null : Text(message),
      actions: [
        ShadButton(
          child: const Text('知道了'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// 二次确认框，返回用户是否确认。
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = '确定',
  String cancelText = '取消',
  bool destructive = false,
}) async {
  final result = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text(title),
      description: message == null ? null : Text(message),
      actions: [
        ShadButton.outline(
          child: Text(cancelText),
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        if (destructive)
          ShadButton.destructive(
            child: Text(confirmText),
            onPressed: () => Navigator.of(ctx).pop(true),
          )
        else
          ShadButton(
            child: Text(confirmText),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
      ],
    ),
  );
  return result ?? false;
}

/// 跳号警告：返回用户是否选择继续。
Future<bool> showSkipWarning(
  BuildContext context, {
  required int currentSerial,
  required int? lastSuccessSerial,
}) {
  return showConfirm(
    context,
    title: '检测到跳号',
    message: '上次成功打印序号为 '
        '${lastSuccessSerial?.toString().padLeft(4, '0') ?? '—'}，'
        '本次为 ${currentSerial.toString().padLeft(4, '0')}。\n'
        '是否继续跳号打印？',
    confirmText: '继续跳号打印',
  );
}

/// 重复扫码时的选择。
enum DuplicateChoice { reuse, createNew }

Future<DuplicateChoice?> showDuplicateDialog(
  BuildContext context, {
  required String accessoryCode,
  required String previousProductCode,
}) {
  return showShadDialog<DuplicateChoice>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: const Text('该配件码已打印过'),
      description: Text(
        '配件编号：$accessoryCode\n上次产品编号：$previousProductCode',
      ),
      actions: [
        ShadButton.outline(
          child: const Text('取消'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        ShadButton.secondary(
          child: const Text('生成新编号'),
          onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.createNew),
        ),
        ShadButton(
          child: const Text('沿用旧编号'),
          onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.reuse),
        ),
      ],
    ),
  );
}

/// 打印机选择框。
Future<BluetoothDevice?> showDevicePicker(
  BuildContext context,
  List<BluetoothDevice> devices,
) {
  return showShadDialog<BluetoothDevice>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: const Text('选择打印机'),
      child: SizedBox(
        width: 320,
        height: 260,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: devices.length,
          itemBuilder: (_, index) {
            final device = devices[index];
            final name = device.platformName.isEmpty
                ? '未知设备'
                : device.platformName;
            return ListTile(
              title: Text(name),
              subtitle: Text(device.remoteId.str),
              onTap: () => Navigator.of(ctx).pop(device),
            );
          },
        ),
      ),
    ),
  );
}
