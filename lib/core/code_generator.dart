/// 产品编号 / 二维码内容 / 标签文字 的生成逻辑。
///
/// 这里全部是纯函数，方便单测覆盖。
class CodeGenerator {
  const CodeGenerator();

  /// 二维码固定前缀。
  static const String qrPrefix = '!';

  /// 产品编号与配件编号之间的固定分隔符。
  static const String accessorySeparator = '#MDE:';

  /// 二维码固定后缀。
  static const String qrSuffix = '@RESULT:OK';

  /// 序号默认位数。
  static const int defaultSerialLength = 4;

  /// 序号上限，超过即报错（不再自动进位）。
  static const int maxSerial = 9999;

  /// 将序号格式化为固定位数（左补零）。
  String formatSerial(int serial, [int serialLength = defaultSerialLength]) {
    return serial.toString().padLeft(serialLength, '0');
  }

  /// 拼接产品编号：prefixA + prefixB + prefixC + 序号。
  String buildProductCode({
    required String prefixA,
    required String prefixB,
    required String prefixC,
    required int serial,
    int serialLength = defaultSerialLength,
  }) {
    return '$prefixA$prefixB$prefixC${formatSerial(serial, serialLength)}';
  }

  /// 拼接二维码内容：!{产品编号}#MDE:{配件编号}@RESULT:OK。
  String buildQrContent({
    required String productCode,
    required String accessoryCode,
  }) {
    return '$qrPrefix$productCode$accessorySeparator$accessoryCode$qrSuffix';
  }

  /// 一步生成二维码内容（内部先拼产品编号）。
  String buildQr({
    required String prefixA,
    required String prefixB,
    required String prefixC,
    required int serial,
    required String accessoryCode,
    int serialLength = defaultSerialLength,
  }) {
    final productCode = buildProductCode(
      prefixA: prefixA,
      prefixB: prefixB,
      prefixC: prefixC,
      serial: serial,
      serialLength: serialLength,
    );
    return buildQrContent(
      productCode: productCode,
      accessoryCode: accessoryCode,
    );
  }

  /// 标签上人眼可见的三行文字：
  /// 第 1 行 prefixA，第 2 行 prefixB，第 3 行 prefixC-序号。
  List<String> buildLabelLines({
    required String prefixA,
    required String prefixB,
    required String prefixC,
    required int serial,
    int serialLength = defaultSerialLength,
  }) {
    return <String>[
      prefixA,
      prefixB,
      '$prefixC-${formatSerial(serial, serialLength)}',
    ];
  }

  /// 序号是否在合法范围内（1 ~ 9999）。
  bool isSerialInRange(int serial) => serial >= 1 && serial <= maxSerial;
}

/// 序号超出上限时抛出。
class SerialOverflowException implements Exception {
  const SerialOverflowException(this.serial);

  final int serial;

  @override
  String toString() => '序号 $serial 超出上限 ${CodeGenerator.maxSerial}';
}
