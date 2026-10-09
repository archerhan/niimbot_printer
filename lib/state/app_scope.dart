import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// 把 [AppController] 注入到控件树中，供各页面读取。
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未找到');
    return scope!.notifier!;
  }
}
