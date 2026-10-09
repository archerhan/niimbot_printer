/// 跳号判断逻辑。
class SkipChecker {
  const SkipChecker();

  /// 当「当前待打印序号」不等于「上一次成功打印的序号 + 1」时，
  /// 判定为跳号，需要警告用户。
  ///
  /// 首次打印（还没有任何成功记录）不警告。
  bool shouldWarn({
    required int currentSerial,
    required int? lastSuccessSerial,
  }) {
    if (lastSuccessSerial == null) {
      return false;
    }
    return currentSerial != lastSuccessSerial + 1;
  }
}
