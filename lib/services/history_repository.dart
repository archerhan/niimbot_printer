import 'package:sqflite/sqflite.dart';

import '../models/print_record.dart';

/// 打印历史存储（sqflite）。
class HistoryRepository {
  HistoryRepository(this.db);

  final Database db;

  static const String table = 'print_history';
  static const int schemaVersion = 1;

  /// 打开数据库。
  ///
  /// [factory] 可注入用于测试（例如 sqflite_common_ffi 的 databaseFactoryFfi）。
  /// [path] 传 [inMemoryDatabasePath] 可开内存库。
  static Future<HistoryRepository> open({
    DatabaseFactory? factory,
    String path = 'printer.db',
    int version = schemaVersion,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _onCreate,
      ),
    );
    return HistoryRepository(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        product_code TEXT NOT NULL,
        accessory_code TEXT NOT NULL,
        serial INTEGER NOT NULL,
        qr_content TEXT NOT NULL,
        label_lines TEXT NOT NULL DEFAULT '',
        success INTEGER NOT NULL DEFAULT 0,
        is_reprint INTEGER NOT NULL DEFAULT 0,
        original_id INTEGER,
        device_id TEXT
      )
    ''');
  }

  /// 新增一条记录，返回带 id 的记录。
  Future<PrintRecord> insert(PrintRecord record) async {
    final id = await db.insert(table, record.toMap());
    return record.copyWith(id: id);
  }

  /// 最近的记录（按 id 倒序）。
  Future<List<PrintRecord>> recent({int limit = 100}) async {
    final rows = await db.query(
      table,
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(PrintRecord.fromMap).toList();
  }

  /// 最近一条成功打印记录（用于跳号判断）。
  Future<PrintRecord?> lastSuccess() async {
    final rows = await db.query(
      table,
      where: 'success = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrintRecord.fromMap(rows.first);
  }

  /// 指定配件编号最近一次打印记录（用于重复扫码判定）。
  Future<PrintRecord?> lastByAccessoryCode(String accessoryCode) async {
    final rows = await db.query(
      table,
      where: 'accessory_code = ?',
      whereArgs: <Object?>[accessoryCode],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrintRecord.fromMap(rows.first);
  }

  Future<PrintRecord?> byId(int id) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrintRecord.fromMap(rows.first);
  }

  Future<int> count() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() => db.close();
}
