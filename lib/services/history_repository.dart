import 'package:sqflite/sqflite.dart';

import '../models/print_record.dart';

/// 历史筛选里的「产品系列」选项。
class SeriesOption {
  const SeriesOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// 打印历史存储（sqflite）。
class HistoryRepository {
  HistoryRepository(this.db);

  final Database db;

  static const String table = 'print_history';
  static const int schemaVersion = 2;

  static const String _createTableSql = '''
    CREATE TABLE $table (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at INTEGER NOT NULL,
      product_code TEXT NOT NULL,
      accessory_code TEXT NOT NULL,
      serial INTEGER NOT NULL,
      qr_content TEXT NOT NULL,
      label_lines TEXT NOT NULL DEFAULT '',
      series_id TEXT NOT NULL DEFAULT '',
      series_name TEXT NOT NULL DEFAULT '',
      success INTEGER NOT NULL DEFAULT 0,
      is_reprint INTEGER NOT NULL DEFAULT 0,
      original_id INTEGER,
      device_id TEXT,
      deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

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
        onUpgrade: _onUpgrade,
      ),
    );
    return HistoryRepository(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createTableSql);
  }

  /// 迁移阶梯：从 [oldVersion] 逐级升到 [newVersion]。
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var v = oldVersion; v < newVersion; v++) {
      await _migrate(db, v, v + 1);
    }
  }

  /// 单步迁移。[to] 为目标版本号。
  static Future<void> _migrate(Database db, int from, int to) async {
    switch (to) {
      case 2:
        // v1 → v2：增加产品系列与软删除标记
        await db.execute(
          "ALTER TABLE $table ADD COLUMN series_id TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          "ALTER TABLE $table ADD COLUMN series_name TEXT NOT NULL DEFAULT ''",
        );
        await db.execute(
          'ALTER TABLE $table ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
        );
        break;
      default:
        break;
    }
  }

  // ------------------------------------------------------------------ 写入

  /// 新增一条记录，返回带 id 的记录。
  Future<PrintRecord> insert(PrintRecord record) async {
    final id = await db.insert(table, record.toMap());
    return record.copyWith(id: id);
  }

  /// 软删除若干条记录（置 `deleted = 1`，数据保留）。
  Future<int> softDelete(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    return db.update(
      table,
      <String, Object?>{'deleted': 1},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // ------------------------------------------------------------------ 读取

  /// 列表查询（**排除**软删除记录）。
  Future<List<PrintRecord>> search({
    String? seriesId,
    DateTime? monthStart,
    DateTime? monthEnd,
    String? keyword,
    int limit = 50,
    int offset = 0,
  }) async {
    final filter = _buildWhere(
      seriesId: seriesId,
      monthStart: monthStart,
      monthEnd: monthEnd,
      keyword: keyword,
    );
    final rows = await db.query(
      table,
      where: filter.where,
      whereArgs: filter.args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(PrintRecord.fromMap).toList();
  }

  /// 符合条件的记录总数（排除软删除）。
  Future<int> countMatching({
    String? seriesId,
    DateTime? monthStart,
    DateTime? monthEnd,
    String? keyword,
  }) async {
    final filter = _buildWhere(
      seriesId: seriesId,
      monthStart: monthStart,
      monthEnd: monthEnd,
      keyword: keyword,
    );
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE ${filter.where}',
      filter.args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 符合条件的记录 id 列表（供「全选」使用，作用于当前筛选结果集）。
  Future<List<int>> searchIds({
    String? seriesId,
    DateTime? monthStart,
    DateTime? monthEnd,
    String? keyword,
  }) async {
    final filter = _buildWhere(
      seriesId: seriesId,
      monthStart: monthStart,
      monthEnd: monthEnd,
      keyword: keyword,
    );
    final rows = await db.query(
      table,
      columns: <String>['id'],
      where: filter.where,
      whereArgs: filter.args,
    );
    return rows.map((row) => row['id'] as int).toList();
  }

  /// 最近的记录（按时间倒序，排除软删除）。
  Future<List<PrintRecord>> recent({int limit = 100}) => search(limit: limit);

  /// 最近一条成功打印记录（**包含**软删除，用于跳号判断）。
  ///
  /// [seriesId] 传入时只在该系列内查找。
  Future<PrintRecord?> lastSuccess({String? seriesId}) async {
    final where = <String>['success = 1'];
    final args = <Object?>[];
    if (seriesId != null && seriesId.isNotEmpty) {
      where.add('series_id = ?');
      args.add(seriesId);
    }
    final rows = await db.query(
      table,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrintRecord.fromMap(rows.first);
  }

  /// 指定配件编号最近一次打印记录（**包含**软删除，用于重复码检测）。
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

  /// 未删除的记录总数。
  Future<int> count() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE deleted = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 筛选下拉用：出现过的产品系列（按最近使用时间倒序）。
  Future<List<SeriesOption>> seriesOptions() async {
    final rows = await db.rawQuery(
      'SELECT series_id, series_name, MAX(created_at) AS latest '
      'FROM $table WHERE deleted = 0 '
      'GROUP BY series_id ORDER BY latest DESC',
    );
    return rows
        .map(
          (row) => SeriesOption(
            id: row['series_id'] as String? ?? '',
            name: row['series_name'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// 筛选下拉用：出现过的月份（`YYYY-MM`，倒序）。
  Future<List<String>> availableMonths() async {
    final rows = await db.rawQuery(
      "SELECT strftime('%Y-%m', created_at / 1000, 'unixepoch', 'localtime') "
      'AS ym FROM $table WHERE deleted = 0 GROUP BY ym ORDER BY ym DESC',
    );
    return rows
        .map((row) => row['ym'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<void> close() => db.close();

  // ---------------------------------------------------------------- 内部实现

  _WhereFilter _buildWhere({
    String? seriesId,
    DateTime? monthStart,
    DateTime? monthEnd,
    String? keyword,
  }) {
    final clauses = <String>['deleted = 0'];
    final args = <Object?>[];

    if (seriesId != null && seriesId.isNotEmpty) {
      clauses.add('series_id = ?');
      args.add(seriesId);
    }
    if (monthStart != null) {
      clauses.add('created_at >= ?');
      args.add(monthStart.millisecondsSinceEpoch);
    }
    if (monthEnd != null) {
      clauses.add('created_at < ?');
      args.add(monthEnd.millisecondsSinceEpoch);
    }
    final trimmed = keyword?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      clauses.add('product_code LIKE ?');
      args.add('%$trimmed%');
    }

    return _WhereFilter(clauses.join(' AND '), args);
  }
}

class _WhereFilter {
  const _WhereFilter(this.where, this.args);

  final String where;
  final List<Object?> args;
}
