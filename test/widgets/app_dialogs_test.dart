import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/widgets/app_dialogs.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('选择打印机弹窗能正常渲染设备列表', (tester) async {
    final devices = <BluetoothDevice>[
      BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
      BluetoothDevice.fromId('11:22:33:44:55:66'),
    ];

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ShadButton(
                onPressed: () => showDevicePicker(ctx, devices),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 之前 ListTile 缺少 Material 祖先会抛异常（release 下表现为灰色方块）
    expect(tester.takeException(), isNull);

    expect(find.text('选择打印机'), findsOneWidget);
    // 测试环境拿不到 platformName，回退为「未知设备」并显示 MAC
    expect(find.text('未知设备'), findsNWidgets(2));
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
