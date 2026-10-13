import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/models/product_series.dart';
import 'package:printer/screens/series_edit_screen.dart';
import 'package:printer/screens/series_list_screen.dart';
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

  late SettingsService settings;
  late HistoryRepository history;
  late AppController controller;

  Future<void> pumpScreen(Widget screen, WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: ShadApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 按钮可能在列表下方，先滚动到可见再点击。
  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

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

  group('产品系列列表', () {
    testWidgets('显示当前系列与操作按钮', (tester) async {
      await settings.addSeries(
        const ProductSeries(
          id: 's2',
          createdAt: 1,
          name: '乙系列',
          prefixA: 'ZZZ',
        ),
      );
      await pumpScreen(const SeriesListScreen(), tester);

      expect(find.text('当前使用'), findsOneWidget);
      expect(find.text('乙系列'), findsOneWidget);
      expect(find.text('切换到此系列'), findsOneWidget);
      expect(find.text('新增产品系列'), findsOneWidget);
      expect(find.text('编辑'), findsNWidgets(2));
      expect(find.text('删除'), findsNWidgets(2));
    });

    testWidgets('删除当前系列被拒绝并提示先切换', (tester) async {
      await settings.addSeries(
        const ProductSeries(
          id: 's2',
          createdAt: 1,
          name: '乙系列',
          prefixA: 'ZZZ',
        ),
      );
      await pumpScreen(const SeriesListScreen(), tester);

      // 第一个「删除」按钮属于默认系列（即当前系列）
      await tester.tap(find.text('删除').first);
      await tester.pumpAndSettle();

      expect(find.text('无法删除当前系列'), findsOneWidget);
    });

    testWidgets('切换系列后标记变化', (tester) async {
      await settings.addSeries(
        const ProductSeries(
          id: 's2',
          createdAt: 1,
          name: '乙系列',
          prefixA: 'ZZZ',
        ),
      );
      await pumpScreen(const SeriesListScreen(), tester);

      await tester.tap(find.text('切换到此系列'));
      await tester.pumpAndSettle();

      expect(settings.currentSeriesId, 's2');
      expect(find.text('当前使用'), findsOneWidget);
    });
  });

  group('编辑产品系列', () {
    testWidgets('新增：三段前缀全空时报错', (tester) async {
      await pumpScreen(const SeriesEditScreen(), tester);
      await tapButton(tester, '创建系列');

      expect(find.text('无法保存'), findsOneWidget);
      expect(find.textContaining('至少填写一段'), findsOneWidget);
    });

    testWidgets('新增：填写前缀后能创建系列', (tester) async {
      await pumpScreen(const SeriesEditScreen(), tester);

      await tester.enterText(find.byType(ShadInput).at(0), '乙系列');
      await tester.enterText(find.byType(ShadInput).at(1), 'ZZZ');
      await tapButton(tester, '创建系列');

      expect(settings.seriesList.length, 2);
      final created = settings.seriesList.last;
      expect(created.name, '乙系列');
      expect(created.prefixA, 'ZZZ');
      expect(created.serialNumber, 1);
    });

    testWidgets('新增：名称与已有系列重复时报错', (tester) async {
      await settings.addSeries(
        const ProductSeries(
          id: 's2',
          createdAt: 1,
          name: '乙系列',
          prefixA: 'ZZZ',
        ),
      );
      await pumpScreen(const SeriesEditScreen(), tester);

      await tester.enterText(find.byType(ShadInput).at(0), '乙系列');
      await tester.enterText(find.byType(ShadInput).at(1), 'YYY');
      await tapButton(tester, '创建系列');

      expect(find.text('无法保存'), findsOneWidget);
      expect(find.textContaining('已被其它系列使用'), findsOneWidget);
    });

    testWidgets('修改当前系列前缀：不重置序号并弹确认框', (tester) async {
      final current = settings.currentSeries;

      await pumpScreen(SeriesEditScreen(series: current), tester);

      await tester.enterText(find.byType(ShadInput).at(1), 'NEWPREFIX');
      await tapButton(tester, '保存修改');

      expect(find.text('确认新的产品编号'), findsOneWidget);
      expect(find.textContaining('NEWPREFIX'), findsWidgets);
      expect(find.textContaining('序号保持 0001 不变'), findsOneWidget);

      await tester.tap(find.text('确认修改'));
      await tester.pumpAndSettle();

      final updated = settings.currentSeries;
      expect(updated.prefixA, 'NEWPREFIX');
      expect(updated.serialNumber, 1, reason: '改前缀不重置序号');
    });
  });
}
