import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'services/history_repository.dart';
import 'services/label_printer.dart';
import 'services/print_service.dart';
import 'services/settings_service.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs);

  final dbPath = p.join(await getDatabasesPath(), 'printer.db');
  final history = await HistoryRepository.open(path: dbPath);

  final printer = NiimbotPrinterService();
  final controller = AppController(
    settings: settings,
    history: history,
    printer: printer,
    printService: PrintService(
      settings: settings,
      history: history,
      printer: printer,
    ),
  );

  runApp(PrinterApp(controller: controller));

  unawaited(controller.autoConnect());
}
