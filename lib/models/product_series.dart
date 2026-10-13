/// 产品系列：一套产品编号配置（产品名称 + 三段前缀 + 该系列自己的序号）。
class ProductSeries {
  const ProductSeries({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.prefixA = '',
    this.prefixB = '',
    this.prefixC = '',
    this.serialNumber = 1,
  });

  static const String defaultPrefixA = 'ADM32672805';
  static const String defaultPrefixB = 'CTX';
  static const String defaultPrefixC = '6O6';

  /// 兜底系列：设置里没有任何系列时使用（正常情况下不会发生）。
  static const ProductSeries fallback = ProductSeries(
    id: 'default',
    createdAt: 0,
    prefixA: defaultPrefixA,
    prefixB: defaultPrefixB,
    prefixC: defaultPrefixC,
  );

  /// 唯一标识。系列删除后重建同名系列也不会复用该 id。
  final String id;

  /// 创建时间戳（毫秒）。
  final int createdAt;

  /// 产品名称，可为空。
  final String name;

  final String prefixA;
  final String prefixB;
  final String prefixC;

  /// 该系列自己的当前序号。
  final int serialNumber;

  /// 三段前缀拼接（产品编号的前半部分），也用于冲突检测。
  String get productPrefix => '$prefixA$prefixB$prefixC';

  /// 列表显示名：名称为空时回退为前缀拼接。
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return productPrefix.isEmpty ? '（未命名系列）' : productPrefix;
  }

  ProductSeries copyWith({
    String? name,
    String? prefixA,
    String? prefixB,
    String? prefixC,
    int? serialNumber,
  }) {
    return ProductSeries(
      id: id,
      createdAt: createdAt,
      name: name ?? this.name,
      prefixA: prefixA ?? this.prefixA,
      prefixB: prefixB ?? this.prefixB,
      prefixC: prefixC ?? this.prefixC,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'createdAt': createdAt,
        'name': name,
        'prefixA': prefixA,
        'prefixB': prefixB,
        'prefixC': prefixC,
        'serialNumber': serialNumber,
      };

  factory ProductSeries.fromJson(Map<String, Object?> json) {
    return ProductSeries(
      id: json['id'] as String,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      prefixA: json['prefixA'] as String? ?? '',
      prefixB: json['prefixB'] as String? ?? '',
      prefixC: json['prefixC'] as String? ?? '',
      serialNumber: (json['serialNumber'] as num?)?.toInt() ?? 1,
    );
  }
}
