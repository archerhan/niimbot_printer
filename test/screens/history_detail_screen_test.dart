import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/print_record.dart';
import 'package:printer/screens/history_detail_screen.dart';
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

  testWidgets('详情页展示标签内容与打印信息', (tester) async {
    final record = PrintRecord(
      id: 1,
      createdAt: DateTime(2026, 10, 9, 10, 30, 15),
      productCode: 'ADM32672805CTX6O60005',
      accessoryCode: 'MDE62564302CDFL9D',
      serial: 5,
      qrContent: '!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK',
      labelLines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
      success: true,
      deviceId: 'AA:BB:CC',
    );

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: ShadApp(
          home: HistoryDetailScreen(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('打印详情'), findsOneWidget);
    expect(find.text('ADM32672805CTX6O60005'), findsOneWidget);
    expect(find.text('MDE62564302CDFL9D'), findsOneWidget);
    expect(find.text('0005'), findsOneWidget);
    expect(find.text('打印成功'), findsOneWidget);
    expect(find.text('2026-10-09 10:30:15'), findsOneWidget);
    expect(find.text('AA:BB:CC'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('重打'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('重打'), findsOneWidget);
  });

  testWidgets('重打记录展示重打类型与原记录', (tester) async {
    final record = PrintRecord(
      id: 2,
      createdAt: DateTime(2026, 10, 9, 11, 0),
      productCode: 'ADM32672805CTX6O60005',
      accessoryCode: 'MDE62564302CDFL9D',
      serial: 5,
      qrContent: '!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK',
      labelLines: const <String>['ADM32672805', 'CTX', '6O6-0005'],
      success: false,
      isReprint: true,
      originalId: 1,
    );

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: ShadApp(
          home: HistoryDetailScreen(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('打印失败'), findsOneWidget);
    expect(find.text('重打（原记录 #1）'), findsOneWidget);
  });
}
