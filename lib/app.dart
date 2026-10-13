import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'screens/home_screen.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

class PrinterApp extends StatelessWidget {
  const PrinterApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      // ShadApp 不带 ScaffoldMessenger，提示改用 shadcn 的 Toast，
      // 且 ShadToaster 必须位于 ShadApp 内部（需要 ShadTheme）。
      child: ShadApp(
        title: '标签助手',
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            ShadToaster(child: child ?? const SizedBox.shrink()),
        home: const HomeScreen(),
      ),
    );
  }
}
