import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/app_settings.dart';
import 'package:printer/screens/settings_screen.dart';
import 'package:printer/services/history_repository.dart';
import 'package:printer/services/label_printer.dart';
import 'package:printer/services/print_service.dart';
import 'package:printer/services/settings_service.dart';
import 'package:printer/state/app_controller.dart';
import 'package:printer/state/app_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late HistoryRepository history;
  late SettingsService settings;
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = SettingsService(await SharedPreferences.getInstance());
    history = await HistoryRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final printer = NiimbotPrinterService();
    controller = AppController(
      settings: settings,
      history: history,
      printer: printer,
      printService: PrintService(
        settings: settings,
        history: history,
        printer: printer,
      ),
    );
  });

  tearDown(() async {
    await history.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    // 放大视口，保证底部卡片（打印任务 / 诊断）也参与构建。
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const ShadApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('设置页渲染打印任务与诊断卡片', (tester) async {
    await pumpSettings(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('打印任务（兼容性）'), findsOneWidget);
    expect(find.text('打印机诊断'), findsOneWidget);
    expect(find.text('打印测试页'), findsOneWidget);
    expect(find.text('自动（推荐）'), findsOneWidget);
  });

  testWidgets('点击可切换打印任务并立即持久化', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('D110M_V4'));
    await tester.pumpAndSettle();

    expect(
      settings.settings.printTaskPreference,
      PrinterTaskPreference.d110mV4,
    );
    expect(find.textContaining('当前将使用：D110M_V4'), findsOneWidget);
  });
}
