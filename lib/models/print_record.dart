/// 打印历史记录。
class PrintRecord {
  const PrintRecord({
    this.id,
    required this.createdAt,
    required this.productCode,
    required this.accessoryCode,
    required this.serial,
    required this.qrContent,
    required this.success,
    this.labelLines = const <String>[],
    this.seriesId = '',
    this.seriesName = '',
    this.isReprint = false,
    this.originalId,
    this.deviceId,
    this.deleted = false,
  });

  /// 主键，未入库时为 null。
  final int? id;
  final DateTime createdAt;
  final String productCode;
  final String accessoryCode;
  final int serial;
  final String qrContent;

  /// 标签上人眼可见的文字行（用于重打还原版式）。
  final List<String> labelLines;

  /// 所属产品系列（冗余存名称，系列被删除后仍可展示与筛选）。
  final String seriesId;
  final String seriesName;

  /// 是否打印成功。
  final bool success;

  /// 是否为重打记录。
  final bool isReprint;

  /// 重打记录关联的原记录 id。
  final int? originalId;

  /// 打印设备 id。
  final String? deviceId;

  /// 软删除标记：为 true 时不出现在列表/统计中，
  /// 但仍参与跳号判断、重复配件码检测与「沿用旧编号」。
  final bool deleted;

  PrintRecord copyWith({
    int? id,
    DateTime? createdAt,
    String? productCode,
    String? accessoryCode,
    int? serial,
    String? qrContent,
    bool? success,
    List<String>? labelLines,
    String? seriesId,
    String? seriesName,
    bool? isReprint,
    int? originalId,
    String? deviceId,
    bool? deleted,
  }) {
    return PrintRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      productCode: productCode ?? this.productCode,
      accessoryCode: accessoryCode ?? this.accessoryCode,
      serial: serial ?? this.serial,
      qrContent: qrContent ?? this.qrContent,
      success: success ?? this.success,
      labelLines: labelLines ?? this.labelLines,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      isReprint: isReprint ?? this.isReprint,
      originalId: originalId ?? this.originalId,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'product_code': productCode,
        'accessory_code': accessoryCode,
        'serial': serial,
        'qr_content': qrContent,
        'label_lines': labelLines.join('\n'),
        'series_id': seriesId,
        'series_name': seriesName,
        'success': success ? 1 : 0,
        'is_reprint': isReprint ? 1 : 0,
        'original_id': originalId,
        'device_id': deviceId,
        'deleted': deleted ? 1 : 0,
      };

  factory PrintRecord.fromMap(Map<String, Object?> map) {
    return PrintRecord(
      id: map['id'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      productCode: map['product_code'] as String,
      accessoryCode: map['accessory_code'] as String,
      serial: map['serial'] as int,
      qrContent: map['qr_content'] as String,
      labelLines: _parseLines(map['label_lines'] as String?),
      seriesId: map['series_id'] as String? ?? '',
      seriesName: map['series_name'] as String? ?? '',
      success: (map['success'] as int) == 1,
      isReprint: (map['is_reprint'] as int) == 1,
      originalId: map['original_id'] as int?,
      deviceId: map['device_id'] as String?,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  static List<String> _parseLines(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    return raw.split('\n');
  }
}
