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
    this.isReprint = false,
    this.originalId,
    this.deviceId,
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

  /// 是否打印成功。
  final bool success;

  /// 是否为重打记录。
  final bool isReprint;

  /// 重打记录关联的原记录 id。
  final int? originalId;

  /// 打印设备 id。
  final String? deviceId;

  PrintRecord copyWith({
    int? id,
    DateTime? createdAt,
    String? productCode,
    String? accessoryCode,
    int? serial,
    String? qrContent,
    bool? success,
    List<String>? labelLines,
    bool? isReprint,
    int? originalId,
    String? deviceId,
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
      isReprint: isReprint ?? this.isReprint,
      originalId: originalId ?? this.originalId,
      deviceId: deviceId ?? this.deviceId,
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
        'success': success ? 1 : 0,
        'is_reprint': isReprint ? 1 : 0,
        'original_id': originalId,
        'device_id': deviceId,
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
      success: (map['success'] as int) == 1,
      isReprint: (map['is_reprint'] as int) == 1,
      originalId: map['original_id'] as int?,
      deviceId: map['device_id'] as String?,
    );
  }

  static List<String> _parseLines(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    return raw.split('\n');
  }
}
