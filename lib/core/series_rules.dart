import '../models/product_series.dart';
import 'code_generator.dart';

/// 产品系列的校验与冲突检测（纯逻辑，便于单测）。
class SeriesRules {
  const SeriesRules();

  /// 前缀中不允许出现的字符：会破坏二维码固定分隔符。
  static const List<String> forbiddenPrefixChars = <String>['#', '@', '!'];

  /// 校验系列配置。返回错误信息；`null` 表示通过。
  String? validate(ProductSeries series, List<ProductSeries> others) {
    final segments = <String>[
      series.prefixA,
      series.prefixB,
      series.prefixC,
    ];

    if (segments.every((segment) => segment.trim().isEmpty)) {
      return '三段前缀不能全为空，至少填写一段';
    }

    for (final segment in segments) {
      if (segment.contains(' ')) {
        return '前缀不能包含空格';
      }
      for (final char in forbiddenPrefixChars) {
        if (segment.contains(char)) {
          return '前缀不能包含 $char（会破坏二维码格式）';
        }
      }
    }

    final name = series.name.trim();
    if (name.isNotEmpty) {
      final duplicated = others.any(
        (other) =>
            other.id != series.id &&
            other.name.trim().toLowerCase() == name.toLowerCase(),
      );
      if (duplicated) {
        return '产品名称「$name」已被其它系列使用';
      }
    }

    if (series.serialNumber < 1 ||
        series.serialNumber > CodeGenerator.maxSerial) {
      return '序号需为 1 ~ ${CodeGenerator.maxSerial}';
    }

    return null;
  }

  /// 与其它系列的前缀拼接冲突时返回提示；`null` 表示不冲突。
  String? conflictWarning(ProductSeries series, List<ProductSeries> others) {
    final prefix = series.productPrefix.trim().toLowerCase();
    if (prefix.isEmpty) return null;

    for (final other in others) {
      if (other.id == series.id) continue;
      if (other.productPrefix.trim().toLowerCase() == prefix) {
        return '与系列「${other.displayName}」的前缀完全相同，'
            '两个系列会生成相同的产品编号。';
      }
    }
    return null;
  }
}
