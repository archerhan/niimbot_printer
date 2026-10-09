import 'package:flutter_test/flutter_test.dart';
import 'package:printer/app.dart';
import 'package:printer/services/history_repository.dart';
import 'package:printer/services/label_printer.dart';
import 'package:printer/services/print_service.dart';
import 'package:printer/services/settings_service.dart';
import 'package:printer/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late HistoryRepository history;
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService(await SharedPreferences.getInstance());
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

  testWidgets('主界面显示标题、默认产品编号与扫描按钮', (tester) async {
    await tester.pumpWidget(PrinterApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('标签打印'), findsWidgets);
    expect(find.text('扫描配件码'), findsOneWidget);
    expect(find.text('当前产品编号'), findsOneWidget);
    expect(find.text('ADM32672805CTX6O60001'), findsOneWidget);
    expect(find.text('未连接'), findsOneWidget);
  });
}
