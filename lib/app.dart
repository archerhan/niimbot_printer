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
      child: const ShadApp(
        title: '标签助手',
        debugShowCheckedModeBanner: false,
        home: HomeScreen(),
      ),
    );
  }
}
