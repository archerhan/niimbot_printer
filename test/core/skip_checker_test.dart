import 'package:flutter_test/flutter_test.dart';
import 'package:printer/core/skip_checker.dart';

void main() {
  const checker = SkipChecker();

  test('首次打印（无历史成功）不警告', () {
    expect(
      checker.shouldWarn(currentSerial: 1, lastSuccessSerial: null),
      isFalse,
    );
  });

  test('连续（上一次成功 5，当前 6）不警告', () {
    expect(
      checker.shouldWarn(currentSerial: 6, lastSuccessSerial: 5),
      isFalse,
    );
  });

  test('跳号（上一次成功 5，当前 8）警告', () {
    expect(
      checker.shouldWarn(currentSerial: 8, lastSuccessSerial: 5),
      isTrue,
    );
  });

  test('回退（上一次成功 5，当前 3）也警告', () {
    expect(
      checker.shouldWarn(currentSerial: 3, lastSuccessSerial: 5),
      isTrue,
    );
  });

  test('原地重复（上一次成功 5，当前 5）也警告', () {
    expect(
      checker.shouldWarn(currentSerial: 5, lastSuccessSerial: 5),
      isTrue,
    );
  });
}
