import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/print_record.dart';
import 'package:printer/screens/history_screen.dart';
import 'package:printer/services/history_repository.dart';
import 'package:printer/services/label_printer.dart';
import 'package:printer/services/print_service.dart';
import 'package:printer/services/settings_service.dart';
import 'package:printer/state/app_controller.dart';
import 'package:printer/state/app_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PrintRecord _record({
  required int serial,
  required String accessory,
  required DateTime createdAt,
  String seriesId = 's1',
  String seriesName = '甲系列',
}) {
  final padded = serial.toString().padLeft(4, '0');
  return PrintRecord(
    createdAt: createdAt,
    productCode: 'ADM32672805CTX6O6$padded',
    accessoryCode: accessory,
    serial: serial,
    qrContent: '!ADM32672805CTX6O6$padded#MDE:$accessory@RESULT:OK',
    labelLines: <String>['ADM32672805', 'CTX', '6O6-$padded'],
    seriesId: seriesId,
    seriesName: seriesName,
    success: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late HistoryRepository history;
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService(await SharedPreferences.getInstance());
    history = await HistoryRepository.open(
      // 控件测试里用无 isolate 的工厂，查询才能在测试的异步环境内完成。
      factory: databaseFactoryFfiNoIsolate,
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

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const ShadApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空历史显示占位文案', (tester) async {
    await pumpHistory(tester);
    expect(find.text('暂无打印记录'), findsOneWidget);
    expect(find.text('共 0 条记录；长按记录可进入多选'), findsOneWidget);
  });

  testWidgets('按天分组并展示记录（今天）', (tester) async {
    final now = DateTime.now();
    await history.insert(
      _record(serial: 1, accessory: 'A1', createdAt: now),
    );
    await history.insert(
      _record(
        serial: 2,
        accessory: 'A2',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    );

    await pumpHistory(tester);

    expect(find.textContaining('（今天）'), findsOneWidget);
    expect(find.textContaining('（昨天）'), findsOneWidget);
    expect(find.text('ADM32672805CTX6O60001'), findsOneWidget);
    expect(find.text('ADM32672805CTX6O60002'), findsOneWidget);
    expect(find.textContaining('配件：A1'), findsOneWidget);
    expect(find.textContaining('序号：0001'), findsOneWidget);
    expect(find.textContaining('时间：'), findsNWidgets(2));
  });

  testWidgets('筛选按钮与搜索框存在', (tester) async {
    await pumpHistory(tester);
    expect(find.text('系列：全部'), findsOneWidget);
    expect(find.text('月份：全部'), findsOneWidget);
    expect(find.text('搜索产品编号，例如 0012'), findsOneWidget);
  });

  testWidgets('搜索框能按产品编号过滤', (tester) async {
    await history.insert(
      _record(serial: 1, accessory: 'A1', createdAt: DateTime.now()),
    );
    await history.insert(
      _record(serial: 12, accessory: 'A2', createdAt: DateTime.now()),
    );
    await pumpHistory(tester);

    await tester.enterText(find.byType(ShadInput).first, '0012');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('ADM32672805CTX6O60012'), findsOneWidget);
    expect(find.text('ADM32672805CTX6O60001'), findsNothing);
    expect(find.text('共 1 条记录；长按记录可进入多选'), findsOneWidget);
  });

  testWidgets('进入多选后可勾选并统计数量', (tester) async {
    await history.insert(
      _record(serial: 1, accessory: 'A1', createdAt: DateTime.now()),
    );
    await pumpHistory(tester);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(find.text('已选 0 条'), findsOneWidget);

    await tester.tap(find.text('ADM32672805CTX6O60001'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 条'), findsOneWidget);
  });
}

