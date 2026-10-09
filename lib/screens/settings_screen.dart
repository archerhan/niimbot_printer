import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _a = TextEditingController();
  final TextEditingController _b = TextEditingController();
  final TextEditingController _c = TextEditingController();
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _offsetX = TextEditingController();
  final TextEditingController _offsetY = TextEditingController();
  final TextEditingController _fontSize = TextEditingController();
  final TextEditingController _density = TextEditingController();
  bool _continuous = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final s = AppScope.of(context).settings.settings;
    _a.text = s.prefixA;
    _b.text = s.prefixB;
    _c.text = s.prefixC;
    _serial.text = s.serialNumber.toString();
    _offsetX.text = s.offsetX.toString();
    _offsetY.text = s.offsetY.toString();
    _fontSize.text = s.fontSize.toStringAsFixed(0);
    _density.text = s.density.toString();
    _continuous = s.continuousMode;
    _initialized = true;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _a,
      _b,
      _c,
      _serial,
      _offsetX,
      _offsetY,
      _fontSize,
      _density,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final old = controller.settings.settings;

    final newA = _a.text.trim();
    final newB = _b.text.trim();
    final newC = _c.text.trim();
    final prefixChanged =
        newA != old.prefixA || newB != old.prefixB || newC != old.prefixC;

    if (prefixChanged) {
      final ok = await showConfirm(
        context,
        title: '修改前缀将重置序号',
        message: '前缀已变更，序号将重置为 0001，是否继续？',
        confirmText: '继续',
      );
      if (!ok) return;
      await controller.settings.changePrefix(a: newA, b: newB, c: newC);
    } else {
      final serial = int.tryParse(_serial.text.trim());
      if (serial == null ||
          !const CodeGenerator().isSerialInRange(serial)) {
        await showAlert(
          context,
          title: '序号无效',
          message: '序号需为 1 ~ ${CodeGenerator.maxSerial} 的整数。',
        );
        return;
      }
      await controller.settings.setSerialNumber(serial);
    }

    await controller.settings.setContinuousMode(_continuous);
    await controller.settings
        .setOffsetX(int.tryParse(_offsetX.text.trim()) ?? old.offsetX);
    await controller.settings
        .setOffsetY(int.tryParse(_offsetY.text.trim()) ?? old.offsetY);
    await controller.settings
        .setFontSize(double.tryParse(_fontSize.text.trim()) ?? old.fontSize);
    await controller.settings
        .setDensity(int.tryParse(_density.text.trim()) ?? old.density);

    if (!mounted) return;
    await showAlert(context, title: '已保存');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShadCard(
            title: const Text('产品编号前缀'),
            description: const Text('修改任一前缀都会重置序号'),
            child: Column(
              children: [
                _field('前缀 A', _a),
                _field('前缀 B', _b),
                _field('前缀 C', _c),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('序号'),
            description: const Text('手动修正当前序号（1 ~ 9999）'),
            child: _field('当前序号', _serial, keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('连续模式'),
            description: const Text('开启后扫码直接打印，跳过预览'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShadSwitch(
                value: _continuous,
                onChanged: (v) => setState(() => _continuous = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('标签排版微调'),
            description: const Text('用于现场校正位置与字号'),
            child: Column(
              children: [
                _field('X 偏移', _offsetX, keyboardType: TextInputType.number),
                _field('Y 偏移', _offsetY, keyboardType: TextInputType.number),
                _field('字号', _fontSize, keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印浓度'),
            description: const Text('1 ~ 5，默认 3'),
            child: _field('浓度', _density, keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          ShadInput(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }
}
